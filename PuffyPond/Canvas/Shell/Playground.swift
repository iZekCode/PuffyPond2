import SwiftUI
import SceneKit
import Metal
import Observation
import QuartzCore
import simd

/// The whole toy: the 3D world, the two hand buddies, the four waiting characters, wet paint on the canvas, and the groove.
@Observable
final class Playground {
    // MARK: HUD state
    var cameraStatus: CameraStatus = .starting
    var showGuide = true
    /// The eye button: shows the front camera's view of the player's movement.
    var showCameraPreview = true
    var musicOn = true
    /// Spoken tracing directions on or off (the megaphone button). Remembered between launches.
    var guideVoiceOn = GuideVoice.savedOn {
        didSet {
            guard guideVoiceOn != oldValue else { return }
            voice.isMuted = !guideVoiceOn
            GuideVoice.save(on: guideVoiceOn)
            if guideVoiceOn, let guide, !isAway { voice.say(guide.text) }
        }
    }
    /// The current tracing direction in words, so it stays readable when the voice is off. Nil without an outline.
    var guideText: String?
    var hasDrawing = false
    /// Another page is showing: hands stop painting until the kids come back to the easel.
    /// Leaving mid-stroke ends the stroke and forgets the hands and the pointer.
    var isAway = false {
        didSet {
            guard isAway, !oldValue else { return }
            input.reset()
            voice.stop()
            pointerEnded()
            for slot in strokeBook.activeSlots { finishStroke(slot: slot) }
            previewHands = []
        }
    }
    var previewHands: [[CGPoint]] = []
    var imageAspect: CGFloat = 4.0 / 3.0
    /// How big the characters are: bigger paints a wider stroke. The settings menu's slider.
    var brushSize: Float = 1

    // MARK: World
    @ObservationIgnored let effects: Effects
    @ObservationIgnored private let easel: EaselScene
    var scene: SCNScene { effects.scene }
    var cameraNode: SCNNode { easel.cameraNode }
    var perches: [CharacterPerch] { easel.perches }
    @ObservationIgnored let audio = GrooveEngine()
    @ObservationIgnored private let input = HandInput()
    @ObservationIgnored private let frameDriver = FrameDriver()
    @ObservationIgnored private(set) var buddies: [Buddy] = []
    @ObservationIgnored private var lastHoldSound: Double = 0
    @ObservationIgnored private var lastPourSound: Double = 0
    @ObservationIgnored private var strokeBook = StrokeBook()
    /// The dotted animal to trace, if one is on the canvas.
    @ObservationIgnored private(set) var template: TemplateOutline?
    /// Follows the brush along the outline: which direction to say next, and where the arrow goes.
    @ObservationIgnored private var guide: TraceGuide?
    @ObservationIgnored private var guideArrow: GuideArrow?
    /// Reads the directions aloud; the HUD menu changes its voice, pace and tone.
    @ObservationIgnored let voice = GuideVoice(muted: !GuideVoice.savedOn)
    /// Seconds since the guide last spoke or the brush last made progress; negative while waiting to say hello.
    @ObservationIgnored private var guideQuiet: Float = 0
    @ObservationIgnored private var guideRepeats = 0
    /// What you actually see: wet, textured paint on the canvas.
    @ObservationIgnored private let paintLayer: PaintLayer
    @ObservationIgnored private let timelapse = TimelapseRecorder()
    @ObservationIgnored private var frameDT: Float = 1.0 / 60.0
    @ObservationIgnored private var lastGurgle: [Int: Double] = [:]
    @ObservationIgnored private var shake: Float = 0
    /// Movement stats of the current canvas session (camera hands and body only).
    @ObservationIgnored private var recorder = SessionRecorder()

    // Layout (see `CanvasLayout`)
    static let canvasSize = CanvasLayout.canvasSize
    static let canvasZ = CanvasLayout.canvasZ
    static let strokeRadius = CanvasLayout.strokeRadius
    static let paintHoverZ = CanvasLayout.paintHoverZ
    static let brushSizeRange = CanvasLayout.brushSizeRange

    // Timing
    @ObservationIgnored private var clock: Float = 0
    @ObservationIgnored private var energy: Float = 0
    @ObservationIgnored private var handsSeenTime: Float = 0

    // Pointer (mouse/touch) fallback acts as the left buddy.
    @ObservationIgnored private var pointer: SIMD2<Float>?
    @ObservationIgnored private var pointerPrevious: SIMD2<Float>?

    init() {
        let effects = Effects(scene: SCNScene())
        let paintLayer = PaintLayer(center: CanvasLayout.canvasCenter, size: CanvasLayout.canvasSize,
                                    z: CanvasLayout.canvasZ + 0.0015)
        self.effects = effects
        self.paintLayer = paintLayer
        easel = EaselScene(scene: effects.scene, paint: paintLayer.node)
        addBuddies()
        frameDriver.onFrame = { [weak self] dt in self?.tick(dt: Float(dt)) }
    }

    func start() {
        audio.start()
        frameDriver.start()
    }

    func pause() {
        audio.pause()
    }

    func toggleMusic() {
        musicOn.toggle()
        audio.setMuted(!musicOn)
    }

    // Lighting knobs, kept here for the timelapse replay (see `EaselScene`).
    static let keyIntensity = EaselScene.keyIntensity
    static let fillIntensity = EaselScene.fillIntensity
    static let environmentIntensity = EaselScene.environmentIntensity
    static let keyPosition = EaselScene.keyPosition
    static let keyTarget = EaselScene.keyTarget
    static let keyInnerAngle = EaselScene.keyInnerAngle
    static let keyOuterAngle = EaselScene.keyOuterAngle

    private func addBuddies() {
        let starting: [PaintTool] = [.ladybug, .butterfly]
        for slot in 0..<2 {
            let start = SIMD3<Float>(slot == 0 ? -1.2 : 1.2, -0.9, 0.5)
            let buddy = Buddy(slot: slot, tool: starting[slot], start: start)
            scene.rootNode.addChildNode(buddy.critter.root)
            buddies.append(buddy)
        }
    }

    /// Fills any window shape with canvas and lines the four characters up along its bottom edge.
    func layout(size: CGSize) { easel.fit(size: size) }

    /// Whether `p` (canvas plane) is under a waiting character: rubbing one must not paint behind it.
    func isOverShelf(_ p: SIMD2<Float>) -> Bool { easel.isOverShelf(p) }

    /// Visible half-size of the view at depth z.
    func visibleHalfSize(atZ z: Float) -> SIMD2<Float> { easel.layout.visibleHalfSize(atZ: z) }

    // MARK: - Input

    func ingest(_ frame: HandFrame) {
        guard !isAway else { return }
        input.ingest(frame)
        let aspect = CGFloat(frame.imageAspect)
        if abs(aspect - imageAspect) > 0.001 { imageAspect = aspect }
        if showCameraPreview {
            previewHands = frame.hands.map { hand in
                hand.joints.compactMap { joint in
                    joint.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
                }
            }
        }
    }

    /// Body pose for the range-of-motion stats; only counts while the canvas is up.
    func ingest(_ body: BodyFrame) {
        guard !isAway else { return }
        recorder.record(body: body, at: CACurrentMediaTime())
    }

    func pointerBegan(_ uv: SIMD2<Float>) {
        pointer = uv
        pointerPrevious = uv
    }

    func pointerMoved(_ uv: SIMD2<Float>) { pointer = uv }

    func pointerEnded() {
        pointer = nil
        pointerPrevious = nil
    }

    // MARK: - Frame loop

    private func tick(dt rawDT: Float) {
        let dt = FrameTiming.clampedDT(rawDT)
        frameDT = dt
        let now = CACurrentMediaTime()
        clock += dt
        let beatPulse = FrameTiming.beatPulse(beat: audio.beat)

        var hands = input.advance(dt: dt, now: now)
        if let p = pointer {
            let previous = pointerPrevious ?? p
            hands.removeAll { $0.slot == 0 }
            hands.append(.pointer(at: p, previous: previous, dt: dt))
            pointerPrevious = p
        }

        var movement: Float = 0
        var recorded: [SessionRecorder.Hand] = []
        for buddy in buddies {
            let hand = hands.first { $0.slot == buddy.slot && $0.tracking }
            let mode = BuddyMode.mode(for: hand?.pose)
            buddy.setMode(mode)
            if mode != .paint { finishStroke(slot: buddy.slot) }

            let size = CanvasLayout.characterScale * brushSize
            let buddyZ = CanvasLayout.buddyZ(painting: mode == .paint, brushSize: size)
            buddy.critter.sizeScale = size
            let target = hand.map { easel.layout.worldPoint($0.position, z: buddyZ) }
                ?? easel.layout.idleTarget(slot: buddy.slot, clock: clock, z: buddyZ)
            buddy.critter.update(dt: dt, target: target, visible: true,
                                 painting: mode == .paint, beatPulse: beatPulse)

            movement += min(buddy.toolSpeed, 4) * (hand == nil ? 0 : 1)
            switch mode {
            case .paint:
                paint(with: buddy, now: now)
            case .idle, .roam:
                break
            }
            rubPerches(buddy, dt: dt, now: now)
            if let hand, !hand.isPointer {
                recorded.append(SessionRecorder.Hand(slot: hand.slot, pose: hand.pose,
                                                     painting: mode == .paint,
                                                     canvas: CanvasLayout.canvasUV(buddy.toolPosition)))
            }
        }
        if !isAway { recorder.record(hands: recorded, dt: Double(dt)) }
        let rubs = buddies.map { (target: $0.rubbingTool, amount: $0.rubAmount) }
        for perch in perches {
            let progress = PotRub.progress(of: perch.tool, rubs: rubs)
            let spot = SIMD2(perch.root.simdPosition.x, perch.root.simdPosition.y)
            let nearest = buddies.map { simd_distance(SIMD2($0.toolPosition.x, $0.toolPosition.y), spot) }.min() ?? .infinity
            perch.update(dt: dt, beatPulse: beatPulse, rubProgress: min(progress, 1), buddyDistance: nearest)
        }
        template?.update()
        guideArrow?.update(dt: dt)
        tickGuide(dt: dt)

        paintLayer.update(dt: dt)

        effects.update(dt: dt)
        shake = max(0, shake - dt * 4)
        let jolt = shake * shake * 0.05
        easel.shakeCamera(jolt)

        // Music swells with how much you move.
        energy = FrameTiming.energy(energy, movement: movement, dt: dt)
        audio.update(energy: energy, now: now)

        publishHUD(dt: dt, hands: hands)
    }

    private func panFor(_ x: Float) -> Float { easel.layout.pan(forX: x) }

    // MARK: - Painting

    private func paint(with buddy: Buddy, now: Double) {
        let slot = buddy.slot
        let p3 = buddy.critter.position.value
        let raw = SIMD2(p3.x, p3.y)
        guard let p = CanvasLayout.brushPoint(raw), !isOverShelf(raw) else {
            finishStroke(slot: slot)
            return
        }

        // Lay real paint every frame, the way this tool paints.
        let from = strokeBook.stampStart(slot: slot, at: p)
        // The ladybug paints with its legs too, so its brush always comes from the animal itself.
        let dabs = buddy.tool == .ladybug
            ? buddy.critter.dabs(from: from, to: p, radius: Self.strokeRadius, speed: buddy.critter.speed)
            : buddy.tool.dabs(from: from, to: p, radius: Self.strokeRadius * brushSize, speed: buddy.critter.speed)
        lay(dabs, color: buddy.color, ncaModel: buddy.colorIndex, seed: Float(slot) * 13.7 + Float(strokeBook.count) * 2.3,
            brush: buddy.critter.kind)
        strokeBook.stamped(slot: slot, at: p)
        advanceGuide(at: p)
        if let hold = buddy.critter.holdProgress {
            if now - lastHoldSound > 0.45 {
                lastHoldSound = now
                audio.play(.ooze, a: hold, pan: panFor(p.x))
            }
            // A steady pour of paint under the gloopy bubbles.
            if now - lastPourSound > 0.1 {
                lastPourSound = now
                audio.play(.pour, a: hold, pan: panFor(p.x))
            }
        }
        switch strokeBook.paint(slot: slot, at: p, now: now, color: buddy.color, brush: buddy.critter.kind,
                                spacing: Self.strokeRadius * 0.6) {
        case .started:
            buddy.critter.gulp()
            audio.play(.blip, a: CanvasLayout.blipHeight(p), pan: panFor(p.x))
        case .blip:
            audio.play(.blip, a: CanvasLayout.blipHeight(p), pan: panFor(p.x))
        case nil:
            break
        }
    }

    /// `ncaModel` is the paint colour's index: each colour has its own NCA texture model.
    private func lay(_ dabs: [BrushDab], color: SIMD3<Float>, ncaModel: Int, seed: Float, brush: CritterKind) {
        timelapse.record(dabs: dabs, color: color, ncaModel: ncaModel, seed: seed, brush: brush)
        for (k, dab) in dabs.enumerated() {
            paintLayer.stamp(from: dab.from, to: dab.to, radius: dab.radius, color: color, speed: dab.speed,
                             seed: seed + Float(k) * 5.1, style: dab.style, drag: dab.drag, strokeSeed: seed,
                             ncaModel: ncaModel)
        }
    }

    private func finishStroke(slot: Int) {
        if strokeBook.finish(slot: slot), slot < buddies.count {
            buddies[slot].critter.react(.happy, for: 0.7)   // proud of that line
        }
    }

    // MARK: - Hang it in the gallery

    /// Photographs the finished painting (just the canvas and its paint, lit like the studio). The paint
    /// stays on the easel, so "Keep drawing" on the review page carries on. Nil when there's nothing painted yet.
    func finishPainting() -> CanvasPhotos? {
        guard !strokeBook.isEmpty else {
            audio.play(.swap)
            return nil
        }
        for slot in strokeBook.activeSlots { finishStroke(slot: slot) }
        guard let photo = easel.photoBooth(paint: paintLayer.node)?.photos() else {
            audio.play(.fizzle)
            return nil
        }
        audio.play(.fanfare)
        for buddy in buddies { buddy.critter.react(.happy, for: 1.2) }
        return photo
    }

    /// Wipes the paint, strokes and tracing guide off the easel.
    func clearCanvas() {
        wipePaint()
        template?.fadeAway()
        template = nil
        stopGuide()
    }

    private func wipePaint() {
        strokeBook.clear()
        paintLayer.clear()
        timelapse.reset()
    }

    /// Starts a fresh canvas session: clears the easel, lays the chosen outline, resets the stats.
    func begin(_ choice: TemplateChoice?) {
        clearCanvas()
        if let choice, let art = choice.art {
            let kind = choice.isDailyQuest ? nil : TemplateCatalog.kind(id: choice.templateID)
            let outline = TemplateOutline(art: art, kind: kind, canvasCenter: SIMD2(0, 0.1), canvasSize: Self.canvasSize,
                                          z: Self.canvasZ + 0.0008)
            showOutline(outline)
            startGuide(on: outline)
        }
        recorder = SessionRecorder()
    }

    /// Movement stats so far; nil when only touch or mouse drew.
    func sessionStats() -> SessionStats? { recorder.finish() }

    /// Everything painted since the canvas was last cleared, for the review page's timelapse.
    func timelapseRecording() -> StrokeRecording? { timelapse.snapshot() }

    /// The refresh button: wipes the paint but keeps the dotted outline, and the guide starts over from the top.
    func clearAll() {
        wipePaint()
        if let template { startGuide(on: template) }
        audio.play(.pop)
    }

    // MARK: - Tracing guide (arrow + spoken directions)

    func toggleGuideVoice() { guideVoiceOn.toggle() }

    private func startGuide(on outline: TemplateOutline) {
        stopGuide()
        guard let guide = TraceGuide(lines: outline.lines) else { return }
        self.guide = guide
        guideText = guide.text
        guideQuiet = -1.2   // a moment to settle before the first direction
        guideRepeats = 0
        let arrow = GuideArrow(z: Self.canvasZ + 0.004)
        arrow.move(to: guide.target, heading: guide.heading)
        scene.rootNode.addChildNode(arrow.node)
        guideArrow = arrow
    }

    private func stopGuide() {
        voice.stop()
        guideArrow?.fadeAway()
        guideArrow = nil
        guide = nil
        if guideText != nil { guideText = nil }
    }

    /// The brush is painting at `point`: move the guide on if it is on the next stretch of the outline.
    private func advanceGuide(at point: SIMD2<Float>) {
        guard var current = guide else { return }
        let progress = current.advance(to: point)
        guard progress != .none else { return }
        guide = current
        guideQuiet = 0
        guideRepeats = 0
        if guideText != current.text { guideText = current.text }
        guideArrow?.move(to: current.target, heading: current.heading)
        if progress == .legChanged || progress == .finished { voice.say(current.text) }
        if progress == .finished { guideArrow?.hide() }
    }

    private func tickGuide(dt: Float) {
        guard let current = guide, !isAway else { return }
        let before = guideQuiet
        guideQuiet += dt
        if before < 0, guideQuiet >= 0 { voice.say(current.text); return }
        // Say it again if the child seems stuck, but not forever.
        if guideQuiet >= 10, guideRepeats < 2, !current.isFinished {
            guideQuiet = 0
            guideRepeats += 1
            voice.say(current.text)
        }
    }

    // MARK: - Waiting characters

    /// Rub a buddy over a character waiting along the bottom and it turns into that character (and its colour).
    func rubPerches(_ buddy: Buddy, dt: Float, now: Double) {
        let p = buddy.toolPosition
        let rubber = PotRub.Rubber(idle: buddy.mode == .idle, position: SIMD2(p.x, p.y), tool: buddy.tool,
                                   speed: buddy.critter.speed)
        let step = PotRub.step(target: buddy.rubbingTool, amount: buddy.rubAmount, rubber: rubber,
                               perches: perches.map { PotRub.Perch(tool: $0.tool, position: $0.root.simdPosition) },
                               dt: dt)
        buddy.rubbingTool = step.target
        buddy.rubAmount = step.amount
        guard let perch = step.perch else { return }
        let perchPosition = perch.position
        if step.started { bounce(perch.tool, 0.6) }
        let pan = panFor(perchPosition.x)
        if now - (lastGurgle[buddy.slot] ?? 0) > 0.11 {
            lastGurgle[buddy.slot] = now
            audio.play(.gurgle, a: step.progress, pan: pan)
        }
        guard step.picked else { return }
        bounce(perch.tool, 1.5)
        finishStroke(slot: buddy.slot)
        if let old = buddy.equip(perch.tool) {
            old.root.removeFromParentNode()
            scene.rootNode.addChildNode(buddy.critter.root)
        }
        effects.colorSplash(at: perchPosition + SIMD3(0, 0.15, 0.1), color: perch.tool.color)
        audio.play(.pick, a: Float(perch.tool.colorIndex), pan: pan)
    }

    private func showOutline(_ outline: TemplateOutline) {
        template?.fadeAway()
        scene.rootNode.addChildNode(outline.node)
        template = outline
    }

    private func bounce(_ tool: PaintTool, _ strength: Float) {
        perches.first { $0.tool == tool }?.bounce(strength)
    }

    private func publishHUD(dt: Float, hands: [HandState]) {
        let drawingExists = !strokeBook.isEmpty
        if drawingExists != hasDrawing { hasDrawing = drawingExists }

        let cameraHands = hands.filter { !$0.isPointer }
        if cameraHands.isEmpty {
            handsSeenTime = 0
        } else {
            handsSeenTime += dt
            if showGuide && handsSeenTime > 1.5 {
                withAnimation(.easeOut(duration: 0.4)) { showGuide = false }
            }
        }
    }
}

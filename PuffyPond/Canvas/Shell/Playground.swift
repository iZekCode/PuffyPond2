import SwiftUI
import SceneKit
import Metal
import Observation
import QuartzCore
import simd

/// The whole toy: the 3D world, the two hand buddies, wet paint on the canvas, and the groove.
@Observable
final class Playground {
    // MARK: HUD state
    var cameraStatus: CameraStatus = .starting
    var showGuide = true
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
    var hint: Hint = .starting
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
    /// Hides the HUD (buttons, hints, camera preview). The paint, the brush characters, the pots and the bubbles stay.
    var focusMode = false
    var pointerErases = false {
        didSet {
            guard pointerErases != oldValue, let buddy = buddies.first else { return }
            // The garden eraser is a critter: the mouse or finger eraser button turns its buddy into the mushroom.
            let next: PaintTool = pointerErases ? .eraser : (toolBeforePointerErase ?? .brush)
            if pointerErases { toolBeforePointerErase = buddy.tool }
            finishStroke(slot: buddy.slot)
            if let old = buddy.equip(next) {
                old.root.removeFromParentNode()
                scene.rootNode.addChildNode(buddy.critter.root)
            }
        }
    }
    @ObservationIgnored private var toolBeforePointerErase: PaintTool?
    /// Red and orange: the ladybug's own colours.
    var buddyColors: [Int] = [0, 3]
    var buddyTools: [PaintTool] = [.brush, .brush]
    /// How big the ladybug is, and so how wide its brush paints (every leg scales with it).
    var brushSize: Float = 1
    var colorFlash: ColorFlash?

    // MARK: World
    @ObservationIgnored let effects: Effects
    @ObservationIgnored private let easel: EaselScene
    var scene: SCNScene { effects.scene }
    var cameraNode: SCNNode { easel.cameraNode }
    var pots: [PaintPot] { easel.pots }
    var critterPots: [CritterPot] { easel.critterPots }
    @ObservationIgnored let audio = GrooveEngine()
    @ObservationIgnored private let input = HandInput()
    @ObservationIgnored private let frameDriver = FrameDriver()
    @ObservationIgnored private(set) var buddies: [Buddy] = []
    @ObservationIgnored private var lastSlurp: Double = 0
    @ObservationIgnored private var lastHoldSound: Double = 0
    @ObservationIgnored private var strokeBook = StrokeBook()
    /// The dotted animal to trace, if one is on the canvas.
    @ObservationIgnored private(set) var template: TemplateOutline?
    /// Follows the brush along the outline: which direction to say next, and where the arrow goes.
    @ObservationIgnored private var guide: TraceGuide?
    @ObservationIgnored private var guideArrow: GuideArrow?
    @ObservationIgnored private let voice = GuideVoice(muted: !GuideVoice.savedOn)
    /// Seconds since the guide last spoke or the brush last made progress; negative while waiting to say hello.
    @ObservationIgnored private var guideQuiet: Float = 0
    @ObservationIgnored private var guideRepeats = 0
    /// What you actually see: wet, textured paint on the canvas.
    @ObservationIgnored private let paintLayer: PaintLayer
    @ObservationIgnored private let timelapse = TimelapseRecorder()
    @ObservationIgnored private var frameDT: Float = 1.0 / 60.0
    @ObservationIgnored private var lastGurgle: [Int: Double] = [:]
    @ObservationIgnored private var flashCounter = 0
    @ObservationIgnored private var shake: Float = 0
    /// Movement stats of the current canvas session (camera hands and body only).
    @ObservationIgnored private var recorder = SessionRecorder()

    // Layout (see `CanvasLayout`)
    static let canvasSize = CanvasLayout.canvasSize
    static let canvasZ = CanvasLayout.canvasZ
    static let shelfX = CanvasLayout.shelfX
    static let strokeRadius = CanvasLayout.strokeRadius
    static let paintHoverZ = CanvasLayout.paintHoverZ
    static let brushSizeRange = CanvasLayout.brushSizeRange

    // Timing
    @ObservationIgnored private var clock: Float = 0
    @ObservationIgnored private var lastPoof: Double = 0
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
        for slot in 0..<2 {
            let start = SIMD3<Float>(slot == 0 ? -1.2 : 1.2, -0.9, 0.5)
            let buddy = Buddy(slot: slot, colorIndex: buddyColors[slot], kind: .ladybug, start: start)
            scene.rootNode.addChildNode(buddy.critter.root)
            buddies.append(buddy)
        }
    }

    /// Fits the whole canvas and the two columns beside it (paint pots on the right, bubbles on the left) into any
    /// window shape, with a little room around them, so nothing is hidden behind a pot or a bubble.
    func layout(size: CGSize) { easel.fit(size: size) }

    /// Whether `p` (canvas plane) is under a pot or bubble: rubbing one must not paint or erase behind it.
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
        var drawingNow = false
        var erasingNow = false
        var recorded: [SessionRecorder.Hand] = []
        for buddy in buddies {
            let hand = hands.first { $0.slot == buddy.slot && $0.tracking }
            // The touch/mouse eraser button makes the pointer scrub, whatever tool the buddy holds.
            let tool: PaintTool = hand?.isPointer == true && pointerErases ? .eraser : buddy.tool
            let mode = BuddyMode.mode(for: hand?.pose, tool: tool)
            buddy.setMode(mode)
            if mode != .paint { finishStroke(slot: buddy.slot) }

            let buddyZ = CanvasLayout.buddyZ(painting: mode == .paint,
                                             brushSize: buddy.critter.usesSizeSlider ? brushSize : nil)
            if buddy.critter.usesSizeSlider { buddy.critter.sizeScale = brushSize }
            let target = hand.map { easel.layout.worldPoint($0.position, z: buddyZ) }
                ?? easel.layout.idleTarget(slot: buddy.slot, clock: clock, z: buddyZ)
            buddy.critter.update(dt: dt, target: target, visible: true,
                                 painting: mode == .paint || mode == .erase, beatPulse: beatPulse)

            movement += min(buddy.toolSpeed, 4) * (hand == nil ? 0 : 1)
            switch mode {
            case .paint:
                drawingNow = true
                paint(with: buddy, now: now)
            case .erase:
                erasingNow = true
                erase(with: buddy, now: now)
            case .idle, .roam:
                break
            }
            rubPots(buddy, dt: dt, now: now)
            if let hand, !hand.isPointer {
                recorded.append(SessionRecorder.Hand(slot: hand.slot, pose: hand.pose,
                                                     painting: mode == .paint || mode == .erase,
                                                     canvas: CanvasLayout.canvasUV(buddy.toolPosition)))
            }
        }
        if !isAway { recorder.record(hands: recorded, dt: Double(dt)) }
        var rubbing = false
        let rubs = buddies.map { (target: $0.rubbingPot, amount: $0.rubAmount) }
        for pot in pots {
            let progress = PotRub.progress(of: .color(pot.colorIndex), rubs: rubs)
            if progress > 0 { rubbing = true }
            let wearing = buddies.filter { $0.colorIndex == pot.colorIndex }.count
            pot.update(dt: dt, beatPulse: beatPulse, rubProgress: min(progress, 1), selectedCount: wearing)
        }
        for pot in critterPots {
            let progress = PotRub.progress(of: pot.target, rubs: rubs)
            if progress > 0 { rubbing = true }
            let wearers = buddies.filter { wears($0, pot.target) }
            let paints: Bool
            if case .tool(let tool) = pot.target { paints = tool.usesColor } else { paints = true }
            pot.update(dt: dt, beatPulse: beatPulse, rubProgress: min(progress, 1), selectedCount: wearers.count,
                       color: paints ? wearers.first?.color : nil)
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

        publishHUD(dt: dt, hands: hands, drawing: drawingNow, erasing: erasingNow, rubbing: rubbing)
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
        let dabs = buddy.tool != .brush
            ? buddy.tool.dabs(from: from, to: p, radius: Self.strokeRadius, speed: buddy.critter.speed)
            : buddy.critter.dabs(from: from, to: p, radius: Self.strokeRadius, speed: buddy.critter.speed)
        lay(dabs, color: buddy.color, ncaModel: buddy.colorIndex, seed: Float(slot) * 13.7 + Float(strokeBook.count) * 2.3,
            brush: buddy.critter.kind)
        strokeBook.stamped(slot: slot, at: p)
        if buddy.tool.usesColor { advanceGuide(at: p) }
        if let hold = buddy.critter.holdProgress, now - lastHoldSound > 0.45 {
            lastHoldSound = now
            audio.play(.ooze, a: hold, pan: panFor(p.x))
        }
        // The blender only moves paint that's already there: it doesn't start a stroke of its own.
        if buddy.tool == .blender {
            if now - lastSlurp > 0.25 {
                lastSlurp = now
                audio.play(.slurp, a: min(buddy.critter.speed / 3, 1), pan: panFor(p.x))
            }
            return
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

    func erase(with buddy: Buddy, now: Double) {
        let s = buddy.toolPosition
        let p = SIMD2(s.x, s.y)
        if isOverShelf(p) { return }
        let r = buddy.eraseRadius
        paintLayer.erase(at: p, radius: r, dt: frameDT)
        // Only erasing on the canvas is part of the timelapse (the eraser also roams the shelf and the floor).
        if CanvasLayout.isOnCanvas(p) {
            timelapse.recordErase(at: p, radius: r, dt: frameDT)
        }
        // The mushroom only wipes paint: the dotted guide stays.
        if strokeBook.erase(at: p, radius: r) {
            buddy.scrubbed()
            if now - lastPoof > 0.09 {
                lastPoof = now
                audio.play(.poof, pan: panFor(p.x))
                Toybox.burst(in: scene, at: SIMD3(p.x, p.y, 0.2), color: SIMD3(1, 1, 1), count: 10, speed: 1.2,
                             size: 0.04, gravity: -1)
            }
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

    // MARK: - HUD

    // MARK: - Paint pots

    /// Dip a critter into a pot and rub/swipe: it soaks up the color (faster the more you rub).
    /// Rub it in a critter bubble instead and it turns into that brush animal.
    func rubPots(_ buddy: Buddy, dt: Float, now: Double) {
        let p = buddy.toolPosition
        let rubber = PotRub.Rubber(idle: buddy.mode == .idle, position: SIMD2(p.x, p.y), colorIndex: buddy.colorIndex,
                                   tool: buddy.tool, speed: buddy.critter.speed)
        let step = PotRub.step(target: buddy.rubbingPot, amount: buddy.rubAmount, rubber: rubber,
                               colorPots: pots.map { PotRub.Pot(target: .color($0.colorIndex), position: $0.root.simdPosition) },
                               toolPots: critterPots.map { PotRub.Pot(target: $0.target, position: $0.root.simdPosition) },
                               dt: dt)
        buddy.rubbingPot = step.target
        buddy.rubAmount = step.amount
        guard let pot = step.pot else {
            buddy.critter.colorPreview = nil
            return
        }
        let target = pot.target
        let potPosition = pot.position
        if step.started { bouncePot(target, 0.6) }
        if case .color(let index) = target { buddy.critter.colorPreview = (Paint.colors[index], step.progress * 0.85) }
        let pan = panFor(potPosition.x)
        if now - (lastGurgle[buddy.slot] ?? 0) > 0.11 {
            lastGurgle[buddy.slot] = now
            audio.play(.gurgle, a: step.progress, pan: pan)
        }
        guard step.picked else { return }
        bouncePot(target, 1.5)
        switch target {
        case .color(let index):
            buddy.pick(index)
            if let tool = PotRub.tool(afterPicking: index, tool: buddy.tool, critter: buddy.critter.kind) {
                finishStroke(slot: buddy.slot)
                if let old = buddy.equip(tool) {
                    old.root.removeFromParentNode()
                    scene.rootNode.addChildNode(buddy.critter.root)
                }
            }
            effects.colorSplash(at: potPosition + SIMD3(0, 0.15, 0.1), color: Paint.colors[index])
            audio.play(Int.random(in: 0..<12) == 0 ? .chicken : .pick, a: Float(index), pan: pan)
            flashCounter += 1
            colorFlash = ColorFlash(slot: buddy.slot, colorIndex: index, id: flashCounter)
        case .tool(let tool):
            finishStroke(slot: buddy.slot)
            if pointerErases, buddy.slot == 0, tool != .eraser {
                // The eraser button would keep the pointer scrubbing: switch it off and take the new tool instead.
                toolBeforePointerErase = tool
                pointerErases = false
            } else if let old = buddy.equip(tool) {
                old.root.removeFromParentNode()
                scene.rootNode.addChildNode(buddy.critter.root)
            }
            effects.colorSplash(at: potPosition + SIMD3(0, 0.15, 0.1), color: tool.usesColor ? buddy.color : SIMD3(1, 1, 1))
            audio.play(.bonk, pan: pan)
        }
    }

    private func showOutline(_ outline: TemplateOutline) {
        template?.fadeAway()
        scene.rootNode.addChildNode(outline.node)
        template = outline
    }

    /// The buddy already holds this tool.
    private func wears(_ buddy: Buddy, _ target: PotTarget) -> Bool {
        if case .tool(let tool) = target { return buddy.tool == tool }
        return false
    }

    private func bouncePot(_ target: PotTarget, _ strength: Float) {
        switch target {
        case .color(let index): pots.first { $0.colorIndex == index }?.bounce(strength)
        case .tool: critterPots.first { $0.target == target }?.bounce(strength)
        }
    }

    private func publishHUD(dt: Float, hands: [HandState], drawing: Bool, erasing: Bool, rubbing: Bool) {
        let next = Hint.pick(erasing: erasing, drawing: drawing, rubbing: rubbing, hasStrokes: !strokeBook.isEmpty,
                             hasTemplate: template != nil,
                             cameraHandsTracking: hands.contains { $0.tracking && !$0.isPointer },
                             cameraStatus: cameraStatus)
        if next != hint { hint = next }
        let drawingExists = !strokeBook.isEmpty
        if drawingExists != hasDrawing { hasDrawing = drawingExists }
        let colors = buddies.map(\.colorIndex)
        if colors != buddyColors { buddyColors = colors }
        let tools = buddies.map(\.tool)
        if tools != buddyTools { buddyTools = tools }

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

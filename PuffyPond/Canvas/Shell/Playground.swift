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
    var hint: Hint = .starting
    var hasDrawing = false
    /// Another page is showing: hands stop painting until the kids come back to the easel.
    /// Leaving mid-stroke ends the stroke and forgets the hands and the pointer.
    var isAway = false {
        didSet {
            guard isAway, !oldValue else { return }
            input.reset()
            pointerEnded()
            for slot in Array(activeStroke.keys) { finishStroke(slot: slot) }
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
    @ObservationIgnored let effects = Effects(scene: SCNScene())
    var scene: SCNScene { effects.scene }
    @ObservationIgnored let cameraNode = SCNNode()
    @ObservationIgnored let audio = GrooveEngine()
    @ObservationIgnored private let input = HandInput()
    @ObservationIgnored private let frameDriver = FrameDriver()
    @ObservationIgnored private(set) var buddies: [Buddy] = []
    @ObservationIgnored private var lastSlurp: Double = 0
    @ObservationIgnored private var lastHoldSound: Double = 0
    @ObservationIgnored private var strokes: [Stroke] = []
    @ObservationIgnored private var activeStroke: [Int: Stroke] = [:]
    @ObservationIgnored private var lastBead: [Int: SIMD2<Float>] = [:]
    @ObservationIgnored private var blipDistance: [Int: Float] = [:]
    @ObservationIgnored private(set) var pots: [PaintPot] = []
    @ObservationIgnored private(set) var critterPots: [CritterPot] = []
    /// The dotted animal to trace, if one is on the canvas.
    @ObservationIgnored private(set) var template: TemplateOutline?
    /// What you actually see: wet, textured paint on the canvas.
    @ObservationIgnored private let paintLayer = PaintLayer(center: SIMD2(0, 0.1), size: Playground.canvasSize,
                                                            z: Playground.canvasZ + 0.0015)
    @ObservationIgnored private let timelapse = TimelapseRecorder()
    @ObservationIgnored private var lastStamp: [Int: SIMD2<Float>] = [:]
    @ObservationIgnored private var frameDT: Float = 1.0 / 60.0
    @ObservationIgnored private var lastGurgle: [Int: Double] = [:]
    @ObservationIgnored private var flashCounter = 0
    @ObservationIgnored private var shake: Float = 0
    @ObservationIgnored private let canvasNode = SCNNode()
    @ObservationIgnored private var canvasBoard: SCNNode?
    @ObservationIgnored private var studioLights: [SCNNode] = []
    /// Movement stats of the current canvas session (camera hands and body only).
    @ObservationIgnored private var recorder = SessionRecorder()

    // Layout (see `CanvasLayout`)
    @ObservationIgnored private var canvasLayout = CanvasLayout()
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
        buildWorld()
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

    // MARK: - World building

    // Lighting knobs. Brightness: keyIntensity, fillIntensity, environmentIntensity, exposureOffset (EV, lower is darker).
    // Direction: keyPosition (x left/right, y up, z toward the camera) and keyTarget (the point it aims at).
    // Spread: keyInnerAngle/keyOuterAngle (wider is more even, narrower is a vignette).
    static let keyIntensity: CGFloat = 300
    static let fillIntensity: CGFloat = 220
    static let environmentIntensity: CGFloat = 0.7
    private static let exposureOffset: CGFloat = -0.5
    static let keyPosition = SIMD3<Float>(0, 7, 6)
    static let keyTarget = SIMD3<Float>(0, 0, 0)
    static let keyInnerAngle: CGFloat = 70
    static let keyOuterAngle: CGFloat = 110

    private func buildWorld() {
        // A painter's studio: soft window light in an out-of-focus room.
        scene.background.contents = Studio.backdrop()
        scene.background.intensity = 1.7          // the room photo, brought up to the camera's exposure
        scene.lightingEnvironment.contents = Studio.environment()
        scene.lightingEnvironment.intensity = Self.environmentIntensity

        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 50
        // Photographic look: tone-mapped HDR, contact shadows, a soft lens vignette and a hint of bloom.
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = Self.exposureOffset
        camera.minimumExposure = -2
        camera.maximumExposure = 2
        camera.screenSpaceAmbientOcclusionIntensity = 0   // no contact shadows under the pots and brush animals
        camera.vignettingIntensity = 0.35
        camera.vignettingPower = 0.9
        camera.bloomIntensity = 0.12
        camera.bloomThreshold = 0.95
        camera.bloomBlurRadius = 8
        cameraNode.camera = camera
        cameraNode.simdPosition = SIMD3(0, CanvasLayout.cameraY, canvasLayout.cameraDistance)
        scene.rootNode.addChildNode(cameraNode)

        // Overhead light from the top centre: a neutral spot that lights the canvas almost evenly (like Splash
        // Canvas's far lights), with the normal map showing the paint ridges (no cast shadows).
        let key = SCNLight()
        key.type = .spot
        key.intensity = Self.keyIntensity
        key.color = PlatformColor(red: 1, green: 1, blue: 1, alpha: 1)
        key.spotInnerAngle = Self.keyInnerAngle
        key.spotOuterAngle = Self.keyOuterAngle
        key.attenuationStartDistance = 4
        key.attenuationEndDistance = 40
        key.attenuationFalloffExponent = 0
        key.castsShadow = false
        key.shadowMode = .deferred
        key.shadowRadius = 14
        key.shadowSampleCount = 24
        key.shadowColor = PlatformColor(red: 0.12, green: 0.1, blue: 0.14, alpha: 0.45)
        key.shadowMapSize = CGSize(width: 4096, height: 4096)
        key.zNear = 1
        key.zFar = 30
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.simdPosition = Self.keyPosition
        keyNode.simdLook(at: Self.keyTarget)
        scene.rootNode.addChildNode(keyNode)
        studioLights.append(keyNode)

        // Neutral bounce light from the room.
        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = Self.fillIntensity
        fill.color = PlatformColor(red: 1, green: 1, blue: 1, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        scene.rootNode.addChildNode(fillNode)
        studioLights.append(fillNode)

        // Stretched linen canvas (deep, like a gallery-wrapped canvas) on a wooden studio easel.
        let size = Self.canvasSize
        let linen = Studio.canvasMaterial(repeats: size / Studio.weaveTileSize)
        let depth: Float = 0.16
        let board = Toybox.node(SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(depth),
                                       chamferRadius: 0.012), linen, at: SIMD3(0, 0, Self.canvasZ - depth / 2))
        canvasNode.addChildNode(board)
        canvasBoard = board
        // No easel frame: the canvas stands free, with the pot and bubble columns beside it.
        canvasNode.simdPosition = SIMD3(0, 0.1, 0)
        scene.rootNode.addChildNode(canvasNode)

        scene.rootNode.addChildNode(paintLayer.node)
        // Two columns just outside the canvas, so dipping never smears the painting:
        // paint pots down the right (rub a critter in one to pick up its color),
        // critter bubbles down the left (rub one to become that brush animal, or to pick up that paint tool).
        let potColors = Paint.potOrder
        for (k, colorIndex) in potColors.enumerated() {
            let pot = PaintPot(colorIndex: colorIndex, at: SIMD3(Self.shelfX, CanvasLayout.columnY(k, of: potColors.count), 0.3))
            scene.rootNode.addChildNode(pot.root)
            pots.append(pot)
        }
        for (k, tool) in PaintTool.allCases.enumerated() {
            let y = CanvasLayout.columnY(k, of: PaintTool.allCases.count)
            critterPots.append(CritterPot(tool: tool, at: SIMD3(-Self.shelfX, y, 0.3)))
        }
        for pot in critterPots {
            scene.rootNode.addChildNode(pot.root)
            scene.rootNode.addChildNode(pot.residentRoot)
        }

        for slot in 0..<2 {
            let start = SIMD3<Float>(slot == 0 ? -1.2 : 1.2, -0.9, 0.5)
            let buddy = Buddy(slot: slot, colorIndex: buddyColors[slot], kind: .ladybug, start: start)
            scene.rootNode.addChildNode(buddy.critter.root)
            buddies.append(buddy)
        }
        layout(size: CGSize(width: 1600, height: 1000))
    }

    /// Fits the whole canvas and the two columns beside it (paint pots on the right, bubbles on the left) into any
    /// window shape, with a little room around them, so nothing is hidden behind a pot or a bubble.
    func layout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        canvasLayout.fit(width: Float(size.width), height: Float(size.height))
        cameraNode.simdPosition = SIMD3(0, CanvasLayout.cameraY, canvasLayout.cameraDistance)
        placeShelves()
    }

    /// Stands the paint pots in a column beside the right edge of the canvas and the bubbles beside the left edge.
    private func placeShelves() {
        for pot in pots { pot.root.simdPosition.x = Self.shelfX }
        for pot in critterPots { pot.root.simdPosition.x = -Self.shelfX }
    }

    /// Whether `p` (canvas plane) is under a pot or bubble: rubbing one must not paint or erase behind it.
    func isOverShelf(_ p: SIMD2<Float>) -> Bool {
        pots.contains { CanvasLayout.touches(p, potAt: $0.root.simdPosition) }
            || critterPots.contains { CanvasLayout.touches(p, potAt: $0.root.simdPosition) }
    }

    /// Visible half-size of the view at depth z.
    func visibleHalfSize(atZ z: Float) -> SIMD2<Float> { canvasLayout.visibleHalfSize(atZ: z) }

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
            let target = hand.map { canvasLayout.worldPoint($0.position, z: buddyZ) }
                ?? canvasLayout.idleTarget(slot: buddy.slot, clock: clock, z: buddyZ)
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

        paintLayer.update(dt: dt)

        effects.update(dt: dt)
        shake = max(0, shake - dt * 4)
        let jolt = shake * shake * 0.05
        cameraNode.simdPosition = SIMD3(Float.random(in: -jolt...jolt), CanvasLayout.cameraY + Float.random(in: -jolt...jolt),
                                        canvasLayout.cameraDistance)

        // Music swells with how much you move.
        energy = FrameTiming.energy(energy, movement: movement, dt: dt)
        audio.update(energy: energy, now: now)

        publishHUD(dt: dt, hands: hands, drawing: drawingNow, erasing: erasingNow, rubbing: rubbing)
    }

    private func panFor(_ x: Float) -> Float { canvasLayout.pan(forX: x) }

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
        let from = lastStamp[slot] ?? p
        // The ladybug paints with its legs too, so its brush always comes from the animal itself.
        let dabs = buddy.tool != .brush
            ? buddy.tool.dabs(from: from, to: p, radius: Self.strokeRadius, speed: buddy.critter.speed)
            : buddy.critter.dabs(from: from, to: p, radius: Self.strokeRadius, speed: buddy.critter.speed)
        lay(dabs, color: buddy.color, ncaModel: buddy.colorIndex, seed: Float(slot) * 13.7 + Float(strokes.count) * 2.3,
            brush: buddy.critter.kind)
        lastStamp[slot] = p
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

        let spacing = Self.strokeRadius * 0.6
        if let stroke = activeStroke[slot], let last = lastBead[slot] {
            let beads = StrokePath.beads(from: last, to: p, spacing: spacing)
            guard !beads.isEmpty else { return }
            for q in beads { stroke.add(q, now: now) }
            lastBead[slot] = p
            blipDistance[slot, default: 0] += simd_distance(p, last)
            if blipDistance[slot, default: 0] > 0.16 {
                blipDistance[slot] = 0
                audio.play(.blip, a: CanvasLayout.blipHeight(p), pan: panFor(p.x))
            }
        } else {
            let stroke = Stroke(color: buddy.color, radius: Self.strokeRadius, surfaceZ: Self.canvasZ + Self.strokeRadius * 0.55,
                                brush: buddy.critter.kind)
            stroke.add(p, now: now)
            strokes.append(stroke)
            activeStroke[slot] = stroke
            lastBead[slot] = p
            buddy.critter.gulp()
            audio.play(.blip, a: CanvasLayout.blipHeight(p), pan: panFor(p.x))
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
        if activeStroke[slot] != nil, slot < buddies.count {
            let buddy = buddies[slot]
            buddy.critter.react(.happy, for: 0.7)   // proud of that line
        }
        activeStroke[slot] = nil
        lastBead[slot] = nil
        lastStamp[slot] = nil
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
        var erasedAny = false
        var newStrokes: [Stroke] = []
        for stroke in strokes {
            // Split into the runs that survive.
            guard let runs = StrokePath.cut(stroke.points, at: p, radius: r) else {
                newStrokes.append(stroke)
                continue
            }
            erasedAny = true
            if let first = runs.first {
                stroke.replacePoints(first)
                newStrokes.append(stroke)
                for run in runs.dropFirst() {
                    let piece = Stroke(color: stroke.color, radius: stroke.radius, surfaceZ: stroke.surfaceZ, brush: stroke.brush)
                    piece.replacePoints(run)
                    scene.rootNode.addChildNode(piece.node)
                    newStrokes.append(piece)
                }
            } else {
                stroke.node.removeFromParentNode()
                for (slot, active) in activeStroke where active === stroke { activeStroke[slot] = nil }
            }
        }
        strokes = newStrokes
        if erasedAny {
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
        guard !strokes.isEmpty else {
            audio.play(.swap)
            return nil
        }
        for slot in Array(activeStroke.keys) { finishStroke(slot: slot) }
        guard let photo = photographCanvas() else {
            audio.play(.fizzle)
            return nil
        }
        audio.play(.fanfare)
        for buddy in buddies { buddy.critter.react(.happy, for: 1.2) }
        return photo
    }

    /// Renders the canvas head-on in a little photo booth: copies of the board and the live paint,
    /// the studio's own lights, no critters, pots or tracing guide in the way.
    private func photographCanvas(pixels width: CGFloat = 1920) -> CanvasPhotos? {
        guard let whole = photograph(board: true, paint: true, pixels: width),
              let canvas = photograph(board: true, paint: false, pixels: width),
              let onBlack = photograph(board: false, paint: true, background: .black, pixels: width),
              let onWhite = photograph(board: false, paint: true, background: .white, pixels: width),
              let blackLevel = backdropLevel(.black), let whiteLevel = backdropLevel(.white),
              let paint = PaintMatte.extract(onBlack: onBlack, onWhite: onWhite, blackLevel: blackLevel,
                                             whiteLevel: whiteLevel, floor: PaintMatte.sheenFloor) else { return nil }
        return CanvasPhotos(whole: whole, canvas: canvas, paint: paint)
    }

    /// How bright a plain backdrop comes out in the booth, whose exposure can dim it.
    private func backdropLevel(_ color: PlatformColor) -> Double? {
        photograph(board: false, paint: false, background: color, pixels: 16).flatMap(PaintMatte.level)
    }

    /// One shot of the photo booth. Paint alone goes over a plain `background` (see `PaintMatte`).
    private func photograph(board showBoard: Bool, paint showPaint: Bool, background: PlatformColor? = nil,
                            pixels width: CGFloat) -> CGImage? {
        guard let canvasBoard else { return nil }
        let booth = SCNScene()
        if let background { booth.background.contents = background }
        booth.lightingEnvironment.contents = scene.lightingEnvironment.contents
        booth.lightingEnvironment.intensity = scene.lightingEnvironment.intensity
        if showBoard {
            let board = canvasBoard.clone()
            board.simdTransform = canvasBoard.simdWorldTransform
            booth.rootNode.addChildNode(board)
        }
        if showPaint { booth.rootNode.addChildNode(paintLayer.node.clone()) }
        for light in studioLights { booth.rootNode.addChildNode(light.clone()) }

        let size = Self.canvasSize
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(size.y * 0.5 * 0.99)   // a hair inside the chamfered edge
        camera.zNear = 0.1
        camera.zFar = 20
        if let studio = cameraNode.camera {
            camera.wantsHDR = studio.wantsHDR
            camera.wantsExposureAdaptation = false
            camera.exposureOffset = studio.exposureOffset
            camera.minimumExposure = studio.minimumExposure
            camera.maximumExposure = studio.maximumExposure
        }
        let lens = SCNNode()
        lens.camera = camera
        lens.simdPosition = SIMD3(0, 0.1, 5)
        booth.rootNode.addChildNode(lens)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = booth
        renderer.pointOfView = lens
        let pixels = CGSize(width: width, height: width * CGFloat(size.y / size.x))
        return renderer.snapshot(atTime: 0, with: pixels, antialiasingMode: .multisampling4X).cgImageValue
    }

    /// Wipes the paint, strokes and tracing guide off the easel.
    func clearCanvas() {
        for stroke in strokes { stroke.node.removeFromParentNode() }
        strokes.removeAll()
        paintLayer.clear()
        timelapse.reset()
        template?.fadeAway()
        template = nil
        activeStroke = [:]
        lastBead = [:]
        lastStamp = [:]
    }

    /// Starts a fresh canvas session: clears the easel, lays the chosen outline, resets the stats.
    func begin(_ choice: TemplateChoice?) {
        clearCanvas()
        if let choice, let art = choice.art {
            let kind = choice.isDailyQuest ? nil : TemplateCatalog.kind(id: choice.templateID)
            showOutline(TemplateOutline(art: art, kind: kind, canvasCenter: SIMD2(0, 0.1), canvasSize: Self.canvasSize,
                                        z: Self.canvasZ + 0.0008))
        }
        recorder = SessionRecorder()
    }

    /// Movement stats so far; nil when only touch or mouse drew.
    func sessionStats() -> SessionStats? { recorder.finish() }

    /// Everything painted since the canvas was last cleared, for the review page's timelapse.
    func timelapseRecording() -> StrokeRecording? { timelapse.snapshot() }

    func clearAll() {
        clearCanvas()
        audio.play(.pop)
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
        let next = Hint.pick(erasing: erasing, drawing: drawing, rubbing: rubbing, hasStrokes: !strokes.isEmpty,
                             hasTemplate: template != nil,
                             cameraHandsTracking: hands.contains { $0.tracking && !$0.isPointer },
                             cameraStatus: cameraStatus)
        if next != hint { hint = next }
        let drawingExists = !strokes.isEmpty
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

import SwiftUI
import SceneKit
import Metal
import Observation
import QuartzCore
import simd

nonisolated enum CameraStatus: Equatable { case starting, running, denied, unavailable }

nonisolated enum Hint: Equatable {
    case starting, raiseHands, swimming, pickingColor, drawing, erasing, readyToHang, tracing, touchMode
}

/// "You picked a color" moment for the HUD.
nonisolated struct ColorFlash: Equatable {
    let slot: Int
    let colorIndex: Int
    let id: Int
}

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
            guard controlScheme == .fist, pointerErases != oldValue, let buddy = buddies.first else { return }
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
    var buddyColors: [Int] = [0, 1]
    var buddyKinds: [CritterKind] = [.octopus, .seahorse]
    var buddyTools: [PaintTool] = [.brush, .brush]
    /// How big the octopus is, and so how wide its brush paints (its mouth and every tentacle scale with it).
    var octopusSize: Float = 1
    var colorFlash: ColorFlash?
    /// Fist paints with four tools (default), or the original pinch + six brush animals.
    let controlScheme: ControlScheme

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
    @ObservationIgnored private var templatePots: [TemplatePot] = []
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

    // Layout
    @ObservationIgnored private var aspect: Float = 16.0 / 10.0
    @ObservationIgnored private var cameraDistance: Float = 7
    @ObservationIgnored private let cameraY: Float = 0.1
    @ObservationIgnored private let tanHalfFOV = Float(tan(17.0 * Double.pi / 180))
    /// A big canvas (≈ 1.8× wider than before) — lots of room for broad arm strokes.
    static let canvasSize = SIMD2<Float>(6.4, 4.0)
    static let canvasZ: Float = 0.04            // front face of the canvas
    /// The pot and bubble columns sit just outside the canvas's left and right edges.
    static let shelfX: Float = canvasSize.x * 0.5 + 0.38
    static let shelfSpacing: Float = 0.62
    /// Template bubbles stand on the easel tray along the bottom of the canvas.
    static let templateRowY: Float = 0.1 - canvasSize.y * 0.5 + 0.23
    static let strokeRadius: Float = 0.085
    static let paintHoverZ: Float = 0.24        // how high the brush animal hovers while painting
    static let octopusSizeRange: ClosedRange<Float> = 0.6...2.4

    // Timing
    @ObservationIgnored private var lastTime: Double = 0
    @ObservationIgnored private var clock: Float = 0
    @ObservationIgnored private var lastSqueak: Double = 0
    @ObservationIgnored private var lastBeatIndex = -1
    @ObservationIgnored private var energy: Float = 0
    @ObservationIgnored private var handsSeenTime: Float = 0

    // Pointer (mouse/touch) fallback acts as the left buddy.
    @ObservationIgnored private var pointer: SIMD2<Float>?
    @ObservationIgnored private var pointerPrevious: SIMD2<Float>?

    init(controlScheme: ControlScheme = .fist) {
        self.controlScheme = controlScheme
        input.scheme = controlScheme
        if controlScheme == .fist {
            buddyKinds = [.ladybug, .ladybug]
            buddyColors = [0, 3]   // red and orange: the ladybug's own colours
        }
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
    private static let keyIntensity: CGFloat = 300
    private static let fillIntensity: CGFloat = 220
    private static let environmentIntensity: CGFloat = 0.7
    private static let exposureOffset: CGFloat = -0.5
    private static let keyPosition = SIMD3<Float>(0, 7, 6)
    private static let keyTarget = SIMD3<Float>(0, 0, 0)
    private static let keyInnerAngle: CGFloat = 70
    private static let keyOuterAngle: CGFloat = 110

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
        cameraNode.simdPosition = SIMD3(0, cameraY, cameraDistance)
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
        // The canvas fills the whole view, so there is no easel frame around it.
        canvasNode.simdPosition = SIMD3(0, 0.1, 0)
        scene.rootNode.addChildNode(canvasNode)

        scene.rootNode.addChildNode(paintLayer.node)
        // Two columns just outside the canvas, so dipping never smears the painting:
        // paint pots down the right (rub a critter in one to pick up its color),
        // critter bubbles down the left (rub one to become that brush animal, or to pick up that paint tool).
        func columnY(_ k: Int, of count: Int) -> Float {
            0.1 + (Float(count - 1) / 2 - Float(k)) * Self.shelfSpacing
        }
        let potColors = controlScheme == .fist ? Paint.potOrder : Array(Paint.colors.indices)
        for (k, colorIndex) in potColors.enumerated() {
            let pot = PaintPot(colorIndex: colorIndex, at: SIMD3(Self.shelfX, columnY(k, of: potColors.count), 0.3))
            scene.rootNode.addChildNode(pot.root)
            pots.append(pot)
        }
        switch controlScheme {
        case .legacy:
            for (k, kind) in CritterKind.legacyBrushes.enumerated() {
                let y = columnY(k, of: CritterKind.legacyBrushes.count)
                critterPots.append(CritterPot(kind: kind, at: SIMD3(-Self.shelfX, y, 0.3)))
            }
        case .fist:
            for (k, tool) in PaintTool.allCases.enumerated() {
                let y = columnY(k, of: PaintTool.allCases.count)
                critterPots.append(CritterPot(tool: tool, at: SIMD3(-Self.shelfX, y, 0.3)))
            }
        }
        for pot in critterPots {
            scene.rootNode.addChildNode(pot.root)
            scene.rootNode.addChildNode(pot.residentRoot)
        }
        // A row of template bubbles on the tray: rub one to get a dotted animal to trace. The fist
        // controls pick the template before the canvas opens instead.
        for (k, kind) in (controlScheme == .legacy ? TemplateKind.legacyTray : []).enumerated() {
            let x = (Float(k) - Float(TemplateKind.legacyTray.count - 1) / 2) * 0.9
            let pot = TemplatePot(kind: kind, at: SIMD3(x, Self.templateRowY, 0.3))
            scene.rootNode.addChildNode(pot.root)
            templatePots.append(pot)
        }

        for slot in 0..<2 {
            let start = SIMD3<Float>(slot == 0 ? -1.2 : 1.2, -0.9, 0.5)
            let buddy = Buddy(slot: slot, colorIndex: buddyColors[slot], kind: buddyKinds[slot], start: start,
                              erasesWithStarfish: controlScheme == .legacy)
            scene.rootNode.addChildNode(buddy.critter.root)
            scene.rootNode.addChildNode(buddy.starfish.root)
            buddies.append(buddy)
        }
        layout(size: CGSize(width: 1600, height: 1000))
    }

    /// The canvas fills the whole window, edge to edge: the tighter side of the window is matched exactly and the
    /// other side overflows. The pots and bubbles float over the left and right edges of the view.
    func layout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        aspect = Float(size.width / size.height)
        let fitHeight = Self.canvasSize.y * 0.5 / tanHalfFOV
        let fitWidth = Self.canvasSize.x * 0.5 / (tanHalfFOV * aspect)
        cameraDistance = Self.canvasZ + min(fitHeight, fitWidth) * 0.999
        cameraNode.simdPosition = SIMD3(0, cameraY, cameraDistance)
        placeShelves()
    }

    /// Puts the paint pots on the right and the bubbles on the left, just inside the edges of the view.
    private func placeShelves() {
        let x = max(visibleHalfSize(atZ: 0.3).x - PaintPot.radius - 0.2, 0.5)
        for pot in pots { pot.root.simdPosition.x = x }
        for pot in critterPots { pot.root.simdPosition.x = -x }
    }

    /// Whether `p` (canvas plane) is under a pot or bubble: rubbing one must not paint or erase behind it.
    func isOverShelf(_ p: SIMD2<Float>) -> Bool {
        let reach = PaintPot.radius + 0.14
        return pots.contains { simd_distance(p, SIMD2($0.root.simdPosition.x, $0.root.simdPosition.y + 0.04)) < reach }
            || critterPots.contains { simd_distance(p, SIMD2($0.root.simdPosition.x, $0.root.simdPosition.y + 0.04)) < reach }
    }

    /// Visible half-size of the view at depth z.
    func visibleHalfSize(atZ z: Float) -> SIMD2<Float> {
        let halfH = (cameraDistance - z) * tanHalfFOV
        return SIMD2(halfH * aspect, halfH)
    }

    /// View UV (0…1, y down) → point in the world at depth z.
    private func worldPoint(_ uv: SIMD2<Float>, z: Float) -> SIMD3<Float> {
        let h = visibleHalfSize(atZ: z)
        return SIMD3((uv.x * 2 - 1) * h.x, cameraY + (1 - uv.y * 2) * h.y, z)
    }

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
        let dt = min(max(rawDT, 1.0 / 240.0), 1.0 / 20.0)
        frameDT = dt
        let now = CACurrentMediaTime()
        clock += dt
        let beat = audio.beat
        let beatFraction = Float(beat - beat.rounded(.down))
        let beatPulse = exp(-beatFraction * 6)
        let beatIndex = Int(beat.rounded(.down))
        let onBeat = beatIndex != lastBeatIndex
        lastBeatIndex = beatIndex

        var hands = input.advance(dt: dt, now: now)
        if let p = pointer {
            let previous = pointerPrevious ?? p
            hands.removeAll { $0.slot == 0 }
            let pose: HandPose = controlScheme == .fist || pointerErases ? .fist : .pinch
            hands.append(HandState(slot: 0, pose: pose, position: p,
                                   velocity: (p - previous) / dt, tracking: true, isPointer: true))
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
            let mode = controlScheme.mode(for: hand?.pose, tool: tool)
            if buddy.setMode(mode) {
                audio.play(.swap, pan: buddy.slot == 0 ? -0.5 : 0.5)
            }
            if mode != .paint { finishStroke(slot: buddy.slot) }

            // Painting, the animal comes down close to the canvas so its tentacles can lie on it.
            // A bigger brush animal hovers higher, so its body stays clear of the canvas.
            let bigBrush = buddy.critter.usesSizeSlider ? max(octopusSize, 1) : 1
            let buddyZ: Float = mode == .paint ? Self.canvasZ + (Self.paintHoverZ - Self.canvasZ) * bigBrush : 0.42
            if buddy.critter.usesSizeSlider { buddy.critter.sizeScale = octopusSize }
            let target: SIMD3<Float>
            if let hand {
                target = worldPoint(hand.position, z: buddyZ)
            } else {
                // Idle: swim lazy loops so the buddies always feel alive.
                let h = visibleHalfSize(atZ: buddyZ)
                let t = clock * 0.35 + Float(buddy.slot) * 3.1
                target = SIMD3(sin(t) * h.x * 0.6, cameraY - h.y * 0.62 + sin(t * 2.3) * 0.15, buddyZ)
            }
            buddy.critter.update(dt: dt, target: target, visible: !buddy.showsStarfish,
                                 painting: (mode == .paint || mode == .erase) && !buddy.showsStarfish,
                              beatPulse: beatPulse)
            buddy.starfish.update(dt: dt, target: SIMD3(target.x, target.y, 0.3), visible: buddy.showsStarfish,
                                  beatPulse: beatPulse)

            movement += min(buddy.toolSpeed, 4) * (hand == nil ? 0 : 1)
            switch mode {
            case .paint:
                drawingNow = true
                paint(with: buddy, now: now)
            case .erase:
                erasingNow = true
                erase(with: buddy, now: now)
            case .idle, .swim:
                break
            }
            rubPots(buddy, dt: dt, now: now)
            if let hand, !hand.isPointer {
                recorded.append(SessionRecorder.Hand(slot: hand.slot, pose: hand.pose,
                                                     painting: mode == .paint || mode == .erase,
                                                     canvas: canvasUV(buddy.toolPosition)))
            }
        }
        if !isAway { recorder.record(hands: recorded, dt: Double(dt)) }
        var rubbing = false
        for pot in pots {
            let rubbers = buddies.filter { $0.rubbingPot == .color(pot.colorIndex) }
            let progress = rubbers.map(\.rubAmount).max() ?? 0
            if progress > 0 { rubbing = true }
            let wearing = buddies.filter { $0.colorIndex == pot.colorIndex }.count
            pot.update(dt: dt, beatPulse: beatPulse, rubProgress: min(progress, 1), selectedCount: wearing)
        }
        for pot in critterPots {
            let rubbers = buddies.filter { $0.rubbingPot == pot.target }
            let progress = rubbers.map(\.rubAmount).max() ?? 0
            if progress > 0 { rubbing = true }
            let wearers = buddies.filter { wears($0, pot.target) }
            let paints: Bool
            if case .tool(let tool) = pot.target { paints = tool.usesColor } else { paints = true }
            pot.update(dt: dt, beatPulse: beatPulse, rubProgress: min(progress, 1), selectedCount: wearers.count,
                       color: paints ? wearers.first?.color : nil)
        }
        for pot in templatePots {
            let rubbers = buddies.filter { $0.rubbingPot == .template(pot.kind) }
            let progress = rubbers.map(\.rubAmount).max() ?? 0
            if progress > 0 { rubbing = true }
            pot.update(dt: dt, beatPulse: beatPulse, rubProgress: min(progress, 1), selected: template?.kind == pot.kind)
        }
        template?.update()

        paintLayer.update(dt: dt)

        effects.update(dt: dt)
        shake = max(0, shake - dt * 4)
        let jolt = shake * shake * 0.05
        cameraNode.simdPosition = SIMD3(Float.random(in: -jolt...jolt), cameraY + Float.random(in: -jolt...jolt),
                                        cameraDistance)

        // Music swells with how much you move.
        energy += (min(movement / 3, 1) - energy) * min(1, dt * 1.5)
        audio.update(energy: energy, now: now)

        publishHUD(dt: dt, hands: hands, drawing: drawingNow, erasing: erasingNow, rubbing: rubbing)
    }

    /// A world point → canvas (0…1, y down), nil when it's off the canvas.
    private func canvasUV(_ p: SIMD3<Float>) -> SIMD2<Float>? {
        let size = Self.canvasSize
        let uv = SIMD2((p.x + size.x * 0.5) / size.x, (0.1 + size.y * 0.5 - p.y) / size.y)
        guard uv.x >= 0, uv.x <= 1, uv.y >= 0, uv.y <= 1 else { return nil }
        return uv
    }

    private func panFor(_ x: Float) -> Float {
        max(-1, min(1, x / max(visibleHalfSize(atZ: 0.5).x, 0.1)))
    }

    // MARK: - Painting

    private func paint(with buddy: Buddy, now: Double) {
        let slot = buddy.slot
        let p3 = buddy.critter.position.value
        let half = Self.canvasSize * 0.5 - SIMD2(repeating: Self.strokeRadius)
        let center = SIMD2<Float>(0, 0.1)
        var p = SIMD2(p3.x, p3.y)
        // Only a little slack sideways: reaching for a pot or bubble beside the canvas shouldn't paint.
        let onCanvas = abs(p.x - center.x) <= half.x + 0.05 && abs(p.y - center.y) <= half.y + 0.12
        // The template bubbles overlap the bottom of the canvas: rubbing one shouldn't smear paint.
        let onTemplatePot = templatePots.contains { pot in
            let c = pot.root.simdPosition
            return simd_distance(p, SIMD2(c.x, c.y + 0.04)) < PaintPot.radius + 0.14
        }
        guard onCanvas, !onTemplatePot, !isOverShelf(p) else {
            finishStroke(slot: slot)
            return
        }
        p = simd_clamp(p, center - half, center + half)

        // Lay real paint every frame, the way this tool (legacy: this brush animal) paints.
        let from = lastStamp[slot] ?? p
        // The octopus paints with its tentacles too, so its brush always comes from the animal itself.
        let dabs = controlScheme == .fist && buddy.tool != .brush
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
        if controlScheme == .fist && buddy.tool == .blender {
            if now - lastSlurp > 0.25 {
                lastSlurp = now
                audio.play(.slurp, a: min(buddy.critter.speed / 3, 1), pan: panFor(p.x))
            }
            return
        }

        let spacing = Self.strokeRadius * 0.6
        if let stroke = activeStroke[slot], let last = lastBead[slot] {
            let gap = simd_distance(p, last)
            guard gap >= spacing else { return }
            let steps = min(Int(gap / spacing), 12)
            for s in 1...steps {
                let q = last + (p - last) * (Float(s) / Float(steps))
                stroke.add(q, now: now)
            }
            lastBead[slot] = p
            blipDistance[slot, default: 0] += gap
            if blipDistance[slot, default: 0] > 0.16 {
                blipDistance[slot] = 0
                let height = (p.y - center.y) / Self.canvasSize.y + 0.5
                audio.play(.blip, a: height, pan: panFor(p.x))
            }
        } else {
            let stroke = Stroke(color: buddy.color, radius: Self.strokeRadius, surfaceZ: Self.canvasZ + Self.strokeRadius * 0.55,
                                brush: buddy.critter.kind)
            stroke.add(p, now: now)
            strokes.append(stroke)
            activeStroke[slot] = stroke
            lastBead[slot] = p
            buddy.critter.gulp()
            audio.play(.blip, a: (p.y - center.y) / Self.canvasSize.y + 0.5, pan: panFor(p.x))
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
            // Some brushes paint when you let go (the pufferfish bursts).
            if controlScheme == .legacy {
                lay(buddy.critter.released(), color: buddy.color, ncaModel: buddy.colorIndex,
                    seed: Float(slot) * 7.7 + Float(strokes.count), brush: buddy.critter.kind)
            }
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
        if abs(p.x) <= Self.canvasSize.x / 2, abs(p.y - 0.1) <= Self.canvasSize.y / 2 {
            timelapse.recordErase(at: p, radius: r, dt: frameDT)
        }
        // The legacy starfish scrubs the dotted guide away too; the garden mushroom only wipes paint.
        var erasedAny = buddy.showsStarfish ? (template?.erase(at: p, radius: r) ?? false) : false
        if let outline = template, outline.isEmpty {
            outline.node.removeFromParentNode()
            template = nil
        }
        var newStrokes: [Stroke] = []
        for stroke in strokes {
            guard stroke.points.contains(where: { simd_distance($0.p, p) < r }) else {
                newStrokes.append(stroke)
                continue
            }
            erasedAny = true
            // Split into the runs that survive.
            var runs: [[StrokePoint]] = [[]]
            for point in stroke.points {
                if simd_distance(point.p, p) < r {
                    if !(runs.last?.isEmpty ?? true) { runs.append([]) }
                } else {
                    runs[runs.count - 1].append(point)
                }
            }
            runs.removeAll { $0.isEmpty }
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
            if now - lastSqueak > 0.09 {
                lastSqueak = now
                audio.play(buddy.showsStarfish ? .squeak : .poof, pan: panFor(p.x))
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
        func stop() {
            buddy.rubbingPot = nil
            buddy.rubAmount = 0
            buddy.critter.colorPreview = nil
        }
        // The garden eraser is a critter like any other, so it can dip into pots and bubbles while it erases
        // (a mouse or finger is always "fist", so the mushroom would otherwise be stuck as the mushroom).
        let canRub = buddy.mode == .swim || buddy.mode == .paint || (buddy.mode == .erase && !buddy.erasesWithStarfish)
        guard canRub else { return stop() }
        let p = buddy.toolPosition
        func near(_ c: SIMD3<Float>) -> Bool {
            simd_distance(SIMD2(p.x, p.y), SIMD2(c.x, c.y + 0.04)) < PaintPot.radius + 0.14
        }
        let target: PotTarget
        let potPosition: SIMD3<Float>
        if let pot = pots.first(where: { near($0.root.simdPosition) }), pot.colorIndex != buddy.colorIndex {
            target = .color(pot.colorIndex)
            potPosition = pot.root.simdPosition
        } else if let pot = critterPots.first(where: { near($0.root.simdPosition) }), !wears(buddy, pot.target) {
            target = pot.target
            potPosition = pot.root.simdPosition
        } else if let pot = templatePots.first(where: { near($0.root.simdPosition) }), pot.kind != template?.kind {
            target = .template(pot.kind)
            potPosition = pot.root.simdPosition
        } else {
            return stop()
        }
        if buddy.rubbingPot != target {
            buddy.rubbingPot = target
            buddy.rubAmount = 0
            bouncePot(target, 0.6)
        }
        // Slow animals (snail, jelly) can't rub fast, so just sitting in the pot counts for a lot too.
        buddy.rubAmount += dt * 0.9 + min(buddy.critter.speed, 3) * dt * 0.9
        let progress = min(buddy.rubAmount, 1)
        if case .color(let index) = target { buddy.critter.colorPreview = (Paint.colors[index], progress * 0.85) }
        let pan = panFor(potPosition.x)
        if now - (lastGurgle[buddy.slot] ?? 0) > 0.11 {
            lastGurgle[buddy.slot] = now
            audio.play(.gurgle, a: progress, pan: pan)
        }
        guard progress >= 1 else { return }
        buddy.rubbingPot = nil
        buddy.rubAmount = 0
        bouncePot(target, 1.5)
        switch target {
        case .color(let index):
            buddy.pick(index)
            // A colour belongs to one brush animal: dip into the other one's colour and become that animal.
            if controlScheme == .fist, buddy.tool.usesColor, let owner = Paint.owner(of: index), owner != buddy.critter.kind,
               let tool = PaintTool.allCases.first(where: { $0.critterKind == owner }) {
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
        case .critter(let kind):
            finishStroke(slot: buddy.slot)
            let old = buddy.become(kind)
            old.root.removeFromParentNode()
            scene.rootNode.addChildNode(buddy.critter.root)
            effects.colorSplash(at: potPosition + SIMD3(0, 0.15, 0.1), color: buddy.color)
            audio.play(.swap, pan: pan)
        case .tool(let tool):
            finishStroke(slot: buddy.slot)
            if pointerErases, buddy.slot == 0, controlScheme == .fist, tool != .eraser {
                // The eraser button would keep the pointer scrubbing: switch it off and take the new tool instead.
                toolBeforePointerErase = tool
                pointerErases = false
            } else if let old = buddy.equip(tool) {
                old.root.removeFromParentNode()
                scene.rootNode.addChildNode(buddy.critter.root)
            }
            effects.colorSplash(at: potPosition + SIMD3(0, 0.15, 0.1), color: tool.usesColor ? buddy.color : SIMD3(1, 1, 1))
            audio.play(.bonk, pan: pan)
        case .template(let kind):
            showTemplate(kind)
            effects.colorSplash(at: potPosition + SIMD3(0, 0.15, 0.1), color: kind.signatureColor)
            audio.play(.sparkle, pan: pan)
        }
    }

    /// Lays a new dotted outline on the canvas (replacing any other one). Paint already there stays.
    private func showTemplate(_ kind: TemplateKind) {
        showOutline(TemplateOutline(kind: kind, canvasCenter: SIMD2(0, 0.1), canvasSize: Self.canvasSize,
                                    z: Self.canvasZ + 0.0008))
    }

    private func showOutline(_ outline: TemplateOutline) {
        template?.fadeAway()
        scene.rootNode.addChildNode(outline.node)
        template = outline
    }

    /// The buddy already is this brush animal or holds this tool.
    private func wears(_ buddy: Buddy, _ target: PotTarget) -> Bool {
        switch target {
        case .critter(let kind): return buddy.critter.kind == kind
        case .tool(let tool): return buddy.tool == tool
        case .color, .template: return false
        }
    }

    private func bouncePot(_ target: PotTarget, _ strength: Float) {
        switch target {
        case .color(let index): pots.first { $0.colorIndex == index }?.bounce(strength)
        case .critter, .tool: critterPots.first { $0.target == target }?.bounce(strength)
        case .template(let kind): templatePots.first { $0.kind == kind }?.bounce(strength)
        }
    }

    private func publishHUD(dt: Float, hands: [HandState], drawing: Bool, erasing: Bool, rubbing: Bool) {
        let next: Hint
        if erasing {
            next = .erasing
        } else if drawing {
            next = .drawing
        } else if rubbing {
            next = .pickingColor
        } else if !strokes.isEmpty {
            next = .readyToHang
        } else if template != nil {
            next = .tracing
        } else if hands.contains(where: { $0.tracking && !$0.isPointer }) {
            next = .swimming
        } else if cameraStatus == .denied || cameraStatus == .unavailable {
            next = .touchMode
        } else if cameraStatus == .starting {
            next = .starting
        } else {
            next = .raiseHands
        }
        if next != hint { hint = next }
        let drawingExists = !strokes.isEmpty
        if drawingExists != hasDrawing { hasDrawing = drawingExists }
        let colors = buddies.map(\.colorIndex)
        if colors != buddyColors { buddyColors = colors }
        let kinds = buddies.map(\.critter.kind)
        if kinds != buddyKinds { buddyKinds = kinds }
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

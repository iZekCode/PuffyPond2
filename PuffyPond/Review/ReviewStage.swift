import CoreGraphics
import Foundation
import Observation
import QuartzCore
import SceneKit
import simd

/// The review page's 3D side: the bare canvas stays put while the paint, on an elastic transparent sheet
/// above it, is what the hands push and grab. Owns the camera hands, the solver and the gestures, and
/// rebuilds the sheet's mesh each frame.
///
/// The camera is orthographic and looks straight at the sheet, so a hand's spot on the screen maps
/// exactly onto the sheet (`sheetPoint(fromView:)`).
@Observable
final class ReviewStage {
    /// One hand as drawn on top of the page, in view UV (0…1, y down).
    struct Cursor: Equatable, Identifiable {
        var slot: Int
        var position: SIMD2<Float>
        var fist: Bool
        var id: Int { slot }
    }

    /// The page is either replaying how the painting was made, or letting the hands play with the sheet.
    enum Phase: Equatable {
        case timelapse
        case interactive
    }

    private(set) var phase: Phase = .interactive
    /// There is a timelapse to play again.
    private(set) var canReplay = false
    /// Makes what draws the timelapse picture; swapped in tests.
    @ObservationIgnored var makeRenderer: (CanvasPhotos, StrokeRecording, ReplayTimeline) -> ReplayRenderer = {
        MaskReplayer(finalPaint: $0.paint, recording: $1, timeline: $2)
    }
    /// Hands on screen, for the cursors.
    private(set) var cursors: [Cursor] = []
    /// Hover-and-hold progress (0…1) of the button an open hand rests on.
    private(set) var dwell: (id: String, progress: Double)?
    /// Called when a hover-and-hold completes.
    @ObservationIgnored var onPress: ((String) -> Void)?
    @ObservationIgnored var targets: [HoverTarget] = []
    /// Touch or mouse holding the sheet, in view UV; acts like a fist.
    @ObservationIgnored var pointer: SIMD2<Float>? {
        didSet {
            if let pointer, let oldValue {
                pointerVelocity = (pointer - oldValue) / Float(max(CACurrentMediaTime() - pointerTime, 1.0 / 120))
            } else {
                pointerVelocity = .zero
            }
            pointerTime = CACurrentMediaTime()
        }
    }

    @ObservationIgnored let scene = SCNScene()
    @ObservationIgnored let cameraNode = SCNNode()
    @ObservationIgnored let solver = SheetSolver()
    @ObservationIgnored let gestures = SheetGestures()
    @ObservationIgnored private let hands = HandInput()
    @ObservationIgnored private let sheet = SCNNode()
    @ObservationIgnored private let material = SCNMaterial()
    @ObservationIgnored private let canvasMaterial = SCNMaterial()
    @ObservationIgnored private let frameDriver = FrameDriver()
    @ObservationIgnored private var audio: GrooveEngine?
    @ObservationIgnored private var conductor: TimelapseConductor?
    @ObservationIgnored private var renderer: ReplayRenderer?
    @ObservationIgnored private var ripples: [Ripple] = []
    @ObservationIgnored private var aspect: Float = 16 / 10
    @ObservationIgnored private var halfHeight: Float = 3
    @ObservationIgnored private var pointerVelocity = SIMD2<Float>.zero
    @ObservationIgnored private var pointerTime: Double = 0
    @ObservationIgnored private var meshIsFlat = false
    @ObservationIgnored private var hover = HoverDwell()
    @ObservationIgnored private lazy var texcoordSource = Self.makeTexcoords()
    @ObservationIgnored private lazy var element = Self.makeElement()

    /// Ripples are pure decoration on top of the solver: ring waves that wobble the sheet up and down.
    private struct Ripple {
        var center: SIMD2<Float>
        var age: Float
        var strength: Float
    }

    /// Where the still canvas sits behind the paint sheet (z = 0).
    static let canvasDepth: Float = -0.3
    static let maxRipples = 16
    static let rippleLifetime: Float = 2

    init() {
        build()
        frameDriver.onFrame = { [weak self] dt in self?.tick(dt: Float(dt)) }
    }

    /// Shows the painting. With a recording that has something to replay the page starts in the timelapse phase.
    func show(_ photos: CanvasPhotos, recording: StrokeRecording?, audio: GrooveEngine) {
        canvasMaterial.diffuse.contents = photos.canvas
        material.diffuse.contents = photos.paint
        self.audio = audio
        meshIsFlat = false
        updateMesh()

        detachTimelapse()
        sheet.removeAllActions()
        sheet.opacity = 1
        phase = .interactive
        canReplay = false
        guard let recording, !recording.isEmpty else { return }
        let timeline = ReplayTimeline(eventTimes: recording.events.map(\.t))
        guard timeline.duration > 0 else { return }

        let renderer = makeRenderer(photos, recording, timeline)
        renderer.node.simdPosition = SIMD3(0, 0, Self.canvasDepth + 0.15)
        scene.rootNode.addChildNode(renderer.node)
        self.renderer = renderer
        conductor = TimelapseConductor(timeline: timeline, notes: NoteComposer.compose(recording, timeline: timeline))
        canReplay = true
        beginTimelapse()
    }

    /// Jumps to the end of the timelapse and lets the hands play.
    func skipTimelapse() {
        guard phase == .timelapse, let conductor else { return }
        conductor.skip()
        renderer?.advance(to: conductor.replayTime)
        finishTimelapse()
    }

    /// Plays the timelapse again; the sheet is put away until it ends.
    func replay() {
        guard phase == .interactive, canReplay else { return }
        gestures.reset(solver: solver)
        beginTimelapse()
    }

    /// One frame of the timelapse: sounds the notes that are due, draws the picture, and ends the phase when the
    /// replay has run out.
    func advanceTimelapse(dt: Double) {
        guard phase == .timelapse, let conductor, let renderer else { return }
        for note in conductor.advance(dt: dt, beat: audio?.beat ?? 0) {
            switch note.voice {
            case .note(let timbre): audio?.playNote(timbre: timbre, pitch: note.pitch, pan: note.pan)
            case .poof: audio?.play(.poof, pan: note.pan)
            }
        }
        renderer.advance(to: conductor.replayTime)
        if conductor.phase == .finished { finishTimelapse() }
    }

    private func beginTimelapse() {
        phase = .timelapse
        sheet.removeAllActions()
        sheet.opacity = 0
        renderer?.node.removeAllActions()
        renderer?.node.opacity = 1
        renderer?.reset()
        conductor?.start(beat: audio?.beat ?? 0)
    }

    /// The picture gives way to the sheet, which wakes up with a wobble.
    private func finishTimelapse() {
        phase = .interactive
        renderer?.node.runAction(.fadeOut(duration: 0.35))
        sheet.runAction(.fadeIn(duration: 0.35))
        addRipple(at: .zero, strength: 0.6)
        audio?.play(.wobble)
    }

    private func detachTimelapse() {
        conductor?.cancel()
        conductor = nil
        renderer?.node.removeFromParentNode()
        renderer = nil
    }

    func start() { frameDriver.start() }

    func stop() {
        detachTimelapse()
        frameDriver.stop()
        hands.reset()
        pointer = nil
        gestures.reset(solver: solver)
        cursors = []
        dwell = nil
    }

    func ingest(_ frame: HandFrame) { hands.ingest(frame) }

    /// Frames the sheet with room for the title above and the buttons below.
    func layout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        aspect = Float(size.width / size.height)
        let sheet = SheetSolver.size
        halfHeight = max(sheet.y * 0.5 / 0.66, sheet.x * 0.5 / (0.86 * aspect))
        cameraNode.camera?.orthographicScale = Double(halfHeight)
    }

    /// View UV (0…1, y down) → sheet space (y up).
    func sheetPoint(fromView uv: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2((uv.x - 0.5) * 2 * halfHeight * aspect, (0.5 - uv.y) * 2 * halfHeight)
    }

    private var viewToSheetScale: SIMD2<Float> { SIMD2(2 * halfHeight * aspect, -2 * halfHeight) }

    // MARK: - Frame

    private func tick(dt: Float) {
        let now = CACurrentMediaTime()
        let states = hands.advance(dt: dt, now: now)
        var sheetHands = states.map {
            SheetHand(slot: $0.slot, pose: $0.pose, position: sheetPoint(fromView: $0.position),
                      velocity: $0.velocity * viewToSheetScale, tracking: $0.tracking)
        }
        if let pointer {
            sheetHands.append(SheetHand(slot: 2, pose: .fist, position: sheetPoint(fromView: pointer),
                                        velocity: pointerVelocity * viewToSheetScale, tracking: true))
        }
        // The timelapse is watched, not touched: the sheet is hidden and no hand or finger reaches it.
        if phase == .timelapse {
            sheetHands.removeAll()
            advanceTimelapse(dt: Double(dt))
        }

        // A hand resting on a button is pressing it, not playing with the sheet.
        let hovering = updateDwell(states, dt: Double(dt))
        if hovering { sheetHands.removeAll { $0.slot < 2 && $0.pose != .fist } }

        for event in gestures.update(hands: sheetHands, dt: dt, solver: solver) { react(to: event) }
        solver.step(Double(dt))

        for k in ripples.indices { ripples[k].age += dt }
        ripples.removeAll { $0.age > Self.rippleLifetime }
        updateMesh()

        let next = states.filter(\.tracking).map { Cursor(slot: $0.slot, position: $0.position, fist: $0.pose == .fist) }
        if next != cursors { cursors = next }
    }

    private func react(to event: SheetGestures.Event) {
        switch event {
        case .grabbed(let p):
            addRipple(at: p, strength: 0.25)
            audio?.play(.sproing, pan: pan(p))
        case .released(let p):
            addRipple(at: p, strength: 0.6)
            audio?.play(.wobble, pan: pan(p))
        case let .pushed(p, strength):
            addRipple(at: p, strength: strength)
            // Mostly wet slaps, now and then a duck.
            if Int.random(in: 0..<8) == 0 {
                audio?.play(.quack, pan: pan(p))
            } else {
                audio?.play(strength > 0.6 ? .splat : .splash, a: strength, pan: pan(p))
            }
        case .stretchStarted:
            audio?.play(.whistleUp)
        case .stretchEnded(let p):
            addRipple(at: p, strength: 0.5)
            audio?.play(.whistleDown)
        }
    }

    private func pan(_ p: SIMD2<Float>) -> Float { min(max(p.x / (SheetSolver.size.x * 0.5), -1), 1) }

    private func addRipple(at center: SIMD2<Float>, strength: Float) {
        ripples.append(Ripple(center: center, age: 0, strength: strength))
        if ripples.count > Self.maxRipples { ripples.removeFirst(ripples.count - Self.maxRipples) }
    }

    /// Open camera hands resting on a button fill its ring; a full ring presses it once until the hand leaves.
    private func updateDwell(_ states: [HandState], dt: Double) -> Bool {
        let open = states.filter { $0.tracking && $0.pose != .fist }
        let hit = targets.first { target in
            open.contains { target.frame.contains(CGPoint(x: CGFloat($0.position.x), y: CGFloat($0.position.y))) }
        }
        let pressed = hover.update(hoveredID: hit?.id, dt: dt)
        let ring = hover.progress.map { (id: $0.id, progress: $0.value) }
        if ring?.id != dwell?.id || ring?.progress != dwell?.progress { dwell = ring }
        if let pressed { onPress?(pressed) }
        return hit != nil
    }

    // MARK: - Mesh

    private func updateMesh() {
        let flat = solver.isSleeping && ripples.isEmpty
        if flat && meshIsFlat { return }
        meshIsFlat = flat

        let columns = SheetSolver.columns
        let rows = SheetSolver.rows
        let n = solver.count
        var positions = [Float](repeating: 0, count: n * 3)
        var heights = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let p = solver.position(i)
            let z = rippleHeight(at: solver.rest[i])
            heights[i] = z
            positions[i * 3] = p.x
            positions[i * 3 + 1] = p.y
            positions[i * 3 + 2] = z
        }

        // Normals from the neighbours, so the ripples catch the light.
        var normals = [Float](repeating: 0, count: n * 3)
        for row in 0..<rows {
            for column in 0..<columns {
                let i = row * columns + column
                let l = row * columns + max(column - 1, 0)
                let r = row * columns + min(column + 1, columns - 1)
                let u = max(row - 1, 0) * columns + column
                let d = min(row + 1, rows - 1) * columns + column
                func point(_ k: Int) -> SIMD3<Float> {
                    SIMD3(positions[k * 3], positions[k * 3 + 1], positions[k * 3 + 2])
                }
                let across = point(r) - point(l)
                let down = point(d) - point(u)
                var normal = simd_cross(down, across)
                if simd_length(normal) < 1e-8 { normal = SIMD3(0, 0, 1) }
                normal = simd_normalize(normal)
                if normal.z < 0 { normal = -normal }
                normals[i * 3] = normal.x
                normals[i * 3 + 1] = normal.y
                normals[i * 3 + 2] = normal.z
            }
        }

        let vertexSource = Self.source(positions, semantic: .vertex, count: n)
        let normalSource = Self.source(normals, semantic: .normal, count: n)
        let geometry = SCNGeometry(sources: [vertexSource, normalSource, texcoordSource], elements: [element])
        geometry.materials = [material]
        sheet.geometry = geometry
    }

    /// Expanding ring waves, fading out over `rippleLifetime`.
    private func rippleHeight(at p: SIMD2<Float>) -> Float {
        var z: Float = 0
        for ripple in ripples {
            let fade = 1 - ripple.age / Self.rippleLifetime
            let ring = ripple.age * 2.2
            let r = simd_distance(p, ripple.center) - ring
            z += 0.06 * ripple.strength * fade * fade * exp(-(r / 0.45) * (r / 0.45)) * sin(r * 10)
        }
        return z
    }

    private static func source(_ values: [Float], semantic: SCNGeometrySource.Semantic, count: Int) -> SCNGeometrySource {
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return SCNGeometrySource(data: data, semantic: semantic, vectorCount: count, usesFloatComponents: true,
                                 componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
    }

    private static func makeTexcoords() -> SCNGeometrySource {
        var uv: [Float] = []
        for row in 0..<SheetSolver.rows {
            for column in 0..<SheetSolver.columns {
                uv.append(Float(column) / Float(SheetSolver.columns - 1))
                uv.append(Float(row) / Float(SheetSolver.rows - 1))
            }
        }
        let data = uv.withUnsafeBufferPointer { Data(buffer: $0) }
        return SCNGeometrySource(data: data, semantic: .texcoord, vectorCount: uv.count / 2, usesFloatComponents: true,
                                 componentsPerVector: 2, bytesPerComponent: 4, dataOffset: 0, dataStride: 8)
    }

    private static func makeElement() -> SCNGeometryElement {
        var indices: [UInt16] = []
        let columns = SheetSolver.columns
        for row in 0..<(SheetSolver.rows - 1) {
            for column in 0..<(columns - 1) {
                let a = UInt16(row * columns + column)
                let b = a + 1
                let c = a + UInt16(columns)
                let d = c + 1
                indices += [a, c, b, b, c, d]
            }
        }
        return SCNGeometryElement(indices: indices, primitiveType: .triangles)
    }

    // MARK: - Scene

    private func build() {
        scene.background.contents = Self.backdrop()

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(halfHeight)
        camera.zNear = 0.1
        camera.zFar = 30
        cameraNode.camera = camera
        cameraNode.simdPosition = SIMD3(0, 0, 10)
        scene.rootNode.addChildNode(cameraNode)

        // Mostly flat light, with a soft key from the upper left so the ripples catch shade.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 620
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 420
        key.simdLook(at: SIMD3(0.35, -0.4, -1), up: SIMD3(0, 1, 0), localFront: SIMD3(0, 0, -1))
        scene.rootNode.addChildNode(key)

        // Both layers share the same plain lighting, so at rest the paint sits on the canvas exactly as photographed.
        // No specular: on a premultiplied, see-through sheet it would haze the canvas where there is no paint.
        for layer in [canvasMaterial, material] {
            layer.lightingModel = .lambert
            layer.isDoubleSided = true
            layer.diffuse.wrapS = .clamp
            layer.diffuse.wrapT = .clamp
            layer.diffuse.mipFilter = .linear
        }

        // The bare canvas never moves.
        let canvas = SCNNode(geometry: SCNPlane(width: CGFloat(SheetSolver.size.x), height: CGFloat(SheetSolver.size.y)))
        canvas.geometry?.materials = [canvasMaterial]
        canvas.simdPosition = SIMD3(0, 0, Self.canvasDepth)
        scene.rootNode.addChildNode(canvas)

        // The paint is drawn over it in triangle order, with no depth test: where the sheet folds over itself
        // the layers stack the same way every frame instead of z-fighting into see-through patches.
        material.transparencyMode = .aOne
        material.blendMode = .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        sheet.renderingOrder = 10
        scene.rootNode.addChildNode(sheet)

        // A soft drop shadow so the canvas sits above the page.
        let shadow = SCNNode(geometry: SCNPlane(width: CGFloat(SheetSolver.size.x) + 0.3,
                                                height: CGFloat(SheetSolver.size.y) + 0.3))
        let shadowMaterial = SCNMaterial()
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = PlatformColor.black
        shadowMaterial.transparency = 0.12
        shadowMaterial.writesToDepthBuffer = false
        shadow.geometry?.materials = [shadowMaterial]
        shadow.simdPosition = SIMD3(0.06, -0.12, Self.canvasDepth - 0.3)
        scene.rootNode.addChildNode(shadow)
        updateMesh()
    }

    /// The page's soft pond gradient (matches `PageBackground`).
    private static func backdrop() -> CGImage? {
        Toybox.image(width: 8, height: 256) { ctx in
            let colors = [CGColor(red: 1, green: 0.93, blue: 0.95, alpha: 1),
                          CGColor(red: 0.86, green: 0.95, blue: 1, alpha: 1)] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                            locations: [0, 1]) else { return }
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
    }
}

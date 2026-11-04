import SceneKit
import simd

/// The studio around the easel: the camera, the lights, the linen canvas, and the paint pot and critter bubble
/// columns beside it. The camera backs off until all of it fits the window (see `CanvasLayout`).
final class EaselScene {
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

    let scene: SCNScene
    let cameraNode = SCNNode()
    private(set) var pots: [PaintPot] = []
    private(set) var critterPots: [CritterPot] = []
    private(set) var layout = CanvasLayout()
    private let canvasNode = SCNNode()
    private var canvasBoard: SCNNode?
    private var studioLights: [SCNNode] = []

    init(scene: SCNScene, paint: SCNNode) {
        self.scene = scene
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
        cameraNode.simdPosition = SIMD3(0, CanvasLayout.cameraY, layout.cameraDistance)
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
        let size = CanvasLayout.canvasSize
        let linen = Studio.canvasMaterial(repeats: size / Studio.weaveTileSize)
        let depth: Float = 0.16
        let board = Toybox.node(SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(depth),
                                       chamferRadius: 0.012), linen, at: SIMD3(0, 0, CanvasLayout.canvasZ - depth / 2))
        canvasNode.addChildNode(board)
        canvasBoard = board
        // No easel frame: the canvas stands free, with the pot and bubble columns beside it.
        canvasNode.simdPosition = SIMD3(0, 0.1, 0)
        scene.rootNode.addChildNode(canvasNode)

        scene.rootNode.addChildNode(paint)
        // Two columns just outside the canvas, so dipping never smears the painting:
        // paint pots above the top-right corner and down the right (rub a critter in one to pick up its color),
        // critter bubbles down the left (rub one to become that brush animal, or to pick up that paint tool).
        let potColors = Paint.potOrder
        for (k, colorIndex) in potColors.enumerated() {
            let spot = CanvasLayout.potPosition(k, of: potColors.count)
            let pot = PaintPot(colorIndex: colorIndex, at: SIMD3(spot.x, spot.y, CanvasLayout.potZ))
            scene.rootNode.addChildNode(pot.root)
            pots.append(pot)
        }
        for (k, tool) in PaintTool.allCases.enumerated() {
            let y = CanvasLayout.columnY(k, of: PaintTool.allCases.count)
            critterPots.append(CritterPot(tool: tool, at: SIMD3(-CanvasLayout.shelfX, y, 0.3)))
        }
        for pot in critterPots {
            scene.rootNode.addChildNode(pot.root)
            scene.rootNode.addChildNode(pot.residentRoot)
        }

        fit(size: CGSize(width: 1600, height: 1000))
    }

    /// Fits the whole canvas and the two columns beside it (paint pots on the right, bubbles on the left) into any
    /// window shape, with a little room around them, so nothing is hidden behind a pot or a bubble.
    func fit(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        layout.fit(width: Float(size.width), height: Float(size.height))
        cameraNode.simdPosition = SIMD3(0, CanvasLayout.cameraY, layout.cameraDistance)
        placeShelves()
    }

    /// Stands the paint pots in a column beside the right edge of the canvas and the bubbles beside the left edge.
    private func placeShelves() {
        for (k, pot) in pots.enumerated() {
            let spot = CanvasLayout.potPosition(k, of: pots.count)
            pot.root.simdPosition.x = spot.x
            pot.root.simdPosition.y = spot.y
        }
        for pot in critterPots { pot.root.simdPosition.x = -CanvasLayout.shelfX }
    }

    /// Whether `p` (canvas plane) is under a pot or bubble: rubbing one must not paint or erase behind it.
    func isOverShelf(_ p: SIMD2<Float>) -> Bool {
        pots.contains { CanvasLayout.touches(p, potAt: $0.root.simdPosition) }
            || critterPots.contains { CanvasLayout.touches(p, potAt: $0.root.simdPosition, radius: CanvasLayout.bubbleRadius) }
    }

    /// Puts the camera back at rest, nudged up to `jolt` in a random direction (the shake after a pop).
    func shakeCamera(_ jolt: Float) {
        cameraNode.simdPosition = SIMD3(Float.random(in: -jolt...jolt),
                                        CanvasLayout.cameraY + Float.random(in: -jolt...jolt), layout.cameraDistance)
    }

    /// The booth that photographs the finished canvas with this `paint` on it.
    func photoBooth(paint: SCNNode) -> CanvasPhotoBooth? {
        guard let canvasBoard else { return nil }
        return CanvasPhotoBooth(board: canvasBoard, paint: paint, lights: studioLights, studio: scene,
                                studioCamera: cameraNode.camera)
    }
}

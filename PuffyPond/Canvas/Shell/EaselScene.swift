import SceneKit
import simd

/// The scene: the camera, the lights, the linen canvas (which fills the whole window) and the four characters
/// floating along its bottom edge (see `CanvasLayout`).
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
    private(set) var perches: [CharacterPerch] = []
    private(set) var layout = CanvasLayout()
    private let canvasNode = SCNNode()
    private var canvasBoard: SCNNode?
    private var studioLights: [SCNNode] = []

    init(scene: SCNScene, paint: SCNNode) {
        self.scene = scene
        // The canvas fills the window, so no room around it: a plain linen colour shows if a pixel ever falls outside.
        scene.background.contents = PlatformColor(red: 0.93, green: 0.92, blue: 0.9, alpha: 1)
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
        camera.vignettingIntensity = 0
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
        canvasNode.simdPosition = SIMD3(0, 0.1, 0)
        scene.rootNode.addChildNode(canvasNode)

        scene.rootNode.addChildNode(paint)
        // The four characters float in a row along the bottom: rub a buddy over one to become it.
        for tool in PaintTool.allCases {
            perches.append(CharacterPerch(tool: tool, at: SIMD3(0, 0, CanvasLayout.characterZ)))
        }
        for perch in perches {
            scene.rootNode.addChildNode(perch.root)
            scene.rootNode.addChildNode(perch.residentRoot)
        }

        fit(size: CGSize(width: 1600, height: 1000))
    }

    /// Fills any window shape with canvas and lines the four characters up along its bottom edge.
    func fit(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        layout.fit(width: Float(size.width), height: Float(size.height))
        cameraNode.simdPosition = SIMD3(0, CanvasLayout.cameraY, layout.cameraDistance)
        placePerches()
    }

    private func placePerches() {
        let slots = layout.characterSlots(count: perches.count)
        for (perch, slot) in zip(perches, slots) {
            perch.root.simdPosition.x = slot.x
            perch.root.simdPosition.y = slot.y
        }
    }

    /// Whether `p` (canvas plane) is under a waiting character: rubbing one must not paint behind it.
    func isOverShelf(_ p: SIMD2<Float>) -> Bool {
        perches.contains { CanvasLayout.touches(p, characterAt: $0.root.simdPosition) }
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

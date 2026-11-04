import Metal
import SceneKit
import simd

/// Renders the canvas head-on in a little photo booth: copies of the board and the live paint,
/// the studio's own lights, no critters, pots or tracing guide in the way.
struct CanvasPhotoBooth {
    let board: SCNNode
    let paint: SCNNode
    let lights: [SCNNode]
    /// The studio scene, for its lighting environment.
    let studio: SCNScene
    let studioCamera: SCNCamera?

    func photos(pixels width: CGFloat = 1920) -> CanvasPhotos? {
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
        let booth = SCNScene()
        if let background { booth.background.contents = background }
        booth.lightingEnvironment.contents = studio.lightingEnvironment.contents
        booth.lightingEnvironment.intensity = studio.lightingEnvironment.intensity
        if showBoard {
            let copy = board.clone()
            copy.simdTransform = board.simdWorldTransform
            booth.rootNode.addChildNode(copy)
        }
        if showPaint { booth.rootNode.addChildNode(paint.clone()) }
        for light in lights { booth.rootNode.addChildNode(light.clone()) }

        let size = CanvasLayout.canvasSize
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(size.y * 0.5 * 0.99)   // a hair inside the chamfered edge
        camera.zNear = 0.1
        camera.zFar = 20
        if let studio = studioCamera {
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
}

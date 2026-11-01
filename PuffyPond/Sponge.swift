import SceneKit
import simd

/// Blender: a squishy sea sponge. It lays no paint of its own; it scrubs over the wet paint and
/// smudges the colors into each other. It wobbles and squeezes while it works.
final class Sponge: Critter {
    private let body: SCNNode
    private var squeeze = Spring1(0)

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        body = SCNNode()
        super.init(kind: .sponge, color: color, at: start, accentLift: 0.3)
        squashNode.addChildNode(body)
        body.addChildNode(Toybox.node(SCNBox(width: 0.3, height: 0.26, length: 0.18, chamferRadius: 0.07),
                                      bodyMaterial))

        // Pores: soft dark dimples around the face.
        let pore = SCNMaterial()
        pore.lightingModel = .physicallyBased
        pore.diffuse.contents = PlatformColor(red: 0.25, green: 0.15, blue: 0.08, alpha: 1)
        pore.roughness.contents = NSNumber(value: 0.8)
        pore.transparency = 0.35
        let spots: [(SIMD2<Float>, Float)] = [(SIMD2(-0.11, 0.09), 0.022), (SIMD2(0.115, 0.085), 0.018),
                                              (SIMD2(-0.1, -0.085), 0.02), (SIMD2(0.105, -0.08), 0.024),
                                              (SIMD2(0.0, 0.1), 0.014), (SIMD2(-0.125, 0.0), 0.014),
                                              (SIMD2(0.13, 0.01), 0.016)]
        for (p, r) in spots {
            body.addChildNode(Toybox.node(SCNSphere(radius: CGFloat(r)), pore, at: SIMD3(p.x, p.y, 0.088),
                                          scale: SIMD3(1, 1, 0.4)))
        }
        addFace(eyes: [EyeSpot(position: SIMD3(-0.055, 0.03, 0.095), yaw: -0.2, browSign: -1),
                       EyeSpot(position: SIMD3(0.055, 0.03, 0.095), yaw: 0.2, browSign: 1)],
                eyeRadius: 0.045, mouth: SIMD3(0, -0.05, 0.093), mouthRadius: 0.018,
                cheeks: [SIMD3(-0.09, -0.04, 0.09), SIMD3(0.09, -0.04, 0.09)], parent: body)
    }

    override var blowsInk: Bool { false }

    override func flare(_ amount: Float) {
        squeeze.velocity += 4 * amount
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        // Scrubbing: it squeezes flat and wobbles side to side.
        squeeze.step(to: painting ? 1 : 0, stiffness: 140, damping: 9, dt: dt)
        let s = squeeze.value
        let wobble = painting ? sin(clock * 18) * 0.12 * s : 0
        body.simdScale = SIMD3(1 + s * 0.12 + wobble, 1 - s * 0.14, 1)
    }

    override func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        PaintTool.blender.dabs(from: a, to: b, radius: radius, speed: speed)
    }
}

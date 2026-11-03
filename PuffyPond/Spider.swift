import SceneKit
import simd

/// Garden spider brush: a chubby, fuzzy, wide-eyed puffball with eight long legs. While painting the legs lie flat
/// on the canvas and are the brush, exactly like the octopus's tentacles (see `LimbBrush`).
final class Spider: Critter {
    private let legs: TentacleBundle
    private let limbs: LimbBrush
    private let fuzz = SCNNode()

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        let count = 8
        let roots = (0..<count).map { k -> (local: SIMD3<Float>, outward: SIMD3<Float>) in
            let a = (Float(k) + 0.5) / Float(count) * 2 * .pi
            return (SIMD3(cos(a) * 0.1, -0.03, sin(a) * 0.085), SIMD3(cos(a), 0, sin(a) * 0.6))
        }
        // Long, slender, fairly stiff legs.
        var shape = TentacleBundle.Shape()
        shape.segments = 9
        shape.segmentLength = 0.045
        shape.rootRadius = 0.014
        shape.tipRadius = 0.005
        shape.startAngle = 0.9
        shape.curl = 0.9
        shape.sway = 0.35
        shape.stiffness = 0.16
        shape.gravity = 1.0
        shape.ripple = 0.05
        legs = TentacleBundle(shape: shape, roots: roots, start: start)
        limbs = LimbBrush(bundle: legs, limbZ: Octopus.limbZ)
        super.init(kind: .spider, color: color, at: start, accentLift: 0.3)
        legs.setSpokes((0..<count).map { k in
            let a = (Float(k) + 0.5) / Float(count) * 2 * .pi
            return SIMD2(cos(a), sin(a))
        })
        legs.material = accentMaterial
        root.addChildNode(legs.node)

        // One big round fuzzy body that is all face, with a few tufts on top.
        squashNode.addChildNode(fuzz)
        fuzz.addChildNode(Toybox.node(SCNSphere(radius: 0.15), bodyMaterial, at: SIMD3(0, 0.02, 0),
                                      scale: SIMD3(1.1, 1.0, 1.0)))
        for (x, y, r) in [(-0.05, 0.16, 0.035), (0.0, 0.18, 0.04), (0.05, 0.16, 0.035)] as [(Float, Float, Float)] {
            fuzz.addChildNode(Toybox.node(SCNSphere(radius: CGFloat(r)), accentMaterial, at: SIMD3(x, y, 0.02)))
        }
        addFace(eyes: [EyeSpot(position: SIMD3(-0.062, 0.03, 0.125), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.062, 0.03, 0.125), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.064, mouth: SIMD3(0, -0.055, 0.135), mouthRadius: 0.02,
                cheeks: [SIMD3(-0.105, -0.03, 0.105), SIMD3(0.105, -0.03, 0.105)], parent: fuzz)
    }

    override var usesSizeSlider: Bool { true }

    override func flare(_ amount: Float) {
        legs.flare(amount, body: leanNode.simdWorldTransform)
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        // A happy little sway, quicker while painting.
        let rate: Float = painting ? 7 : 2.4
        fuzz.simdEulerAngles = SIMD3(0, 0, sin(clock * rate) * (painting ? 0.09 : 0.05))
        limbs.animate(dt: dt, velocity: SIMD2(position.velocity.x, position.velocity.y), head: bodyNode.simdPosition,
                      body: leanNode.simdWorldTransform, scale: scale, clock: clock, beatPulse: beatPulse,
                      pressing: painting && !hidden, hidden: hidden)
    }

    override func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        limbs.dabs(towards: b)
    }
}

import SceneKit
import simd

/// Bundle brush: a glossy head with a face and eight jiggly tentacles. While painting the tentacles lie flat on
/// the canvas and are the brush: every stretch that touches it paints, and holding still makes them all ooze.
final class Octopus: Critter {
    private let tentacles: TentacleBundle
    private let limbs: LimbBrush
    /// Height of a limb's centre when it lies on the canvas (just above the canvas face).
    static let limbZ: Float = Playground.canvasZ + 0.02

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        let count = 8
        let roots = (0..<count).map { k -> (local: SIMD3<Float>, outward: SIMD3<Float>) in
            let a = (Float(k) + 0.5) / Float(count) * 2 * .pi
            // Spread wider sideways than front-to-back so you see every tentacle from the front.
            return (SIMD3(cos(a) * 0.09, -0.07, sin(a) * 0.075), SIMD3(cos(a), 0, sin(a) * 0.6))
        }
        tentacles = TentacleBundle(shape: .init(), roots: roots, start: start)
        limbs = LimbBrush(bundle: tentacles, limbZ: Self.limbZ)
        super.init(kind: .octopus, color: color, at: start)
        // Lying on the canvas the eight limbs fan out evenly around the head, like a star.
        tentacles.setSpokes((0..<count).map { k in
            let a = (Float(k) + 0.5) / Float(count) * 2 * .pi
            return SIMD2(cos(a), sin(a))
        })
        tentacles.material = accentMaterial
        root.addChildNode(tentacles.node)

        // Head: a tall round mantle over a wider "skirt" where the tentacles start.
        squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.15), bodyMaterial,
                                            at: SIMD3(0, 0.05, -0.01), scale: SIMD3(1.05, 1.2, 0.95)))
        squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.11), bodyMaterial,
                                            at: SIMD3(0, -0.06, 0), scale: SIMD3(1.2, 0.6, 1.1)))
        addFace(eyes: [EyeSpot(position: SIMD3(-0.062, 0, 0.118), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.062, 0, 0.118), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.06, mouth: SIMD3(0, -0.07, 0.115), mouthRadius: 0.022,
                cheeks: [SIMD3(-0.1, -0.05, 0.105), SIMD3(0.1, -0.05, 0.105)])
    }

    override func flare(_ amount: Float) {
        tentacles.flare(amount, body: leanNode.simdWorldTransform)
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        limbs.animate(dt: dt, velocity: SIMD2(position.velocity.x, position.velocity.y), head: bodyNode.simdPosition,
                      body: leanNode.simdWorldTransform, scale: scale, clock: clock, beatPulse: beatPulse,
                      pressing: painting && !hidden, hidden: hidden)
    }

    override func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        limbs.dabs(towards: b)
    }
}

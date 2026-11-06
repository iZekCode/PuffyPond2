import SceneKit
import simd

/// A round green frog that sits facing you: a wide squat body with a pale belly, two bulging eyes on top and a
/// little smile. The throat puffs with the beat, the folded back legs wobble behind it when it moves, and it
/// hops a little while it paints. It paints green.
final class Frog: Critter {
    private let belly = SCNNode()
    private var legs: [SCNNode] = []
    private var bulbs: [SCNNode] = []
    private var legLag = Spring1(0)

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        super.init(kind: .frog, color: color, at: start, accentLift: 0.35)
        let dark = Toybox.balloon(SIMD3(0.1, 0.25, 0.14), wobble: 0, roughness: 0.5)

        // Wide, squat body.
        squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.17), bodyMaterial, at: SIMD3(0, -0.03, 0),
                                            scale: SIMD3(1.2, 0.88, 1.0)))
        // Pale belly bulging at the front, under the mouth.
        belly.simdPosition = SIMD3(0, -0.09, 0.09)
        belly.addChildNode(Toybox.node(SCNSphere(radius: 0.12), accentMaterial, scale: SIMD3(1.15, 0.85, 0.8)))
        squashNode.addChildNode(belly)

        // Bulging eye bulbs on top of the head.
        for side in [Float(-1), 1] {
            let bulb = Toybox.node(SCNSphere(radius: 0.075), bodyMaterial, at: SIMD3(side * 0.095, 0.115, 0.04))
            squashNode.addChildNode(bulb)
            bulbs.append(bulb)
        }

        // Folded back legs at the sides, and flat front feet.
        for side in [Float(-1), 1] {
            let pivot = SCNNode()
            pivot.simdPosition = SIMD3(side * 0.19, -0.07, -0.01)
            pivot.addChildNode(Toybox.node(SCNSphere(radius: 0.085), bodyMaterial, scale: SIMD3(0.8, 1.0, 1.1)))
            pivot.addChildNode(Toybox.node(SCNSphere(radius: 0.05), accentMaterial, at: SIMD3(side * 0.03, -0.075, 0.07),
                                           scale: SIMD3(1.4, 0.45, 1.5)))
            squashNode.addChildNode(pivot)
            legs.append(pivot)
            squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.04), accentMaterial,
                                                at: SIMD3(side * 0.09, -0.15, 0.13), scale: SIMD3(1.3, 0.5, 1.5)))
        }

        // Nostrils.
        for side in [Float(-1), 1] {
            squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.008), dark, at: SIMD3(side * 0.025, 0.06, 0.168)))
        }

        addFace(eyes: [EyeSpot(position: SIMD3(-0.095, 0.135, 0.105), yaw: -0.2, browSign: -1),
                       EyeSpot(position: SIMD3(0.095, 0.135, 0.105), yaw: 0.2, browSign: 1)],
                eyeRadius: 0.052, mouth: SIMD3(0, -0.015, 0.168), mouthRadius: 0.026,
                cheeks: [SIMD3(-0.14, -0.02, 0.12), SIMD3(0.14, -0.02, 0.12)])
    }

    override var followStiffness: Float { 80 }
    override var followDamping: Float { 16 }
    override var bob: Float { sin(clock * 2.2) * 0.02 }

    override func flare(_ amount: Float) {
        legLag.velocity += 3 * amount
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        // The throat puffs with the beat (and faster while it paints).
        let breath = sin(clock * (painting ? 9 : 2.6)) * (painting ? 0.05 : 0.03)
        belly.simdScale = SIMD3(1 + beatPulse * 0.12 + breath, 1 + beatPulse * 0.18 + breath, 1 + beatPulse * 0.1)
        // The back legs swing out behind the body when it moves sideways.
        legLag.step(to: -position.velocity.x * 0.05, stiffness: 90, damping: 7, dt: dt)
        for (k, leg) in legs.enumerated() {
            let side: Float = k == 0 ? -1 : 1
            leg.simdEulerAngles = SIMD3(0, 0, side * (0.1 + abs(legLag.value) * 0.8) * (painting ? 1.4 : 1))
        }
        // The eyes sink and rise a little, like blinking bulbs.
        for (k, bulb) in bulbs.enumerated() {
            bulb.simdScale = SIMD3(repeating: 1 + sin(clock * 1.7 + Float(k) * 1.3) * 0.02 + beatPulse * 0.03)
        }
    }
}

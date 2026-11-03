import SceneKit
import simd

/// Liquid oil: a dreamy butterfly with big wings that flap lazily and flap fast while it paints. The glaze
/// itself comes from the liquid-oil tool (`PaintTool.dabs`), which spreads and runs downhill.
final class Butterfly: Critter {
    private var hinges: [SCNNode] = []
    private var antennae: [SCNNode] = []
    private var rateSpring = Spring1(5)
    private var phase: Float = 0
    /// Radians per second of the wing flap (about 5 resting, 15 while painting).
    var flapRate: Float { rateSpring.value }
    /// 0 = wings folded edge-on … 1 = wings spread flat toward the viewer.
    private(set) var wingOpen: Float = 1

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        super.init(kind: .butterfly, color: color, at: start, accentLift: 0.35)
        let dark = Toybox.balloon(SIMD3(0.36, 0.24, 0.22), wobble: 0, roughness: 0.5)
        let cream = Toybox.balloon(SIMD3(1.0, 0.93, 0.8), wobble: 0.003)
        let dot = Toybox.balloon(SIMD3(1, 1, 1), wobble: 0, roughness: 0.4)

        // Little striped body below a round cream head.
        squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.06), dark, at: SIMD3(0, -0.13, -0.02),
                                            scale: SIMD3(0.8, 1.6, 0.8)))
        let head = SCNNode()
        head.simdPosition = SIMD3(0, 0.03, 0)
        head.addChildNode(Toybox.node(SCNSphere(radius: 0.115), cream))
        squashNode.addChildNode(head)

        // Wings: a big upper and a smaller lower one on each side, hinged at the shoulders.
        for side in [Float(-1), 1] {
            let hinge = SCNNode()
            hinge.simdPosition = SIMD3(side * 0.06, 0.0, -0.05)
            hinge.addChildNode(Toybox.node(SCNSphere(radius: 0.17), bodyMaterial, at: SIMD3(side * 0.15, 0.09, 0),
                                           scale: SIMD3(1.0, 1.15, 0.12)))
            hinge.addChildNode(Toybox.node(SCNSphere(radius: 0.11), accentMaterial, at: SIMD3(side * 0.12, -0.1, 0.004),
                                           scale: SIMD3(0.9, 1.0, 0.12)))
            for (x, y, r) in [(0.19, 0.12, 0.03), (0.12, 0.2, 0.022), (0.13, -0.11, 0.024)] as [(Float, Float, Float)] {
                hinge.addChildNode(Toybox.node(SCNSphere(radius: CGFloat(r)), dot, at: SIMD3(side * x, y, 0.014),
                                               scale: SIMD3(1, 1, 0.4)))
            }
            squashNode.addChildNode(hinge)
            hinges.append(hinge)
        }
        // Curly antennae.
        for side in [Float(-1), 1] {
            let pivot = SCNNode()
            pivot.simdPosition = SIMD3(side * 0.045, 0.13, 0.02)
            pivot.addChildNode(Toybox.node(SCNCapsule(capRadius: 0.006, height: 0.1), dark, at: SIMD3(0, 0.05, 0)))
            pivot.addChildNode(Toybox.node(SCNSphere(radius: 0.017), dark, at: SIMD3(0, 0.105, 0)))
            pivot.simdEulerAngles = SIMD3(0, 0, -side * 0.4)
            squashNode.addChildNode(pivot)
            antennae.append(pivot)
        }
        addFace(eyes: [EyeSpot(position: SIMD3(-0.048, 0.04, 0.098), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.048, 0.04, 0.098), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.05, mouth: SIMD3(0, -0.025, 0.11), mouthRadius: 0.018,
                cheeks: [SIMD3(-0.085, -0.005, 0.08), SIMD3(0.085, -0.005, 0.08)], parent: head)
    }

    override var bob: Float { sin(clock * 2.4) * 0.05 }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        rateSpring.step(to: painting ? 15 : 5, stiffness: 60, damping: 10, dt: dt)
        phase += rateSpring.value * dt
        // The beat gives each flap a little extra pop.
        wingOpen = min(max(0.5 + 0.5 * sin(phase) + beatPulse * 0.1, 0), 1)
        for (k, hinge) in hinges.enumerated() {
            let side: Float = k == 0 ? -1 : 1
            // Seen from the front a flap is the wing narrowing toward its shoulder and widening again.
            hinge.simdScale = SIMD3(0.15 + 0.85 * wingOpen, 1, 1)
            hinge.simdEulerAngles = SIMD3(0, 0, side * 0.2 * (1 - wingOpen))
        }
        for (k, antenna) in antennae.enumerated() {
            let side: Float = k == 0 ? -1 : 1
            antenna.simdEulerAngles = SIMD3(sin(clock * 3 + Float(k)) * 0.2, 0,
                                            -side * 0.4 + sin(clock * 2.1 + Float(k) * 2) * 0.25)
        }
    }
}

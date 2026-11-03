import SceneKit
import simd

/// Blender: a fuzzy, stinger-less bee. It lays no paint of its own; it buzzes over the wet paint and smudges
/// the colors into each other, wiggling its bottom while it works. The wings never stop buzzing.
final class Bee: Critter {
    private let body = SCNNode()
    private let bottom = SCNNode()
    private var wings: [SCNNode] = []
    private var wiggleSpring = Spring1(0)
    /// 0 = resting … 1 = hard at work (how much the bottom wiggles).
    private(set) var wiggle: Float = 0

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        super.init(kind: .bee, color: color, at: start, accentLift: 0.3)
        // A bee stays honey-yellow whatever paint color was picked.
        let honey = Toybox.balloon(SIMD3(1.0, 0.82, 0.25), wobble: 0.004, speed: 6)
        let stripe = Toybox.balloon(SIMD3(0.22, 0.14, 0.1), wobble: 0, roughness: 0.5)
        let glass = SCNMaterial()
        glass.lightingModel = .physicallyBased
        glass.diffuse.contents = PlatformColor(red: 0.92, green: 0.97, blue: 1, alpha: 1)
        glass.roughness.contents = NSNumber(value: 0.2)
        glass.transparency = 0.55

        squashNode.addChildNode(body)
        body.addChildNode(Toybox.node(SCNSphere(radius: 0.14), honey, scale: SIMD3(1.05, 0.95, 1)))
        // The round back end with two stripes, wiggling on its own pivot.
        bottom.simdPosition = SIMD3(0, -0.06, -0.1)
        body.addChildNode(bottom)
        bottom.addChildNode(Toybox.node(SCNSphere(radius: 0.1), honey, scale: SIMD3(1, 0.95, 1.1)))
        for z in [Float(-0.03), 0.04] {
            bottom.addChildNode(Toybox.node(SCNTorus(ringRadius: 0.096, pipeRadius: 0.014), stripe, at: SIMD3(0, 0, z),
                                            scale: SIMD3(1, 1, 1)))
            bottom.childNodes.last?.simdEulerAngles = SIMD3(Float.pi / 2, 0, 0)
        }
        // Little antennae.
        for side in [Float(-1), 1] {
            let pivot = SCNNode()
            pivot.simdPosition = SIMD3(side * 0.05, 0.13, 0.06)
            pivot.addChildNode(Toybox.node(SCNCapsule(capRadius: 0.006, height: 0.09), stripe, at: SIMD3(0, 0.045, 0)))
            pivot.addChildNode(Toybox.node(SCNSphere(radius: 0.015), stripe, at: SIMD3(0, 0.095, 0)))
            pivot.simdEulerAngles = SIMD3(0, 0, -side * 0.4)
            body.addChildNode(pivot)
        }
        // Buzzing wings, hinged at the back of the shoulders.
        for side in [Float(-1), 1] {
            let hinge = SCNNode()
            hinge.simdPosition = SIMD3(side * 0.06, 0.12, -0.05)
            hinge.addChildNode(Toybox.node(SCNSphere(radius: 0.075), glass, at: SIMD3(side * 0.06, 0.03, 0),
                                           scale: SIMD3(1, 0.5, 0.25)))
            body.addChildNode(hinge)
            wings.append(hinge)
        }
        addFace(eyes: [EyeSpot(position: SIMD3(-0.058, 0.025, 0.118), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.058, 0.025, 0.118), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.058, mouth: SIMD3(0, -0.055, 0.128), mouthRadius: 0.02,
                cheeks: [SIMD3(-0.1, -0.035, 0.1), SIMD3(0.1, -0.035, 0.1)], parent: body)
    }

    override var blowsInk: Bool { false }
    override var bob: Float { sin(clock * 3.1) * 0.035 }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        wiggleSpring.step(to: painting ? 1 : 0, stiffness: 140, damping: 12, dt: dt)
        wiggle = wiggleSpring.value
        bottom.simdEulerAngles = SIMD3(0, 0, sin(clock * 15) * 0.32 * wiggle + sin(clock * 2) * 0.05)
        for (k, hinge) in wings.enumerated() {
            let side: Float = k == 0 ? -1 : 1
            hinge.simdEulerAngles = SIMD3(0, 0, -side * (0.35 + 0.3 * sin(clock * 70 + Float(k))))
        }
    }
}

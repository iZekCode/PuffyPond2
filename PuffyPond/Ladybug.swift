import SceneKit
import simd

/// Liquid oil: a round, rosy ladybug. Its little wing covers pop open and shut with the beat and flutter while it
/// paints; the glaze itself comes from the liquid-oil tool (`PaintTool.dabs`), which spreads and runs downhill.
final class Ladybug: Critter {
    private var wings: [SCNNode] = []
    private var antennae: [SCNNode] = []
    private var legs: [SCNNode] = []
    private var wingSpring = Spring1(0)
    /// 0 = covers closed … 1 = fully open (a touch more while it flutters).
    private(set) var wingOpen: Float = 0

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        let spots = SCNMaterial()
        spots.lightingModel = .physicallyBased
        spots.diffuse.contents = PlatformColor(red: 0.16, green: 0.1, blue: 0.12, alpha: 1)
        spots.roughness.contents = NSNumber(value: 0.45)

        let wingParent = SCNNode()
        super.init(kind: .ladybug, color: color, at: start, accentLift: 0.3)

        // Round body that is all face, with dark spots on top.
        squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.15), bodyMaterial, at: SIMD3(0, 0, 0),
                                            scale: SIMD3(1.08, 0.98, 1)))
        for (x, y, z, r) in [(-0.092, 0.11, 0.065, 0.026), (0.092, 0.11, 0.065, 0.026), (0.0, 0.147, 0.03, 0.02)] as [(Float, Float, Float, Float)] {
            squashNode.addChildNode(Toybox.node(SCNSphere(radius: CGFloat(r)), spots, at: SIMD3(x, y, z),
                                                scale: SIMD3(1, 1, 0.5)))
        }

        // Wing covers: two rounded plates that hinge open from the top, left and right.
        squashNode.addChildNode(wingParent)
        for side in [Float(-1), 1] {
            let hinge = SCNNode()
            hinge.simdPosition = SIMD3(side * 0.05, 0.13, -0.05)
            let plate = Toybox.node(SCNSphere(radius: 0.085), accentMaterial, at: SIMD3(side * 0.05, 0.0, 0),
                                    scale: SIMD3(0.8, 0.45, 1))
            hinge.addChildNode(plate)
            wingParent.addChildNode(hinge)
            wings.append(hinge)
        }
        // Antennae with a ball on the end.
        for side in [Float(-1), 1] {
            let pivot = SCNNode()
            pivot.simdPosition = SIMD3(side * 0.05, 0.14, 0.09)
            pivot.addChildNode(Toybox.node(SCNCapsule(capRadius: 0.006, height: 0.1), spots, at: SIMD3(0, 0.05, 0)))
            pivot.addChildNode(Toybox.node(SCNSphere(radius: 0.015), spots, at: SIMD3(0, 0.105, 0)))
            pivot.simdEulerAngles = SIMD3(0, 0, -side * 0.35)
            squashNode.addChildNode(pivot)
            antennae.append(pivot)
        }
        // Six tiny feet along the bottom.
        for side in [Float(-1), 1] {
            for z in [Float(-0.07), 0, 0.07] {
                let foot = Toybox.node(SCNCapsule(capRadius: 0.014, height: 0.06), spots,
                                       at: SIMD3(side * 0.1, -0.14, z))
                foot.simdEulerAngles = SIMD3(0, 0, side * 0.5)
                squashNode.addChildNode(foot)
                legs.append(foot)
            }
        }
        addFace(eyes: [EyeSpot(position: SIMD3(-0.062, 0.02, 0.128), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.062, 0.02, 0.128), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.06, mouth: SIMD3(0, -0.06, 0.138), mouthRadius: 0.02,
                cheeks: [SIMD3(-0.105, -0.04, 0.105), SIMD3(0.105, -0.04, 0.105)])
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        // Open on every beat; while painting the covers also flutter.
        let flutter = painting ? 0.35 + 0.3 * sin(clock * 22) : 0
        wingSpring.step(to: max(beatPulse, flutter), stiffness: 160, damping: 18, dt: dt)
        wingOpen = min(max(wingSpring.value, 0), 1.2)
        for (k, hinge) in wings.enumerated() {
            let side: Float = k == 0 ? -1 : 1
            hinge.simdEulerAngles = SIMD3(0, 0, -side * wingOpen * 0.8)
        }
        for (k, antenna) in antennae.enumerated() {
            let side: Float = k == 0 ? -1 : 1
            antenna.simdEulerAngles = SIMD3(sin(clock * 3 + Float(k)) * 0.15, 0, -side * 0.35 + sin(clock * 2.3 + Float(k) * 2) * 0.2)
        }
        for (k, foot) in legs.enumerated() {
            let side: Float = k < 3 ? -1 : 1
            foot.simdEulerAngles = SIMD3(0, 0, side * (0.5 + 0.25 * sin(clock * (painting ? 16 : 6) + Float(k) * 1.3)))
        }
    }
}

import SceneKit
import simd

/// Brush: a round, rosy ladybug with six little legs. While painting the legs lie flat on the canvas and are the
/// brush, exactly like the octopus's tentacles (see `LimbBrush`). Its wing covers pop open and shut with the beat.
final class Ladybug: Critter {
    private let legs: TentacleBundle
    private let limbs: LimbBrush
    private var wings: [SCNNode] = []
    private var antennae: [SCNNode] = []
    private var wingSpring = Spring1(0)
    /// 0 = covers closed … 1 = fully open (a touch more while it flutters).
    private(set) var wingOpen: Float = 0

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        let spots = SCNMaterial()
        spots.lightingModel = .physicallyBased
        spots.diffuse.contents = PlatformColor(red: 0.16, green: 0.1, blue: 0.12, alpha: 1)
        spots.roughness.contents = NSNumber(value: 0.45)

        let count = 6
        let roots = (0..<count).map { k -> (local: SIMD3<Float>, outward: SIMD3<Float>) in
            let a = (Float(k) + 0.5) / Float(count) * 2 * .pi
            return (SIMD3(cos(a) * 0.095, -0.05, sin(a) * 0.08), SIMD3(cos(a), 0, sin(a) * 0.6))
        }
        // Short, stubby, fairly stiff legs.
        var shape = TentacleBundle.Shape()
        shape.segments = 7
        shape.segmentLength = 0.04
        shape.rootRadius = 0.016
        shape.tipRadius = 0.006
        shape.startAngle = 0.8
        shape.curl = 0.7
        shape.sway = 0.3
        shape.stiffness = 0.2
        shape.gravity = 1.0
        shape.ripple = 0.05
        legs = TentacleBundle(shape: shape, roots: roots, start: start)
        limbs = LimbBrush(bundle: legs, limbZ: Octopus.limbZ)
        super.init(kind: .ladybug, color: color, at: start, accentLift: 0.3)
        legs.setSpokes((0..<count).map { k in
            let a = (Float(k) + 0.5) / Float(count) * 2 * .pi
            return SIMD2(cos(a), sin(a))
        })
        legs.material = spots
        root.addChildNode(legs.node)

        // Round body that is all face, with dark spots on top.
        squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.15), bodyMaterial, at: SIMD3(0, 0, 0),
                                            scale: SIMD3(1.08, 0.98, 1)))
        for (x, y, z, r) in [(-0.092, 0.11, 0.065, 0.026), (0.092, 0.11, 0.065, 0.026), (0.0, 0.147, 0.03, 0.02)] as [(Float, Float, Float, Float)] {
            squashNode.addChildNode(Toybox.node(SCNSphere(radius: CGFloat(r)), spots, at: SIMD3(x, y, z),
                                                scale: SIMD3(1, 1, 0.5)))
        }

        // Wing covers: two rounded plates that hinge open from the top, left and right.
        for side in [Float(-1), 1] {
            let hinge = SCNNode()
            hinge.simdPosition = SIMD3(side * 0.05, 0.13, -0.05)
            hinge.addChildNode(Toybox.node(SCNSphere(radius: 0.085), accentMaterial, at: SIMD3(side * 0.05, 0.0, 0),
                                           scale: SIMD3(0.8, 0.45, 1)))
            squashNode.addChildNode(hinge)
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

        addFace(eyes: [EyeSpot(position: SIMD3(-0.062, 0.02, 0.128), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.062, 0.02, 0.128), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.06, mouth: SIMD3(0, -0.06, 0.138), mouthRadius: 0.02,
                cheeks: [SIMD3(-0.105, -0.04, 0.105), SIMD3(0.105, -0.04, 0.105)])
    }

    override var usesSizeSlider: Bool { true }

    override func flare(_ amount: Float) {
        legs.flare(amount, body: leanNode.simdWorldTransform)
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
            antenna.simdEulerAngles = SIMD3(sin(clock * 3 + Float(k)) * 0.15, 0,
                                            -side * 0.35 + sin(clock * 2.3 + Float(k) * 2) * 0.2)
        }
        limbs.animate(dt: dt, velocity: SIMD2(position.velocity.x, position.velocity.y), head: bodyNode.simdPosition,
                      body: leanNode.simdWorldTransform, scale: scale, clock: clock, beatPulse: beatPulse,
                      pressing: painting && !hidden, hidden: hidden)
    }

    override func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        limbs.dabs(towards: b)
    }
}

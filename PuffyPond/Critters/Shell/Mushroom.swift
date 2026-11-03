import SceneKit
import simd

/// Eraser: a bouncy little toadstool. Its cap wobbles as it trots along, and while it wipes paint away it squashes
/// and puffs out clouds of spores.
final class Mushroom: Critter {
    /// How much paint it wipes away around itself (world units).
    static let eraseRadius: Float = 0.26

    private let cap = SCNNode()
    private var feet: [SCNNode] = []
    private let spores = SCNParticleSystem()
    private var puffSpring = Spring1(0)
    /// 0…1, how hard it is puffing right now (kicked by `scrubbed()`, then fades).
    var puff: Float { max(0, puffSpring.value) }

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        super.init(kind: .mushroom, color: color, at: start, accentLift: 0.3)
        // A toadstool keeps its own colors whatever paint color was picked.
        let capMaterial = Toybox.balloon(SIMD3(0.93, 0.3, 0.32), wobble: 0.004, speed: 5)
        let stemMaterial = Toybox.balloon(SIMD3(1.0, 0.94, 0.83), wobble: 0.003)

        squashNode.addChildNode(Toybox.node(SCNCapsule(capRadius: 0.085, height: 0.3), stemMaterial,
                                            at: SIMD3(0, -0.09, 0), scale: SIMD3(1, 1, 0.95)))
        cap.simdPosition = SIMD3(0, 0.1, 0)
        cap.addChildNode(Toybox.node(SCNSphere(radius: 0.19), capMaterial, scale: SIMD3(1.1, 0.72, 1.05)))
        for (x, y, z, r) in [(-0.1, 0.07, 0.146, 0.034), (0.1, 0.06, 0.155, 0.03), (0.0, 0.11, 0.122, 0.026),
                             (-0.17, 0.0, 0.07, 0.026), (0.17, 0.0, 0.07, 0.026)] as [(Float, Float, Float, Float)] {
            cap.addChildNode(Toybox.node(SCNSphere(radius: CGFloat(r)), stemMaterial, at: SIMD3(x, y, z),
                                         scale: SIMD3(1, 1, 0.4)))
        }
        squashNode.addChildNode(cap)
        // Two stubby feet that patter.
        for side in [Float(-1), 1] {
            let foot = Toybox.node(SCNSphere(radius: 0.045), stemMaterial, at: SIMD3(side * 0.05, -0.25, 0.02),
                                   scale: SIMD3(1, 0.6, 1.2))
            squashNode.addChildNode(foot)
            feet.append(foot)
        }
        addFace(eyes: [EyeSpot(position: SIMD3(-0.05, -0.085, 0.085), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.05, -0.085, 0.085), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.047, mouth: SIMD3(0, -0.15, 0.09), mouthRadius: 0.02,
                cheeks: [SIMD3(-0.085, -0.13, 0.075), SIMD3(0.085, -0.13, 0.075)])

        // Spores drift up from the top of the cap.
        spores.birthRate = 0
        spores.particleLifeSpan = 0.9
        spores.particleLifeSpanVariation = 0.3
        spores.particleSize = 0.03
        spores.particleSizeVariation = 0.015
        spores.particleVelocity = 0.5
        spores.particleVelocityVariation = 0.3
        spores.emittingDirection = SCNVector3(0, 1, 0)
        spores.spreadingAngle = 80
        spores.acceleration = SCNVector3(0, 0.2, 0)
        spores.particleColor = PlatformColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
        let emitter = SCNNode()
        emitter.simdPosition = SIMD3(0, 0.2, 0.02)
        emitter.addParticleSystem(spores)
        squashNode.addChildNode(emitter)
    }

    override var eraseRadius: Float { Self.eraseRadius }
    override var facesMotion: Bool { true }
    override var bob: Float { sin(clock * 3) * 0.03 }

    override func scrubbed() {
        puffSpring.value = 1
        puffSpring.velocity = 0
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        puffSpring.step(to: 0, stiffness: 50, damping: 11, dt: dt)
        cap.simdScale = SIMD3(1 + 0.12 * puff, 1 - 0.15 * puff, 1 + 0.12 * puff)
        cap.simdEulerAngles = SIMD3(0, 0, sin(clock * (painting ? 12 : 2.2)) * (painting ? 0.1 : 0.05))
        for (k, foot) in feet.enumerated() {
            let step = sin(clock * (painting ? 14 : 5) + Float(k) * Float.pi)
            foot.simdPosition = SIMD3((k == 0 ? -0.05 : 0.05), -0.25 + max(step, 0) * 0.025, 0.02)
        }
        spores.birthRate = puff > 0.35 ? 40 : 0
    }
}

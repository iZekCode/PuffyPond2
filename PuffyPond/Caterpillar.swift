import SceneKit
import simd

/// Eraser: a hungry caterpillar. A big round head with a chewing mouth leads a chain of round segments that
/// wriggle along behind it; while it eats paint the mouth munches and a few crumbs fly.
final class Caterpillar: Critter {
    /// How much paint it eats around its head (world units).
    static let eraseRadius: Float = 0.26
    private static let segmentCount = 5
    /// Distance between neighbouring segment centres at scale 1.
    private static let spacing: Float = 0.15

    private let head = SCNNode()
    private var segments: [SCNNode] = []
    /// World positions of the segments, nearest the head first.
    private var chain: [SIMD3<Float>]
    private var chompSpring = Spring1(0)
    private let crumbs = SCNParticleSystem()
    /// 0…1, how hard it is munching right now (kicked by `scrubbed()`, then fades).
    var chomp: Float { max(0, chompSpring.value) }

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        chain = (0..<Self.segmentCount).map { start - SIMD3(0, Float($0 + 1) * Self.spacing, 0) }
        super.init(kind: .caterpillar, color: color, at: start, accentLift: 0.3)

        squashNode.addChildNode(head)
        head.addChildNode(Toybox.node(SCNSphere(radius: 0.14), bodyMaterial, scale: SIMD3(1.05, 1.0, 1.0)))
        // Two little antennae with round tips.
        let tip = Toybox.balloon(SIMD3(0.95, 0.45, 0.45), wobble: 0.003)
        for side in [Float(-1), 1] {
            let pivot = SCNNode()
            pivot.simdPosition = SIMD3(side * 0.06, 0.125, 0.02)
            pivot.addChildNode(Toybox.node(SCNCapsule(capRadius: 0.008, height: 0.1), accentMaterial, at: SIMD3(0, 0.05, 0)))
            pivot.addChildNode(Toybox.node(SCNSphere(radius: 0.022), tip, at: SIMD3(0, 0.105, 0)))
            pivot.simdEulerAngles = SIMD3(0, 0, -side * 0.4)
            head.addChildNode(pivot)
        }
        addFace(eyes: [EyeSpot(position: SIMD3(-0.06, 0.035, 0.125), yaw: -0.22, browSign: -1),
                       EyeSpot(position: SIMD3(0.06, 0.035, 0.125), yaw: 0.22, browSign: 1)],
                eyeRadius: 0.062, mouth: SIMD3(0, -0.055, 0.135), mouthRadius: 0.026,
                cheeks: [SIMD3(-0.105, -0.025, 0.105), SIMD3(0.105, -0.025, 0.105)], parent: head)

        // Crumbs fly off the mouth while it munches.
        crumbs.birthRate = 0
        crumbs.particleLifeSpan = 0.5
        crumbs.particleLifeSpanVariation = 0.2
        crumbs.particleSize = 0.02
        crumbs.particleVelocity = 0.8
        crumbs.particleVelocityVariation = 0.5
        crumbs.spreadingAngle = 60
        crumbs.acceleration = SCNVector3(0, -1.6, 0)
        crumbs.emitterShape = SCNSphere(radius: 0.02)
        let mouthEmitter = SCNNode()
        mouthEmitter.simdPosition = SIMD3(0, -0.06, 0.15)
        mouthEmitter.addParticleSystem(crumbs)
        head.addChildNode(mouthEmitter)

        // The body: round segments in world space, alternating shades, getting smaller toward the tail.
        for k in 0..<Self.segmentCount {
            let node = Toybox.node(SCNSphere(radius: 0.11), k % 2 == 0 ? accentMaterial : bodyMaterial)
            node.simdPosition = chain[k]
            root.addChildNode(node)
            segments.append(node)
        }
    }

    override var eraseRadius: Float { Self.eraseRadius }
    override var bob: Float { sin(clock * 2.6) * 0.025 }

    override func scrubbed() {
        chompSpring.value = 1
        chompSpring.velocity = 0
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        chompSpring.step(to: 0, stiffness: 60, damping: 12, dt: dt)
        head.simdScale = SIMD3(repeating: 1 + 0.07 * chomp)
        head.simdEulerAngles = SIMD3(0, 0, sin(clock * (painting ? 9 : 2.5)) * 0.06)

        // Follow the head: each segment stays one step from the one in front, with a little wriggle and droop.
        let headPosition = bodyNode.simdPosition
        let step = Self.spacing * scale
        if simd_distance(headPosition, chain[0]) > 0.8 {   // a teleport: gather the body behind the head
            for k in chain.indices { chain[k] = headPosition - SIMD3(0, Float(k + 1) * step, 0) }
        }
        var previous = headPosition
        for k in chain.indices {
            var p = chain[k]
            p.y -= 0.35 * dt
            p.x += sin(clock * 5 - Float(k) * 0.9) * 0.12 * dt * (painting ? 2 : 1)
            let away = p - previous
            let length = simd_length(away)
            let direction = length > 1e-5 ? away / length : SIMD3<Float>(0, -1, 0)
            chain[k] = previous + direction * step
            previous = chain[k]
            let size = scale * (1 - 0.1 * Float(k)) * (1 + 0.05 * sin(clock * 6 - Float(k)))
            segments[k].simdPosition = chain[k]
            segments[k].simdScale = SIMD3(repeating: max(size, 0.001))
            segments[k].isHidden = hidden
        }

        crumbs.birthRate = chomp > 0.4 ? 40 : 0
        crumbs.particleColor = Paint.platform(displayedColor)
    }
}

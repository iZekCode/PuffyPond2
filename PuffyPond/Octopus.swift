import SceneKit
import simd

/// Bundle brush: a glossy head with a face and eight jiggly tentacles. The mouth blows the main
/// stroke, and while painting the tentacles lie on the canvas: every stretch that touches it paints too.
final class Octopus: Critter {
    private let tentacles: TentacleBundle
    /// Height of a limb's centre when it lies on the canvas (just above the canvas face).
    static let limbZ: Float = Playground.canvasZ + 0.02
    private var lastHead: SIMD3<Float>
    /// The head's planar velocity (smoothed), so the tentacles don't flip direction on every jittery frame.
    private var smoothVelocity = SIMD2<Float>.zero
    /// How long the octopus has been holding still while painting (seconds).
    private var holdTime: Float = 0
    private var frameDT: Float = 1.0 / 60.0
    /// Wiping faster than this (world units/s) gathers every tentacle into one trailing bundle.
    private static let trailSpeed: ClosedRange<Float> = 0.35...1.4
    /// Holding still for this long (seconds) starts the paint oozing out; it keeps growing for `oozeGrowth` seconds.
    private static let oozeDelay: Float = 0.15
    private static let oozeGrowth: Float = 4
    /// How fast the oozing paint flows outward (world units/s; slow enough that the texture grows fully).
    private static let oozeSpeed: Float = 0.28

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        lastHead = start
        let count = 8
        let roots = (0..<count).map { k -> (local: SIMD3<Float>, outward: SIMD3<Float>) in
            let a = (Float(k) + 0.5) / Float(count) * 2 * .pi
            // Spread wider sideways than front-to-back so you see every tentacle from the front.
            return (SIMD3(cos(a) * 0.09, -0.07, sin(a) * 0.075), SIMD3(cos(a), 0, sin(a) * 0.6))
        }
        tentacles = TentacleBundle(shape: .init(), roots: roots, start: start)
        super.init(kind: .octopus, color: color, at: start)
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
        // A teleport (e.g. starfish → octopus) would fling the tentacles: snap them home instead.
        let head = bodyNode.simdPosition
        let teleported = simd_distance(head, lastHead) > 0.8
        lastHead = head
        let pressing = painting && !hidden
        frameDT = dt
        let v = SIMD2(position.velocity.x, position.velocity.y)
        smoothVelocity += (v - smoothVelocity) * min(1, dt * 8)
        let planarSpeed = simd_length(smoothVelocity)
        // Wiping: every tentacle streams out behind the head, side by side, the way a broom drags.
        let trail = pressing ? smoothStep(Self.trailSpeed.lowerBound, Self.trailSpeed.upperBound, planarSpeed) : 0
        let streamDirection = planarSpeed > 1e-4 ? -smoothVelocity / planarSpeed : .zero
        if !pressing || planarSpeed > Self.trailSpeed.lowerBound {
            holdTime = 0
        } else if planarSpeed < 0.2 {
            holdTime += dt
        }
        tentacles.simulate(dt: dt, body: leanNode.simdWorldTransform, scale: scale, clock: clock,
                           beatPulse: beatPulse, snap: teleported, press: pressing ? 1 : 0, minZ: Self.limbZ,
                           trail: trail, trailDirection: streamDirection)
        tentacles.collectTips(dt: dt, painting: pressing)
        tentacles.collectContacts(dt: dt, painting: pressing, scale: scale, contactZ: Self.limbZ + 0.03)
        tentacles.rebuild(scale: scale, clock: clock, hidden: hidden)
    }

    override func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        // Holding still, the octopus keeps pushing paint out: it pools under the head and every tentacle,
        // and flows outward from it, so the puddle spreads (and its texture keeps regrowing) the longer you hold.
        let ooze = smoothStep(Self.oozeDelay, Self.oozeDelay + 0.35, holdTime)
        let swell = min(max(holdTime - Self.oozeDelay, 0), Self.oozeGrowth)
        var style = BrushStyle.octopus
        if ooze > 0 { style.amount = 0.05 + 0.1 * ooze }
        var result = [BrushDab(from: a, to: b, radius: radius * sizeScale * (1 + 0.3 * swell), speed: speed, style: style)]
        for c in tentacles.contacts {
            guard ooze > 0 else {
                result.append(BrushDab(from: c.a, to: c.b, radius: c.radius, speed: c.speed, style: .octopus, drag: c.drag))
                continue
            }
            let away = (c.a + c.b) * 0.5 - b
            let outward = simd_length(away) > 1e-4 ? simd_normalize(away) : SIMD2<Float>(0, 1)
            result.append(BrushDab(from: c.a, to: c.b, radius: c.radius * (1 + 0.45 * swell), speed: Self.oozeSpeed,
                                   style: style, drag: outward * Self.oozeSpeed * frameDT * ooze))
        }
        return result
    }
}

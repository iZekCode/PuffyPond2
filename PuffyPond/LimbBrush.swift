import SceneKit
import simd

/// The brush behaviour of a critter whose limbs lie flat on the canvas and paint (the octopus, the ladybug):
/// wiping gathers the limbs into one trailing bundle, holding still makes every limb ooze paint outward.
final class LimbBrush {
    let bundle: TentacleBundle
    /// Height of a limb's centre when it lies on the canvas (just above the canvas face).
    let limbZ: Float
    private var lastHead: SIMD3<Float>?
    /// The head's planar velocity (smoothed), so the limbs don't flip direction on every jittery frame.
    private var smoothVelocity = SIMD2<Float>.zero
    /// How long the critter has been holding still while painting (seconds).
    private var holdTime: Float = 0
    private var frameDT: Float = 1.0 / 60.0
    /// 0…1, how flat the limbs lie fanned out on the canvas (eases in and out).
    private var spread: Float = 0
    /// Wiping faster than this (world units/s) gathers every limb into one trailing bundle.
    private static let trailSpeed: ClosedRange<Float> = 0.35...1.4
    /// Holding still for this long (seconds) starts the paint oozing out; it keeps growing for `oozeGrowth` seconds.
    private static let oozeDelay: Float = 0.15
    private static let oozeGrowth: Float = 4
    /// How fast the oozing paint flows outward (world units/s; slow enough that the texture grows fully).
    private static let oozeSpeed: Float = 0.28

    /// How long it has been held still while pressing, as 0…1 (nil while it moves or isn't pressing).
    var holdProgress: Float? {
        holdTime > Self.oozeDelay ? min((holdTime - Self.oozeDelay) / Self.oozeGrowth, 1) : nil
    }

    init(bundle: TentacleBundle, limbZ: Float) {
        self.bundle = bundle
        self.limbZ = limbZ
    }

    func animate(dt: Float, velocity: SIMD2<Float>, head: SIMD3<Float>, body: simd_float4x4, scale: Float,
                 clock: Float, beatPulse: Float, pressing: Bool, hidden: Bool) {
        // A teleport (e.g. swapping animals in a bubble) would fling the limbs: snap them home instead.
        let teleported = lastHead.map { simd_distance(head, $0) > 0.8 } ?? false
        lastHead = head
        frameDT = dt
        smoothVelocity += (velocity - smoothVelocity) * min(1, dt * 8)
        let planarSpeed = simd_length(smoothVelocity)
        // Wiping: every limb streams out behind the head, side by side, the way a broom drags.
        let trail = pressing ? smoothStep(Self.trailSpeed.lowerBound, Self.trailSpeed.upperBound, planarSpeed) : 0
        let streamDirection = planarSpeed > 1e-4 ? -smoothVelocity / planarSpeed : .zero
        if !pressing || planarSpeed > Self.trailSpeed.lowerBound {
            holdTime = 0
        } else if planarSpeed < 0.2 {
            holdTime += dt
        }
        // Pressing, the limbs settle flat onto the canvas as a star until a wipe gathers them into a trailing bundle.
        spread += ((pressing ? 1 - trail : 0) - spread) * min(1, dt * 10)
        bundle.simulate(dt: dt, body: body, scale: scale, clock: clock,
                        beatPulse: beatPulse, snap: teleported, press: pressing ? 1 : 0, minZ: limbZ,
                        trail: trail, trailDirection: streamDirection, spread: spread)
        bundle.collectTips(dt: dt, painting: pressing)
        bundle.collectContacts(dt: dt, painting: pressing, scale: scale, contactZ: limbZ + 0.03)
        bundle.rebuild(scale: scale, clock: clock, hidden: hidden)
    }

    /// The head never paints: the limbs lying on the canvas are the brush, like wiping with eight fingers.
    /// Holding still, every limb keeps pushing paint out along its whole length, and it flows outward
    /// from the head, so the puddle spreads (and its texture keeps regrowing) the longer you hold.
    func dabs(towards head: SIMD2<Float>) -> [BrushDab] {
        let ooze = smoothStep(Self.oozeDelay, Self.oozeDelay + 0.35, holdTime)
        let swell = min(max(holdTime - Self.oozeDelay, 0), Self.oozeGrowth)
        var style = BrushStyle.octopus
        if ooze > 0 { style.amount = 0.05 + 0.1 * ooze }
        var result: [BrushDab] = []
        for c in bundle.contacts {
            guard ooze > 0 else {
                result.append(BrushDab(from: c.a, to: c.b, radius: c.radius, speed: c.speed, style: .octopus, drag: c.drag))
                continue
            }
            let away = (c.a + c.b) * 0.5 - head
            let outward = simd_length(away) > 1e-4 ? simd_normalize(away) : SIMD2<Float>(0, 1)
            result.append(BrushDab(from: c.a, to: c.b, radius: c.radius * (1 + 0.45 * swell), speed: Self.oozeSpeed,
                                   style: style, drag: outward * Self.oozeSpeed * frameDT * ooze))
        }
        return result
    }
}

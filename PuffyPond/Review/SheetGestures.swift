import Foundation
import simd

/// One hand over the review sheet, in sheet space (see `SheetSolver`).
struct SheetHand {
    var slot: Int
    var pose: HandPose
    var position: SIMD2<Float>
    /// Sheet units per second.
    var velocity: SIMD2<Float>
    var tracking: Bool
}

/// One fist holding the sheet. The node under the hand follows it fully; the rest follow less the
/// farther away they sit on the sheet, so the pull fades out like on a wet canvas.
private struct SheetGrab {
    var slot: Int
    var grabNode: Int
    /// Hand point when the grab began (or was re-baselined).
    var anchorStart: SIMD2<Float>
    /// Where the grabbed point is now; lags the hand, so the sheet feels heavy.
    var anchor: SIMD2<Float>
    var nodes: [Int]
    var weights: [Float]
    /// Node positions when the grab (or its latest re-baseline) began.
    var start: [SIMD2<Float>]

    /// Falloff on the sheet: a quarter of its width.
    static let sigma: Float = SheetSolver.size.x * 0.25
    /// How far off the sheet a fist can still catch it.
    static let reach: Float = 0.8
    /// Fraction of the gap to the target closed per substep.
    static let stiffness: Float = 0.3
    /// How quickly the grabbed point catches up with the hand (1/s).
    static let followRate: Float = 9

    /// Catches the sheet near `point`, or nil when the fist is off the sheet.
    static func make(slot: Int, at point: SIMD2<Float>, solver: SheetSolver) -> SheetGrab? {
        let grabNode = solver.nearestNode(to: point)
        guard simd_distance(solver.position(grabNode), point) <= reach else { return nil }
        let center = solver.rest[grabNode]
        var nodes: [Int] = []
        var weights: [Float] = []
        for i in 0..<solver.count {
            let s = simd_distance(solver.rest[i], center) / sigma
            let w = exp(-s * s)
            if w > 0.02 {
                nodes.append(i)
                weights.append(w)
            }
        }
        return SheetGrab(slot: slot, grabNode: grabNode, anchorStart: point, anchor: point,
                         nodes: nodes, weights: weights, start: nodes.map(solver.position))
    }

    mutating func follow(_ hand: SIMD2<Float>, dt: Float) {
        anchor += (hand - anchor) * (1 - exp(-dt * Self.followRate))
    }

    /// Restarts from the sheet's current shape, so switching between one and two hands never jumps.
    mutating func rebaseline(solver: SheetSolver) {
        anchorStart = anchor
        start = nodes.map(solver.position)
    }

    func apply(to solver: SheetSolver) {
        let delta = anchor - anchorStart
        for (k, node) in nodes.enumerated() {
            let w = weights[k]
            solver.pin(node, to: start[k] + delta * w, weight: w * Self.stiffness)
        }
    }
}

/// Two fists holding the sheet: the part between the hands follows the similarity transform that maps
/// the starting hand pair onto the current one, so moving the hands apart stretches, together squashes,
/// and turning the pair twists. Away from the segment between the hands the effect fades.
private struct SheetStretch {
    var a0: SIMD2<Float>
    var b0: SIMD2<Float>
    var start: [SIMD2<Float>]
    var weights: [Float]

    static let minScale: Float = 0.3
    static let maxScale: Float = 3.5
    static let falloff: Float = SheetGrab.sigma
    static let stiffness: Float = 0.7

    init(a: SheetGrab, b: SheetGrab, solver: SheetSolver) {
        a0 = a.anchor
        b0 = b.anchor
        start = (0..<solver.count).map(solver.position)
        // Projection onto the segment between the two grabbed points, measured on the rest sheet.
        let ra = solver.rest[a.grabNode]
        let rb = solver.rest[b.grabNode]
        let axis = rb - ra
        let length2 = max(simd_length_squared(axis), 1e-6)
        weights = solver.rest.map { p in
            let t = min(max(simd_dot(p - ra, axis) / length2, 0), 1)
            let gap = simd_distance(p, ra + axis * t) / Self.falloff
            return exp(-gap * gap)
        }
    }

    /// Scale and rotation of the current hand pair relative to the starting pair.
    func transform(a: SIMD2<Float>, b: SIMD2<Float>) -> (scale: Float, angle: Float) {
        let from = b0 - a0
        let to = b - a
        let fromLength = simd_length(from)
        guard fromLength > 0.01, simd_length(to) > 0.01 else { return (1, 0) }
        let scale = min(max(simd_length(to) / fromLength, Self.minScale), Self.maxScale)
        let angle = atan2(to.y, to.x) - atan2(from.y, from.x)
        return (scale, angle)
    }

    func apply(a: SIMD2<Float>, b: SIMD2<Float>, to solver: SheetSolver) {
        let (scale, angle) = transform(a: a, b: b)
        let c = cos(angle) * scale
        let s = sin(angle) * scale
        for (i, p) in start.enumerated() where weights[i] > 0.02 {
            let local = p - a0
            let mapped = a + SIMD2(c * local.x - s * local.y, s * local.x + c * local.y)
            let w = weights[i]
            solver.pin(i, to: p + (mapped - p) * w, weight: w * Self.stiffness)
        }
    }
}

/// Reads the hands over the review sheet and turns them into solver inputs, InterARTive style:
/// one fist grabs, two fists stretch and twist, a moving open palm pushes and makes ripples.
/// Letting go (or the camera losing the hand) is always a release, so the sheet can never get stuck.
final class SheetGestures {
    enum State: Equatable { case idle, grabbing, stretching, pushing, releasing }

    enum Event: Equatable {
        case grabbed(SIMD2<Float>)
        case released(SIMD2<Float>)
        /// Strength 0...1, from the palm's speed.
        case pushed(SIMD2<Float>, strength: Float)
    }

    /// An open palm pushes only when it moves at least this fast (sheet units / s).
    static let pushSpeed: Float = 1
    static let pushRadius: Float = 0.7
    static let repel: Float = 17
    static let drag: Float = 9
    /// Seconds between ripples from one pushing palm.
    static let rippleInterval: Float = 0.15

    private(set) var state: State = .idle
    private var grabs: [SheetGrab] = []
    private var stretch: SheetStretch?
    private var rippleCooldown: [Int: Float] = [:]

    /// Positions of the grabbed points (they lag the fists a little), for drawing.
    var anchors: [SIMD2<Float>] { grabs.map(\.anchor) }

    /// Clears last frame's inputs and adds this frame's. Call once per frame, before `solver.step`.
    func update(hands: [SheetHand], dt: Float, solver: SheetSolver) -> [Event] {
        var events: [Event] = []
        solver.clearInputs()
        let live = hands.filter(\.tracking)
        let fists = live.filter { $0.pose == .fist }

        // Release grabs whose fist opened or whose hand was lost.
        let before = grabs.count
        grabs.removeAll { grab in
            guard !fists.contains(where: { $0.slot == grab.slot }) else { return false }
            solver.release(heaviness: 1)
            events.append(.released(grab.anchor))
            return true
        }
        let released = grabs.count != before

        // New fists catch the sheet.
        var caught = false
        for fist in fists where !grabs.contains(where: { $0.slot == fist.slot }) {
            if let grab = SheetGrab.make(slot: fist.slot, at: fist.position, solver: solver) {
                grabs.append(grab)
                events.append(.grabbed(fist.position))
                caught = true
            }
        }

        for k in grabs.indices {
            if let fist = fists.first(where: { $0.slot == grabs[k].slot }) { grabs[k].follow(fist.position, dt: dt) }
        }

        if grabs.count >= 2 {
            if stretch == nil || caught || released {
                for k in grabs.indices { grabs[k].rebaseline(solver: solver) }
                stretch = SheetStretch(a: grabs[0], b: grabs[1], solver: solver)
            }
            stretch?.apply(a: grabs[0].anchor, b: grabs[1].anchor, to: solver)
            state = .stretching
        } else if !grabs.isEmpty {
            if stretch != nil || released {
                stretch = nil
                grabs[0].rebaseline(solver: solver)
            }
            grabs[0].apply(to: solver)
            state = .grabbing
        } else {
            stretch = nil
            let pushed = push(with: live, dt: dt, solver: solver, events: &events)
            state = pushed ? .pushing : (solver.isSleeping ? .idle : .releasing)
        }
        return events
    }

    /// Forgets every hand and lets the sheet spring back, e.g. when the page closes.
    func reset(solver: SheetSolver) {
        if !grabs.isEmpty { solver.release(heaviness: 1) }
        grabs.removeAll()
        stretch = nil
        rippleCooldown.removeAll()
        solver.clearInputs()
        state = solver.isSleeping ? .idle : .releasing
    }

    /// Open palms moving fast enough push the sheet away from their center and drag it along.
    private func push(with hands: [SheetHand], dt: Float, solver: SheetSolver, events: inout [Event]) -> Bool {
        var pushed = false
        for hand in hands where hand.pose != .fist {
            let speed = simd_length(hand.velocity)
            let cooldown = (rippleCooldown[hand.slot] ?? 0) - dt
            rippleCooldown[hand.slot] = max(cooldown, 0)
            guard speed > Self.pushSpeed else { continue }
            let radius = Self.pushRadius
            var touched = false
            for i in 0..<solver.count {
                let offset = solver.position(i) - hand.position
                let distance = simd_length(offset)
                guard distance < radius else { continue }
                touched = true
                let f = (1 - distance / radius) * (1 - distance / radius)
                let away = distance > 1e-4 ? offset / distance : SIMD2<Float>(0, 1)
                solver.push(i, acceleration: (away * Self.repel + hand.velocity * Self.drag) * f)
            }
            guard touched else { continue }
            pushed = true
            if cooldown <= 0 {
                rippleCooldown[hand.slot] = Self.rippleInterval
                events.append(.pushed(hand.position, strength: min(speed / 4, 1)))
            }
        }
        return pushed
    }
}

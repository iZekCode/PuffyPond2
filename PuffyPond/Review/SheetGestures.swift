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

/// One fist holding the sheet: a small patch of paint under the hand comes along and the rest stays put.
///
/// The patch moves in small steps. Every frame the hand's movement since the last frame is added to each
/// node's target, weighted by how close that node's target is to the hand. A step that small can't fold the
/// grid, however far the hand travels. Nodes that fall out of the patch stop being held and spring back
/// toward where they were drawn, so a long pull leaves a stretchy trail behind the hand.
private struct SheetGrab {
    var slot: Int
    var grabNode: Int
    /// Where the hand's grabbed point was last frame; lags the hand, so the paint feels heavy.
    var previous: SIMD2<Float>
    var anchor: SIMD2<Float>
    /// Where every node is being pulled to; follows the node's own position while it isn't in the patch.
    var targets: [SIMD2<Float>]

    /// Radius of the patch: a tenth of the sheet's width.
    static let sigma: Float = SheetSolver.size.x * 0.1
    /// Nodes weighted less than this are left alone.
    static let minWeight: Float = 0.02
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
        return SheetGrab(slot: slot, grabNode: grabNode, previous: point, anchor: point,
                         targets: (0..<solver.count).map(solver.position))
    }

    mutating func follow(_ hand: SIMD2<Float>, dt: Float) {
        anchor += (hand - anchor) * (1 - exp(-dt * Self.followRate))
    }

    mutating func apply(to solver: SheetSolver) {
        let step = anchor - previous
        previous = anchor
        for i in targets.indices {
            let s = simd_distance(targets[i], anchor - step) / Self.sigma
            let w = exp(-s * s)
            guard w > Self.minWeight else {
                targets[i] = solver.position(i)
                continue
            }
            targets[i] += step * w
            solver.pin(i, to: targets[i], weight: w * Self.stiffness)
        }
    }
}

/// Reads the hands over the review sheet and turns them into solver inputs, InterARTive style:
/// one fist grabs a small patch, two fists pull two patches apart, a moving open palm pushes and makes ripples.
/// Letting go (or the camera losing the hand) is always a release, so the sheet can never get stuck.
final class SheetGestures {
    enum State: Equatable { case idle, grabbing, stretching, pushing, releasing }

    enum Event: Equatable {
        case grabbed(SIMD2<Float>)
        case released(SIMD2<Float>)
        /// Strength 0...1, from the palm's speed.
        case pushed(SIMD2<Float>, strength: Float)
        /// The second fist caught the sheet; at the middle of the two.
        case stretchStarted(SIMD2<Float>)
        /// One of the two fists let go; at the middle of the two.
        case stretchEnded(SIMD2<Float>)
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
    private var rippleCooldown: [Int: Float] = [:]

    /// Clears last frame's inputs and adds this frame's. Call once per frame, before `solver.step`.
    func update(hands: [SheetHand], dt: Float, solver: SheetSolver) -> [Event] {
        var events: [Event] = []
        solver.clearInputs()
        let before = state
        let middle = grabs.count >= 2 ? (grabs[0].anchor + grabs[1].anchor) / 2 : .zero
        let live = hands.filter(\.tracking)
        let fists = live.filter { $0.pose == .fist }

        // Release grabs whose fist opened or whose hand was lost.
        grabs.removeAll { grab in
            guard !fists.contains(where: { $0.slot == grab.slot }) else { return false }
            solver.release(heaviness: 1)
            events.append(.released(grab.anchor))
            return true
        }

        // New fists catch the sheet.
        for fist in fists where !grabs.contains(where: { $0.slot == fist.slot }) {
            if let grab = SheetGrab.make(slot: fist.slot, at: fist.position, solver: solver) {
                grabs.append(grab)
                events.append(.grabbed(fist.position))
            }
        }

        for k in grabs.indices {
            if let fist = fists.first(where: { $0.slot == grabs[k].slot }) { grabs[k].follow(fist.position, dt: dt) }
        }

        // Each fist moves its own patch; with two, the paint between them stretches as they part.
        if !grabs.isEmpty {
            for k in grabs.indices { grabs[k].apply(to: solver) }
            state = grabs.count >= 2 ? .stretching : .grabbing
        } else {
            let pushed = push(with: live, dt: dt, solver: solver, events: &events)
            state = pushed ? .pushing : (solver.isSleeping ? .idle : .releasing)
        }
        if state == .stretching, before != .stretching, grabs.count >= 2 {
            events.append(.stretchStarted((grabs[0].anchor + grabs[1].anchor) / 2))
        } else if before == .stretching, state != .stretching {
            events.append(.stretchEnded(middle))
        }
        return events
    }

    /// Forgets every hand and lets the sheet spring back, e.g. when the page closes.
    func reset(solver: SheetSolver) {
        if !grabs.isEmpty { solver.release(heaviness: 1) }
        grabs.removeAll()
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

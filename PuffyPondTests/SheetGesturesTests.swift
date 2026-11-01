import Foundation
import Testing
import simd
@testable import PuffyPond

@MainActor
struct SheetGesturesTests {
    private let dt: Float = 1.0 / 60

    private func hand(_ slot: Int, _ pose: HandPose, _ p: SIMD2<Float>, velocity: SIMD2<Float> = .zero,
                      tracking: Bool = true) -> SheetHand {
        SheetHand(slot: slot, pose: pose, position: p, velocity: velocity, tracking: tracking)
    }

    /// Feeds the same hands for `frames` frames, stepping the solver like the stage does.
    @discardableResult
    private func run(_ gestures: SheetGestures, _ solver: SheetSolver, frames: Int,
                     _ hands: (Int) -> [SheetHand]) -> [SheetGestures.Event] {
        var events: [SheetGestures.Event] = []
        for f in 0..<frames {
            events += gestures.update(hands: hands(f), dt: dt, solver: solver)
            solver.step(Double(dt))
        }
        return events
    }

    private func displacement(_ solver: SheetSolver, at p: SIMD2<Float>) -> Float {
        simd_length(solver.displacement[solver.nearestNode(to: p)])
    }

    @Test func grabMovesNearNodesMoreThanFar() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        run(gestures, solver, frames: 40) { f in
            [hand(0, .fist, SIMD2(min(Float(f) * 0.05, 0.8), 0))]
        }
        #expect(gestures.state == .grabbing)
        let near = displacement(solver, at: .zero)
        let far = displacement(solver, at: SIMD2(2.8, 1.6))
        #expect(near > 0.3)
        #expect(near > far * 4)
    }

    @Test func stretchScalesBetweenHands() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        run(gestures, solver, frames: 5) { _ in
            [hand(0, .fist, SIMD2(-1, 0)), hand(1, .fist, SIMD2(1, 0))]
        }
        #expect(gestures.state == .stretching)
        run(gestures, solver, frames: 90) { f in
            let spread = 1 + min(Float(f) / 30, 1) * 0.6
            return [hand(0, .fist, SIMD2(-spread, 0)), hand(1, .fist, SIMD2(spread, 0))]
        }
        let i = solver.nearestNode(to: SIMD2(0.5, 0))
        let x = solver.position(i).x
        #expect(x > solver.rest[i].x * 1.35)
        // The middle stays put under a symmetric stretch.
        #expect(displacement(solver, at: .zero) < 0.1)
    }

    @Test func pushOnlyAffectsNodesInRadius() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        let events = gestures.update(hands: [hand(0, .open, .zero, velocity: SIMD2(3, 0))], dt: dt, solver: solver)
        solver.step(SheetSolver.Parameters().substep)
        #expect(gestures.state == .pushing)
        #expect(events.contains { if case .pushed = $0 { true } else { false } })
        let spacing = SheetSolver.size.x / Float(SheetSolver.columns - 1)
        var movedInside = false
        for i in 0..<solver.count {
            let r = simd_length(solver.rest[i])
            if r > SheetGestures.pushRadius + 2 * spacing {
                #expect(solver.displacement[i] == .zero)
            } else if r < SheetGestures.pushRadius * 0.5, solver.displacement[i] != .zero {
                movedInside = true
            }
        }
        #expect(movedInside)
    }

    @Test func slowOpenHandDoesNotPush() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        _ = gestures.update(hands: [hand(0, .open, .zero, velocity: SIMD2(0.2, 0))], dt: dt, solver: solver)
        solver.step(1.0 / 60)
        #expect(gestures.state == .idle)
        #expect(solver.isSleeping)
    }

    @Test func trackingLossReleases() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        run(gestures, solver, frames: 30) { f in [hand(0, .fist, SIMD2(Float(f) * 0.03, 0))] }
        #expect(gestures.state == .grabbing)
        let events = run(gestures, solver, frames: 1) { _ in [hand(0, .fist, SIMD2(0.9, 0), tracking: false)] }
        #expect(events.contains { if case .released = $0 { true } else { false } })
        #expect(gestures.state == .releasing)
        run(gestures, solver, frames: 60 * 8) { _ in [] }
        #expect(gestures.state == .idle)
        #expect(solver.isSleeping)
        #expect(solver.displacement.allSatisfy { $0 == .zero })
    }

    @Test func openingTheFistReleases() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        run(gestures, solver, frames: 20) { f in [hand(0, .fist, SIMD2(Float(f) * 0.03, 0))] }
        let events = run(gestures, solver, frames: 1) { _ in [hand(0, .open, SIMD2(0.6, 0))] }
        #expect(events.contains { if case .released = $0 { true } else { false } })
        #expect(gestures.state == .releasing)
    }

    @Test func secondFistLetGoFallsBackToOneHandGrab() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        run(gestures, solver, frames: 10) { _ in [hand(0, .fist, SIMD2(-1, 0)), hand(1, .fist, SIMD2(1, 0))] }
        #expect(gestures.state == .stretching)
        run(gestures, solver, frames: 2) { _ in [hand(0, .fist, SIMD2(-1, 0)), hand(1, .open, SIMD2(1, 0))] }
        #expect(gestures.state == .grabbing)
    }
}

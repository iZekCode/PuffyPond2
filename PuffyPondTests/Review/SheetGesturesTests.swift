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
        #expect(displacement(solver, at: .zero) < 0.2)
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

    /// Smallest signed area of any triangle of the sheet's mesh; negative means a flipped (folded) triangle.
    private func smallestTriangleArea(_ solver: SheetSolver) -> Float {
        let columns = SheetSolver.columns
        var smallest = Float.infinity
        func area(_ a: Int, _ b: Int, _ c: Int) -> Float {
            let u = solver.position(b) - solver.position(a)
            let v = solver.position(c) - solver.position(a)
            return (u.x * v.y - u.y * v.x) / 2
        }
        for row in 0..<(SheetSolver.rows - 1) {
            for column in 0..<(columns - 1) {
                let a = row * columns + column
                let b = a + 1
                let c = a + columns
                let d = c + 1
                smallest = min(smallest, area(a, c, b), area(b, c, d))
            }
        }
        return smallest
    }

    @Test func longDragBarelyBunchesTheSheet() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        var smallest = Float.infinity
        run(gestures, solver, frames: 180) { f in
            smallest = min(smallest, smallestTriangleArea(solver))
            return [hand(0, .fist, SIMD2(min(Float(f) / 90, 1) * 4.5, min(Float(f) / 90, 1) * -1.5))]
        }
        // Pushed-up paint may bunch a little, never by more than half a grid cell turning inside out.
        let cell = SheetSolver.size.x / Float(SheetSolver.columns - 1) * SheetSolver.size.y / Float(SheetSolver.rows - 1)
        #expect(smallest > -cell * 0.5)
        // The patch travelled all the way with the hand.
        #expect(solver.maxDisplacement > 4)
    }

    @Test func wideStretchNeverFoldsTheSheet() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        var smallest = Float.infinity
        run(gestures, solver, frames: 150) { f in
            smallest = min(smallest, smallestTriangleArea(solver))
            let t = min(Float(f) / 90, 1)
            let spread = 0.8 + 2.2 * t
            return [hand(0, .fist, SIMD2(-spread, 0)), hand(1, .fist, SIMD2(spread, 0))]
        }
        #expect(gestures.state == .stretching)
        let cell = SheetSolver.size.x / Float(SheetSolver.columns - 1) * SheetSolver.size.y / Float(SheetSolver.rows - 1)
        #expect(smallest > -cell * 0.5)
    }

    @Test func stretchAnnouncesItsStartAndEnd() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        let begun = run(gestures, solver, frames: 10) { _ in [hand(0, .fist, SIMD2(-1, 0)), hand(1, .fist, SIMD2(1, 0))] }
        #expect(begun.filter { if case .stretchStarted = $0 { true } else { false } }.count == 1)
        let ended = run(gestures, solver, frames: 2) { _ in [hand(0, .fist, SIMD2(-1, 0)), hand(1, .open, SIMD2(1, 0))] }
        #expect(ended.filter { if case .stretchEnded = $0 { true } else { false } }.count == 1)
    }

    @Test func grabMovesOnlyASmallPatch() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        run(gestures, solver, frames: 90) { f in [hand(0, .fist, SIMD2(min(Float(f) / 60, 1) * 1.5, 0))] }
        #expect(solver.maxDisplacement > 1.2)
        // Anything more than 3 units from the hand's path stays where it was drawn.
        for i in 0..<solver.count {
            let p = solver.rest[i]
            let along = min(max(p.x / 1.5, 0), 1)
            if simd_length(p - SIMD2(along * 1.5, 0)) > 3 {
                #expect(simd_length(solver.displacement[i]) < 0.1)
            }
        }
    }

    @Test func twoFistsEachMoveOnlyTheirOwnPatch() {
        let solver = SheetSolver()
        let gestures = SheetGestures()
        run(gestures, solver, frames: 90) { f in
            let t = min(Float(f) / 60, 1)
            return [hand(0, .fist, SIMD2(-1.5 - t, 0)), hand(1, .fist, SIMD2(1.5 + t, 0))]
        }
        #expect(gestures.state == .stretching)
        #expect(displacement(solver, at: SIMD2(2.5, 0)) > 0.7)
        #expect(displacement(solver, at: SIMD2(0, 1.8)) < 0.05)
    }
}

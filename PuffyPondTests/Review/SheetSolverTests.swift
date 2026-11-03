import Foundation
import Testing
import simd
@testable import PuffyPond

@MainActor
struct SheetSolverTests {
    @Test func releasedSheetReturnsToRest() {
        let solver = SheetSolver()
        let middle = solver.nearestNode(to: .zero)
        for _ in 0..<30 {
            solver.clearInputs()
            solver.pin(middle, to: SIMD2(1.2, 0.6), weight: 0.5)
            solver.step(1.0 / 60)
        }
        #expect(simd_length(solver.displacement[middle]) > 0.5)
        #expect(!solver.isSleeping)

        solver.clearInputs()
        solver.release(heaviness: 1)
        for _ in 0..<(60 * 8) { solver.step(1.0 / 60) }
        #expect(solver.isSleeping)
        #expect(solver.displacement.allSatisfy { $0 == .zero })
    }

    @Test func gridMatchesSheetShape() {
        let solver = SheetSolver()
        #expect(solver.count == SheetSolver.columns * SheetSolver.rows)
        let corner = solver.rest[solver.index(column: 0, row: 0)]
        #expect(abs(corner.x + SheetSolver.size.x / 2) < 1e-5)
        #expect(abs(corner.y - SheetSolver.size.y / 2) < 1e-5)
    }

    @Test func smoothingKeepsNeighboursTogether() {
        let solver = SheetSolver()
        let middle = solver.nearestNode(to: .zero)
        for _ in 0..<20 {
            solver.clearInputs()
            solver.pin(middle, to: SIMD2(0.8, 0), weight: 1)
            solver.step(1.0 / 60)
        }
        let neighbour = middle + 1
        #expect(solver.displacement[neighbour].x > 0.05)
    }
}

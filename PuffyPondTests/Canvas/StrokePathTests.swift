import Foundation
import Testing
import simd
@testable import PuffyPond

@MainActor
struct StrokePathTests {
    private func line(_ xs: [Float]) -> [StrokePoint] {
        xs.enumerated().map { StrokePoint(p: SIMD2($0.element, 0), born: Double($0.offset)) }
    }

    @Test func noBeadsUntilTheGapReachesTheSpacing() {
        #expect(StrokePath.beads(from: .zero, to: SIMD2(0.04, 0), spacing: 0.05).isEmpty)
    }

    @Test func beadsAreEvenAndEndAtThePoint() {
        let beads = StrokePath.beads(from: .zero, to: SIMD2(0.2, 0), spacing: 0.05)
        #expect(beads.count == 4)
        #expect(beads.last == SIMD2(0.2, 0))
        #expect(abs(beads[0].x - 0.05) < 1e-6)
    }

    @Test func aLongJumpIsCapped() {
        #expect(StrokePath.beads(from: .zero, to: SIMD2(10, 0), spacing: 0.05).count == 12)
    }

    @Test func missingTheStrokeLeavesItAlone() {
        #expect(StrokePath.cut(line([0, 0.1, 0.2]), at: SIMD2(5, 5), radius: 0.1) == nil)
    }

    @Test func erasingTheMiddleSplitsTheStroke() {
        let runs = StrokePath.cut(line([0, 0.1, 0.2, 0.3, 0.4]), at: SIMD2(0.2, 0), radius: 0.05)
        #expect(runs?.map { $0.map(\.p.x) } == [[0, 0.1], [0.3, 0.4]])
    }

    @Test func erasingAnEndKeepsTheRest() {
        let runs = StrokePath.cut(line([0, 0.1, 0.2]), at: SIMD2(0, 0), radius: 0.05)
        #expect(runs?.map { $0.map(\.p.x) } == [[0.1, 0.2]])
    }

    @Test func erasingEverythingLeavesNoRuns() {
        #expect(StrokePath.cut(line([0, 0.01]), at: .zero, radius: 1)?.isEmpty == true)
    }
}

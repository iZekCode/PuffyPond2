import Testing
@testable import PuffyPond

struct HoverDwellTests {
    /// Holds on `id` for `seconds` in steps of `dt`; returns the ids that fired.
    private func hold(_ dwell: inout HoverDwell, _ id: String?, seconds: Double, dt: Double = 0.1) -> [String] {
        var fired: [String] = []
        for _ in 0..<Int((seconds / dt).rounded()) {
            if let done = dwell.update(hoveredID: id, dt: dt) { fired.append(done) }
        }
        return fired
    }

    @Test func firesAfterOneSecond() {
        var dwell = HoverDwell()
        #expect(hold(&dwell, "a", seconds: 0.9).isEmpty)
        #expect(hold(&dwell, "a", seconds: 0.1) == ["a"])
    }

    @Test func firesOnlyOnce() {
        var dwell = HoverDwell()
        #expect(hold(&dwell, "a", seconds: 3) == ["a"])
    }

    @Test func leavingResets() {
        var dwell = HoverDwell()
        #expect(hold(&dwell, "a", seconds: 0.9).isEmpty)
        #expect(hold(&dwell, nil, seconds: 0.1).isEmpty)
        #expect(hold(&dwell, "a", seconds: 0.9).isEmpty)
    }

    @Test func switchingTargetsRestarts() {
        var dwell = HoverDwell()
        #expect(hold(&dwell, "a", seconds: 0.9).isEmpty)
        #expect(hold(&dwell, "b", seconds: 0.9).isEmpty)
        #expect(hold(&dwell, "b", seconds: 0.1) == ["b"])
    }

    @Test func relatchesAfterLeaving() {
        var dwell = HoverDwell()
        #expect(hold(&dwell, "a", seconds: 1) == ["a"])
        _ = hold(&dwell, nil, seconds: 0.1)
        #expect(hold(&dwell, "a", seconds: 1) == ["a"])
    }

    @Test func progressReportsTheFraction() throws {
        var dwell = HoverDwell()
        #expect(dwell.progress == nil)
        _ = hold(&dwell, "a", seconds: 0.5)
        let progress = try #require(dwell.progress)
        #expect(progress.id == "a")
        #expect(abs(progress.value - 0.5) < 1e-9)
        _ = hold(&dwell, "a", seconds: 0.5)
        #expect(dwell.progress == nil, "a finished hold shows no ring")
    }

    @Test func requireReleaseBlocksUntilTheHandLeaves() {
        var dwell = HoverDwell()
        _ = hold(&dwell, "a", seconds: 0.5)
        dwell.requireRelease()
        #expect(dwell.progress == nil)
        #expect(hold(&dwell, "b", seconds: 3).isEmpty, "a hand that stays put never presses what appears under it")
        _ = hold(&dwell, nil, seconds: 0.1)
        #expect(hold(&dwell, "b", seconds: 1) == ["b"])
    }
}

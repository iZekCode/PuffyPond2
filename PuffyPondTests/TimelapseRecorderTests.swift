import Testing
import simd
@testable import PuffyPond

struct TimelapseRecorderTests {
    private func dab(_ x: Float = 0) -> BrushDab {
        BrushDab(from: SIMD2(x, 0), to: SIMD2(x + 0.1, 0), radius: 0.1, speed: 1)
    }

    private func recorder(times: [Double]) -> TimelapseRecorder {
        var remaining = times
        return TimelapseRecorder(clock: { remaining.isEmpty ? 0 : remaining.removeFirst() })
    }

    @Test func firstEventIsTimeZero() {
        let recorder = recorder(times: [100, 102.5])
        recorder.record(dabs: [dab()], color: SIMD3(1, 0, 0), ncaModel: 0, seed: 1, brush: .butterfly)
        recorder.recordErase(at: .zero, radius: 0.3, dt: 0.016)
        #expect(recorder.snapshot()?.events.map(\.t) == [0, 2.5])
    }

    @Test func dabSeedsMatchWhatLayGivesTheLayer() throws {
        let recorder = recorder(times: [5, 5, 5])
        recorder.record(dabs: [dab(0), dab(1), dab(2)], color: SIMD3(1, 0, 0), ncaModel: 3, seed: 10,
                        brush: .ladybug)
        let recorded = try #require(recorder.snapshot()).events.compactMap { event -> RecordedDab? in
            if case let .dab(d) = event { d } else { nil }
        }
        #expect(recorded.count == 3)
        let wanted: [Float] = [10, 15.1, 20.2]
        for (got, want) in zip(recorded.map(\.seed), wanted) {
            let difference: Float = abs(got - want)
            #expect(difference < 1e-4)
        }
        #expect(recorded.allSatisfy { $0.strokeSeed == 10 && $0.ncaModel == 3 && $0.brush == .ladybug })
    }

    @Test func snapshotIsAValueCopy() {
        let recorder = recorder(times: [1, 2, 3])
        recorder.record(dabs: [dab()], color: .zero, ncaModel: 0, seed: 1, brush: .butterfly)
        let first = recorder.snapshot()
        recorder.record(dabs: [dab()], color: .zero, ncaModel: 0, seed: 2, brush: .butterfly)
        recorder.recordErase(at: .zero, radius: 0.3, dt: 0.016)
        #expect(first?.events.count == 1)
        #expect(recorder.snapshot()?.events.count == 3)
    }

    @Test func resetStartsFresh() {
        let recorder = recorder(times: [10, 20, 30])
        recorder.record(dabs: [dab()], color: .zero, ncaModel: 0, seed: 1, brush: .butterfly)
        recorder.reset()
        #expect(recorder.snapshot() == nil)
        recorder.record(dabs: [dab()], color: .zero, ncaModel: 0, seed: 1, brush: .butterfly)
        #expect(recorder.snapshot()?.events.first?.t == 0)
    }

    @Test func erasesAreCoalesced() {
        let recorder = recorder(times: [0, 0.01, 0.02, 0.2, 0.21])
        recorder.recordErase(at: SIMD2(0, 0), radius: 0.3, dt: 0.016)
        recorder.recordErase(at: SIMD2(0.01, 0), radius: 0.3, dt: 0.016)      // same spot, a moment later: skipped
        recorder.recordErase(at: SIMD2(1, 0), radius: 0.3, dt: 0.016)         // moved far: kept
        recorder.recordErase(at: SIMD2(1.01, 0), radius: 0.3, dt: 0.016)      // long enough since the last: kept
        recorder.recordErase(at: SIMD2(1.02, 0), radius: 0.3, dt: 0.016)      // same spot, a moment later: skipped
        #expect(recorder.snapshot()?.events.count == 3)
    }
}

import Testing
@testable import PuffyPond

struct ReplayTimelineTests {
    private func steady(until end: Double, every step: Double = 0.1) -> [Double] {
        (0...Int((end / step).rounded())).map { Double($0) * step }
    }

    @Test func emptyAndSingleEventHaveNoDuration() {
        #expect(ReplayTimeline(eventTimes: []).duration == 0)
        let single = ReplayTimeline(eventTimes: [3.0])
        #expect(single.duration == 0)
        let mapped = single.replayTime(forRecorded: 3)
        #expect(mapped == 0)
        #expect(mapped.isFinite)
    }

    @Test func shortSessionPlaysAtRealTime() {
        let timeline = ReplayTimeline(eventTimes: steady(until: 6))
        #expect(abs(timeline.duration - 6) < 1e-9)
    }

    @Test func longSessionFitsTheTarget() {
        let timeline = ReplayTimeline(eventTimes: steady(until: 300))
        #expect(abs(timeline.duration - ReplayTimeline.targetSeconds) < 1e-9)
    }

    @Test func idleGapIsCollapsed() {
        let timeline = ReplayTimeline(eventTimes: [0, 1, 2, 32, 33])
        #expect(timeline.duration == 3.25)
        #expect(timeline.replayTime(forRecorded: 32) == 2.25)
    }

    @Test func mappingIsMonotonicAndInvertible() {
        let times: [Double] = [0, 0.4, 0.9, 5, 5.2, 400, 400.5, 900]
        let timeline = ReplayTimeline(eventTimes: times)
        var last = -1.0
        var t = -1.0
        while t < 1000 {
            let mapped = timeline.replayTime(forRecorded: t)
            #expect(mapped >= last)
            last = mapped
            t += 0.37
        }
        for time in times {
            let back = timeline.recordedTime(forReplay: timeline.replayTime(forRecorded: time))
            #expect(abs(back - time) < 1e-6)
        }
    }
}

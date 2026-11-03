import Foundation

/// How a recorded painting session maps onto a short replay: long idle gaps are cut down, and a long session
/// is sped up to fit `targetSeconds`. A short one plays at real time.
struct ReplayTimeline: Equatable {
    static let targetSeconds = 18.0
    /// Recorded gaps longer than this are collapsed…
    static let idleGap = 1.5
    /// …to this many recorded seconds.
    static let idleReplacement = 0.25

    private let times: [Double]
    /// Recorded time with idle gaps collapsed, at each event.
    private let active: [Double]
    private let speed: Double

    /// `eventTimes`: recorded seconds since the recording started, ascending.
    init(eventTimes: [Double]) {
        times = eventTimes
        var running = 0.0
        var cumulative: [Double] = []
        for (index, time) in eventTimes.enumerated() {
            if index > 0 {
                let gap = max(time - eventTimes[index - 1], 0)
                running += gap > Self.idleGap ? Self.idleReplacement : gap
            }
            cumulative.append(running)
        }
        active = cumulative
        speed = max(1, running / Self.targetSeconds)
    }

    private var total: Double { active.last ?? 0 }

    /// Replay seconds; 0 when there are fewer than two events or all events share one time.
    var duration: Double { times.count < 2 ? 0 : total / speed }

    func replayTime(forRecorded t: Double) -> Double {
        guard times.count >= 2, total > 0, t.isFinite else { return 0 }
        let clamped = min(max(t, times[0]), times[times.count - 1])
        // Last event at or before `clamped`, capped so a following event exists.
        var low = 0
        var high = times.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if times[mid] <= clamped { low = mid } else { high = mid - 1 }
        }
        let i = min(low, times.count - 2)
        let length = times[i + 1] - times[i]
        let fraction = length > 0 ? (clamped - times[i]) / length : 0
        return (active[i] + fraction * (active[i + 1] - active[i])) / speed
    }

    func recordedTime(forReplay t: Double) -> Double {
        guard times.count >= 2, total > 0, t.isFinite else { return times.first ?? 0 }
        let a = min(max(t * speed, 0), total)
        var low = 0
        var high = times.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if active[mid] <= a { low = mid } else { high = mid - 1 }
        }
        let i = min(low, times.count - 2)
        let span = active[i + 1] - active[i]
        let fraction = span > 0 ? (a - active[i]) / span : 0
        return times[i] + fraction * (times[i + 1] - times[i])
    }
}

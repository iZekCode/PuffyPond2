import Foundation

/// Everything the Report page shows for one local day: the paintings made that day and their movement
/// stats merged together. Pure: built from the saved records, nothing is stored.
struct DayReport {
    /// The day's movement stats, summed or maxed over every session that recorded any.
    struct Stats: Equatable {
        /// Highest shoulder abduction per arm, in degrees.
        var highestROM: [Side: Double] = [:]
        /// Straightest elbow per arm, in degrees.
        var elbowExtension: [Side: Double] = [:]
        /// Highest wrist above its shoulder per arm, in shoulder widths.
        var reachHeight: [Side: Double] = [:]
        /// Biggest reach area of one session per arm, in shoulder widths squared.
        var reachArea: [Side: Double] = [:]
        /// Seconds of painting per canvas cell (`SessionStats.heatmapColumns` × `heatmapRows`, row-major).
        var heatmap = [Double](repeating: 0, count: SessionStats.heatmapColumns * SessionStats.heatmapRows)
        /// Each hand's share of the painting time (sums to 1); empty when no hand painted.
        var dominance: [Side: Double] = [:]
        var gripCycles: [Side: Int] = [:]
        var maxTrunkLean: Double = 0
        /// Seconds spent on the canvas page.
        var duration: TimeInterval = 0
    }

    let day: Date
    /// The day's paintings, newest first.
    let paintings: [Painting]
    /// Nil when no painting that day has movement data (none made, or all drawn by touch or before stats).
    let stats: Stats?
    let questDone: Bool

    init(day: Date, paintings all: [Painting], calendar: Calendar = .current) {
        self.day = calendar.startOfDay(for: day)
        paintings = all.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date > $1.date }
        questDone = paintings.contains { $0.record.isDailyQuest }
        stats = Self.merge(paintings.compactMap(\.record.stats))
    }

    private static func merge(_ sessions: [SessionStats]) -> Stats? {
        guard !sessions.isEmpty else { return nil }
        var stats = Stats()
        var painting: [Side: Double] = [:]
        for session in sessions {
            stats.highestROM.merge(session.romDegrees, uniquingKeysWith: max)
            stats.elbowExtension.merge(session.elbowExtension, uniquingKeysWith: max)
            stats.reachHeight.merge(session.reachHeight, uniquingKeysWith: max)
            stats.reachArea.merge(session.reachArea, uniquingKeysWith: max)
            stats.gripCycles.merge(session.gripCycles, uniquingKeysWith: +)
            painting.merge(session.pinchSeconds, uniquingKeysWith: +)
            stats.maxTrunkLean = max(stats.maxTrunkLean, session.maxTrunkLean)
            stats.duration += session.duration
            for (i, hundredths) in session.heatmap.enumerated() where i < stats.heatmap.count {
                stats.heatmap[i] += Double(hundredths) / 100
            }
        }
        let total = painting.values.reduce(0, +)
        if total > 0 {
            stats.dominance = painting.mapValues { $0 / total }
        }
        return stats
    }
}

import Foundation
import Testing
@testable import PuffyPond

struct DayReportTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func painting(_ date: Date, stats: SessionStats? = nil, quest: Bool = false) -> Painting {
        Painting(url: URL(fileURLWithPath: "/tmp/painting-\(date.timeIntervalSince1970).png"),
                 record: PaintingRecord(date: date, templateID: quest ? "quest-moon" : nil, isDailyQuest: quest, stats: stats))
    }

    private func stats(rom: [Side: Double], pinch: [Side: Double], cell: Int, seconds: UInt16,
                       grips: [Side: Int] = [:], lean: Double = 0) -> SessionStats {
        var stats = SessionStats()
        stats.romDegrees = rom
        stats.pinchSeconds = pinch
        stats.heatmap[cell] = seconds
        stats.gripCycles = grips
        stats.maxTrunkLean = lean
        return stats
    }

    @Test func emptyDayHasNoStats() {
        let other = painting(date(2, hour: 10), stats: stats(rom: [.left: 90], pinch: [.left: 5], cell: 0, seconds: 100))
        let report = DayReport(day: date(1, hour: 12), paintings: [other], calendar: calendar)

        #expect(report.paintings.isEmpty)
        #expect(report.stats == nil)
        #expect(report.questDone == false)
    }

    @Test func mergesSessions() throws {
        let morning = painting(date(1, hour: 9),
                               stats: stats(rom: [.left: 80, .right: 120], pinch: [.left: 10, .right: 20],
                                            cell: 5, seconds: 300, grips: [.right: 4], lean: 8))
        let evening = painting(date(1, hour: 19),
                               stats: stats(rom: [.left: 95, .right: 100], pinch: [.left: 10, .right: 40],
                                            cell: 5, seconds: 200, grips: [.right: 3, .left: 1], lean: 18),
                               quest: true)
        let report = DayReport(day: date(1, hour: 12), paintings: [evening, morning], calendar: calendar)

        #expect(report.paintings.count == 2)
        #expect(report.questDone)
        let stats = try #require(report.stats)
        #expect(stats.highestROM == [.left: 95, .right: 120])
        #expect(stats.heatmap[5] == 5)                       // 300 + 200 hundredths = 5 s
        #expect(stats.heatmap.reduce(0, +) == 5)
        #expect(abs(stats.dominance[.right]! - 0.75) < 1e-9) // 60 of 80 painting seconds
        #expect(abs(stats.dominance[.left]! - 0.25) < 1e-9)
        #expect(stats.gripCycles == [.right: 7, .left: 1])
        #expect(stats.maxTrunkLean == 18)
    }

    @Test func legacyPaintingsCountButAddNoStats() throws {
        let legacy = painting(date(1, hour: 8))
        let tracked = painting(date(1, hour: 10), stats: stats(rom: [.right: 110], pinch: [.right: 12], cell: 3, seconds: 50))
        let report = DayReport(day: date(1, hour: 12), paintings: [tracked, legacy], calendar: calendar)

        #expect(report.paintings.count == 2)
        let stats = try #require(report.stats)
        #expect(stats.highestROM == [.right: 110])
        #expect(stats.dominance == [.right: 1])
        #expect(stats.heatmap[3] == 0.5)

        let onlyLegacy = DayReport(day: date(1, hour: 12), paintings: [legacy], calendar: calendar)
        #expect(onlyLegacy.paintings.count == 1)
        #expect(onlyLegacy.stats == nil)
    }

    @Test func noPaintingTimeHasNoDominance() throws {
        let still = painting(date(1, hour: 10), stats: stats(rom: [.left: 60], pinch: [:], cell: 0, seconds: 0))
        let report = DayReport(day: date(1, hour: 12), paintings: [still], calendar: calendar)
        #expect(try #require(report.stats).dominance.isEmpty)
    }

    @Test func heatmapCanBeFilteredByHandAndPainting() {
        let count = SessionStats.heatmapColumns * SessionStats.heatmapRows
        var a = SessionStats()
        a.heatmap = Array(repeating: 100, count: count)
        a.sideHeatmaps = [.left: Array(repeating: 100, count: count)]
        var b = SessionStats()
        b.heatmap = Array(repeating: 200, count: count)
        b.sideHeatmaps = [.right: Array(repeating: 200, count: count)]
        let first = painting(Date(), stats: a)
        let second = painting(Date().addingTimeInterval(60), stats: b)

        #expect(DayReport.heatmap(of: [first, second], side: nil)?.first == 3)
        #expect(DayReport.heatmap(of: [first, second], side: .left)?.first == 1)
        #expect(DayReport.heatmap(of: [first, second], side: .right)?.first == 2)
        #expect(DayReport.heatmap(of: [first], side: .right) == nil)   // that painting has no right-hand data
        #expect(DayReport.heatmap(of: [second], side: nil)?.first == 2)
    }
}

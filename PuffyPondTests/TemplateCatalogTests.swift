import Foundation
import Testing
@testable import PuffyPond

struct TemplateCatalogTests {
    private var ordered: [TemplateKind] { TemplateCatalog.ordered }

    @Test func orderedRunsEasyToHardWithoutDuplicates() {
        #expect(ordered.count == 9)
        #expect(Set(ordered.map(\.id)).count == ordered.count)
        #expect(ordered.map(\.difficulty) == ordered.map(\.difficulty).sorted())
        #expect(ordered.filter { $0.difficulty == .easy }.count == 3)
        #expect(ordered.filter { $0.difficulty == .medium }.count == 3)
        #expect(ordered.filter { $0.difficulty == .hard }.count == 3)
    }

    @Test func existingPaintingIDsStillResolve() {
        // Paintings saved before this update carry these ids in their sidecar.
        #expect(TemplateCatalog.kind(id: "fish") == .fish)
        #expect(TemplateCatalog.kind(id: "turtle") == .turtle)
        #expect(TemplateCatalog.kind(id: "duck") == .duck)
        #expect(TemplateCatalog.kind(id: "nope") == nil)
    }

    @Test func everyTemplateHasDrawableOutline() {
        for kind in ordered {
            let shape = kind.art.shape(center: .zero, size: SIMD2(2, 1.5))
            #expect(!shape.lines.isEmpty, "\(kind.id) has no outline")
            #expect(shape.lines.allSatisfy { $0.count > 1 }, "\(kind.id) has a degenerate line")
            let points = shape.lines.flatMap { $0 } + shape.eyes
            #expect(points.allSatisfy { abs($0.x) <= 1.001 && abs($0.y) <= 0.751 }, "\(kind.id) overflows its box")
        }
    }

    @Test func firstEasyAlwaysUnlocked() throws {
        let first = try #require(ordered.first)
        #expect(first.difficulty == .easy)
        #expect(TemplateCatalog.isUnlocked(first, saved: []))
        #expect(!TemplateCatalog.isUnlocked(ordered[1], saved: []))
    }

    @Test func unlockFollowsSavedPaintings() {
        let second = ordered[1]
        #expect(!TemplateCatalog.isUnlocked(second, saved: []))
        #expect(TemplateCatalog.isUnlocked(second, saved: [ordered[0].id]))
        // Derived, never stored: the painting going away locks it again.
        #expect(!TemplateCatalog.isUnlocked(second, saved: []))
    }

    @Test func unlockIsProgressiveNotSkipping() {
        // Only the template right after a saved one opens; saving #3 does not open #5.
        let saved: Set<String> = [ordered[0].id, ordered[1].id, ordered[2].id]
        #expect(TemplateCatalog.isUnlocked(ordered[3], saved: saved))
        #expect(!TemplateCatalog.isUnlocked(ordered[4], saved: saved))
        #expect(!TemplateCatalog.isUnlocked(ordered[8], saved: saved))
        #expect(TemplateCatalog.previous(of: ordered[0]) == nil)
        #expect(TemplateCatalog.previous(of: ordered[3]) == ordered[2])
    }
}

struct DailyQuestStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "DailyQuestStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!   // UTC+7
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// A store whose "random" picks come from a script, and which counts how often it was asked.
    private final class Rolls {
        var script: [Int]
        private(set) var asked = 0
        init(_ script: [Int]) { self.script = script }
        func next(_ upperBound: Int) -> Int {
            asked += 1
            return script.removeFirst() % upperBound
        }
    }

    private func makeStore(_ defaults: UserDefaults, _ rolls: Rolls) -> DailyQuestStore {
        DailyQuestStore(defaults: defaults, calendar: calendar, roll: rolls.next)
    }

    @Test func questPoolIsSeparateFromTemplates() {
        #expect(QuestCatalog.all.count >= 10)
        #expect(Set(QuestCatalog.all.map(\.id)).count == QuestCatalog.all.count)
        let templateIDs = Set(TemplateCatalog.ordered.map(\.id))
        #expect(QuestCatalog.all.allSatisfy { !templateIDs.contains($0.id) })
        for quest in QuestCatalog.all {
            let shape = quest.art.shape(center: .zero, size: SIMD2(2, 1.5))
            #expect(!shape.lines.isEmpty, "\(quest.id) has no outline")
        }
    }

    @Test func dailyQuestStableWithinDay() {
        let rolls = Rolls([3, 5])
        let store = makeStore(makeDefaults(), rolls)
        let morning = store.quest(for: date(1, hour: 0, minute: 5))
        let night = store.quest(for: date(1, hour: 23, minute: 55))
        #expect(morning == night)
        #expect(rolls.asked == 1)
    }

    @Test func dailyQuestSurvivesRelaunch() {
        let defaults = makeDefaults()
        let first = makeStore(defaults, Rolls([4])).quest(for: date(1))
        let rolls = Rolls([7])
        let again = makeStore(defaults, rolls).quest(for: date(1))
        #expect(first == again)
        #expect(rolls.asked == 0)
    }

    @Test func dailyQuestRerollsNextDay() {
        let rolls = Rolls([2, 6])
        let store = makeStore(makeDefaults(), rolls)
        let today = store.quest(for: date(1))
        let tomorrow = store.quest(for: date(2))
        #expect(rolls.asked == 2)
        #expect(today != tomorrow)
    }

    @Test func dailyQuestNeverRepeatsYesterday() {
        // The script would pick yesterday's quest again (index 2); the store must step past it.
        let rolls = Rolls([2, 2])
        let store = makeStore(makeDefaults(), rolls)
        let yesterday = store.quest(for: date(1))
        let today = store.quest(for: date(2))
        #expect(yesterday.id == QuestCatalog.all[2].id)
        #expect(today != yesterday)
    }

    @Test func dailyQuestUsesLocalMidnight() {
        // 23:30 and 00:30 local are one hour apart but different days (and the same UTC day).
        let rolls = Rolls([1, 4])
        let store = makeStore(makeDefaults(), rolls)
        _ = store.quest(for: date(1, hour: 23, minute: 30))
        _ = store.quest(for: date(2, hour: 0, minute: 30))
        #expect(rolls.asked == 2)
    }

    @Test func unknownStoredQuestIsRerolled() {
        let defaults = makeDefaults()
        let rolls = Rolls([0])
        let store = makeStore(defaults, rolls)
        defaults.set(["2026-11-01": "retired-quest"], forKey: DailyQuestStore.defaultsKey)
        let quest = store.quest(for: date(1))
        #expect(quest == QuestCatalog.all[0])
        #expect(rolls.asked == 1)
    }
}

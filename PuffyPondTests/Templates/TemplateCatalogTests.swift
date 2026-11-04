import Foundation
import Testing
@testable import PuffyPond

struct TemplateCatalogTests {
    private var all: [TemplateDesign] { TemplateCatalog.all }

    @Test func catalogRunsEasyToHardWithoutDuplicates() {
        #expect(all.count == TemplateKind.allCases.count + QuestCatalog.all.count + 20)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(all.map(\.level) == all.map(\.level).sorted())
        #expect(TemplateCatalog.levels == [1, 2, 3, 4])
        #expect(TemplateDesign.pictures.count == 20)
        for level in 1...4 {
            #expect(TemplateDesign.pictures.filter { $0.level == level }.count == 5, "level \(level)")
        }
    }

    @Test func existingPaintingIDsStillResolve() {
        // Paintings saved before carry these ids in their sidecar: old shape ids and old quest ids.
        #expect(TemplateCatalog.kind(id: "fish") == .pebble)
        #expect(TemplateCatalog.kind(id: "turtle") == .bumpy)
        #expect(TemplateCatalog.design(id: "duck")?.title == TemplateKind.bean.title)
        #expect(TemplateCatalog.design(id: "quest-rocket")?.title == "Roket")
        #expect(TemplateCatalog.design(id: "nope") == nil)
        #expect(TemplateChoice(templateID: "quest-house", isDailyQuest: true).art != nil)
        #expect(TemplateChoice(templateID: "tpl-hati", isDailyQuest: false).title == "Hati")
    }

    @Test func everyTemplateHasDrawableOutline() {
        for design in all {
            let shape = design.art.shape(center: .zero, size: SIMD2(2, 1.5))
            #expect(!shape.lines.isEmpty, "\(design.id) has no outline")
            #expect(shape.lines.allSatisfy { $0.count > 1 }, "\(design.id) has a degenerate line")
            let points = shape.lines.flatMap { $0 } + shape.eyes
            #expect(points.allSatisfy { abs($0.x) <= 1.001 && abs($0.y) <= 0.751 }, "\(design.id) overflows its box")
        }
    }

    @Test func harderPicturesHaveMoreLinesAndSpreadWider() {
        func average(_ level: Int, _ value: (TemplateDesign) -> Float) -> Float {
            let designs = TemplateDesign.pictures.filter { $0.level == level }
            return designs.map(value).reduce(0, +) / Float(designs.count)
        }
        for level in 1...3 {
            #expect(average(level) { Float($0.art.paths.count) } < average(level + 1) { Float($0.art.paths.count) })
            #expect(average(level) { $0.art.spread } < average(level + 1) { $0.art.spread })
        }
    }

    @Test func hardShapesReachTheCorners() {
        // Hard shapes are drawn bigger and touch all four corners of their box, to widen the range of motion.
        for kind in TemplateKind.allCases where kind.difficulty == .hard {
            #expect(kind.art.spread > 1, "\(kind.id) is not drawn bigger")
            let shape = kind.art.shape(center: .zero, size: SIMD2(2, 1.5))
            let points = shape.lines.flatMap { $0 }
            #expect(points.contains { $0.x < -0.7 && $0.y > 0.45 }, "\(kind.id) misses top left")
            #expect(points.contains { $0.x > 0.7 && $0.y > 0.45 }, "\(kind.id) misses top right")
            #expect(points.contains { $0.x < -0.7 && $0.y < -0.45 }, "\(kind.id) misses bottom left")
            #expect(points.contains { $0.x > 0.7 && $0.y < -0.45 }, "\(kind.id) misses bottom right")
        }
    }

    @Test func shapesAreAbstractWithoutEyes() {
        #expect(TemplateKind.allCases.allSatisfy { $0.art.eyes.isEmpty })
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

    @Test func questComesFromTheTemplates() {
        let store = makeStore(makeDefaults(), Rolls([5]))
        let quest = store.quest(for: date(1))
        #expect(TemplateCatalog.design(id: quest.id) == quest)
    }

    @Test func shuffleGivesAnotherTemplateForToday() {
        let defaults = makeDefaults()
        let rolls = Rolls([4, 4])
        let store = makeStore(defaults, rolls)
        let first = store.quest(for: date(1))
        let shuffled = store.reroll(for: date(1))
        #expect(shuffled != first)
        #expect(store.quest(for: date(1)) == shuffled)   // the shuffle sticks for the rest of the day
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
        #expect(yesterday.id == TemplateCatalog.all[2].id)
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
        #expect(quest == TemplateCatalog.all[0])
        #expect(rolls.asked == 1)
    }
}

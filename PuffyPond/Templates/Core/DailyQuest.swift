import Foundation

/// A challenge of the day. Lives in its own pool, apart from the template list.
struct Quest: Equatable, Identifiable {
    let id: String
    let title: String
    let art: OutlineArt
}

enum QuestCatalog {
    static let all: [Quest] = [
        Quest(id: "quest-rocket", title: "Roket",
              art: OutlineArt(paths: ["M150 20 C185 55 190 110 180 150 L120 150 C110 110 115 55 150 20 Z",
                                      "M120 120 L90 165 L120 150", "M180 120 L210 165 L180 150",
                                      "M162 85 C162 94 138 94 138 85 C138 76 162 76 162 85 Z",
                                      "M135 150 L150 195 L165 150"],
                              eyes: [], color: Paint.colors[3])),
        Quest(id: "quest-house", title: "Rumah",
              art: OutlineArt(paths: ["M70 110 L150 40 L230 110 Z",
                                      "M90 110 L90 180 L210 180 L210 110",
                                      "M135 180 L135 140 L165 140 L165 180"],
                              eyes: [], color: Paint.colors[0])),
        Quest(id: "quest-tree", title: "Pohon",
              art: OutlineArt(paths: ["M100 120 C60 120 55 70 95 65 C95 30 150 20 165 50 C200 35 235 70 210 95 "
                                          + "C235 120 200 135 180 120 Z",
                                      "M138 125 L135 190 L170 190 L165 125"],
                              eyes: [], color: Paint.colors[4])),
        Quest(id: "quest-flower", title: "Bunga",
              art: OutlineArt(paths: ["M150 62 C128 28 172 28 150 62 Z", "M150 98 C128 132 172 132 150 98 Z",
                                      "M132 80 C98 58 98 102 132 80 Z", "M168 80 C202 58 202 102 168 80 Z",
                                      "M168 80 C168 95 132 95 132 80 C132 65 168 65 168 80 Z",
                                      "M150 132 C150 160 145 180 150 205",
                                      "M150 170 C175 150 195 160 198 175 C180 185 160 182 150 170 Z"],
                              eyes: [], color: Paint.colors[3])),
        Quest(id: "quest-ice-cream", title: "Es krim",
              art: OutlineArt(paths: ["M110 105 L150 200 L190 105 Z",
                                      "M105 105 C90 50 210 50 195 105 Z",
                                      "M105 105 C120 118 135 105 150 118 C165 105 180 118 195 105",
                                      "M160 35 C160 48 140 48 140 35 C140 22 160 22 160 35 Z"],
                              eyes: [], color: Paint.colors[3])),
        Quest(id: "quest-moon", title: "Bulan dan bintang",
              art: OutlineArt(paths: ["M170 30 C110 40 80 100 105 150 C130 200 200 195 225 160 C170 175 130 120 170 30 Z",
                                      "M230 40 L238 62 L262 63 L243 77 L250 100 L230 87 L210 100 L217 77 L198 63 L222 62 Z"],
                              eyes: [], color: Paint.colors[2])),
        Quest(id: "quest-boat", title: "Perahu layar",
              art: OutlineArt(paths: ["M60 150 L240 150 L215 185 L85 185 Z", "M150 150 L150 30",
                                      "M150 35 L215 140 L150 140 Z", "M142 55 L95 140 L142 140 Z"],
                              eyes: [], color: Paint.colors[1])),
        Quest(id: "quest-rainbow", title: "Pelangi",
              art: OutlineArt(paths: ["M40 170 C40 20 260 20 260 170", "M70 170 C70 50 230 50 230 170",
                                      "M100 170 C100 80 200 80 200 170",
                                      "M25 175 C15 155 50 145 55 160 C65 148 90 160 82 175 Z",
                                      "M275 175 C285 155 250 145 245 160 C235 148 210 160 218 175 Z"],
                              eyes: [], color: Paint.colors[5])),
        Quest(id: "quest-balloon", title: "Balon",
              art: OutlineArt(paths: ["M150 20 C205 20 220 90 175 125 L180 135 L120 135 L125 125 C80 90 95 20 150 20 Z",
                                      "M150 135 C140 155 160 175 150 200",
                                      "M118 55 C120 45 130 38 138 36"],
                              eyes: [], color: Paint.colors[0])),
        Quest(id: "quest-cupcake", title: "Kue mangkuk",
              art: OutlineArt(paths: ["M95 120 L110 190 L190 190 L205 120 Z",
                                      "M90 120 C70 100 100 80 115 85 C115 55 185 55 185 85 C200 80 230 100 210 120 Z",
                                      "M160 42 C160 55 140 55 140 42 C140 29 160 29 160 42 Z"],
                              eyes: [], color: Paint.colors[3])),
    ]

    static func quest(id: String) -> Quest? { all.first { $0.id == id } }
}

/// Picks the quest of the day: rolled once per local day, remembered, and never the same as yesterday's.
final class DailyQuestStore {
    static let defaultsKey = "dailyQuests"

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let roll: (Int) -> Int

    /// - Parameter roll: returns a number in `0..<upperBound`; truly random unless a test passes its own.
    init(defaults: UserDefaults = .standard, calendar: Calendar = .current,
         roll: @escaping (Int) -> Int = { upperBound in
             var generator = SystemRandomNumberGenerator()
             return Int.random(in: 0..<upperBound, using: &generator)
         }) {
        self.defaults = defaults
        self.calendar = calendar
        self.roll = roll
    }

    func quest(for date: Date) -> Quest {
        var rolled = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
        let today = key(for: date)
        if let id = rolled[today], let quest = QuestCatalog.quest(id: id) { return quest }

        let before = calendar.date(byAdding: .day, value: -1, to: date).map(key(for:))
        let yesterdaysID = before.flatMap { rolled[$0] }
        let pool = QuestCatalog.all.filter { $0.id != yesterdaysID }
        let quest = pool[min(max(roll(pool.count), 0), pool.count - 1)]

        rolled[today] = quest.id
        if let before { rolled = rolled.filter { $0.key >= before } }   // only yesterday still matters
        defaults.set(rolled, forKey: Self.defaultsKey)
        return quest
    }

    /// Local calendar day as `yyyy-MM-dd`, so it sorts as text.
    private func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

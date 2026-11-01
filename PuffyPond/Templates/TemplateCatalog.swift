import Foundation

extension TemplateChoice {
    /// The outline to trace: a template from the catalog, or the day's quest from its own pool.
    var art: OutlineArt? {
        isDailyQuest ? QuestCatalog.quest(id: templateID)?.art : TemplateCatalog.kind(id: templateID)?.art
    }
}

/// The templates in unlock order, and which of them a person can start from.
enum TemplateCatalog {
    /// Easy → hard. Each template opens once the one before it has a saved painting.
    static let ordered: [TemplateKind] = TemplateKind.allCases.sorted {
        ($0.difficulty, index(of: $0)) < ($1.difficulty, index(of: $1))
    }

    static func kind(id: String) -> TemplateKind? { TemplateKind(rawValue: id) }

    static func previous(of kind: TemplateKind) -> TemplateKind? {
        guard let i = ordered.firstIndex(of: kind), i > 0 else { return nil }
        return ordered[i - 1]
    }

    /// Derived from the saved paintings every time, so deleting a painting can lock a template again.
    /// - Parameter saved: ids of the templates that have at least one painting in the gallery.
    static func isUnlocked(_ kind: TemplateKind, saved: Set<String>) -> Bool {
        guard let before = previous(of: kind) else { return true }
        return saved.contains(before.id)
    }

    static func sections() -> [(difficulty: TemplateDifficulty, kinds: [TemplateKind])] {
        [TemplateDifficulty.easy, .medium, .hard].map { level in (level, ordered.filter { $0.difficulty == level }) }
    }

    private static func index(of kind: TemplateKind) -> Int { TemplateKind.allCases.firstIndex(of: kind) ?? 0 }
}

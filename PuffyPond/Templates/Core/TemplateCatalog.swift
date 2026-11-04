import Foundation

extension TemplateChoice {
    /// The outline to trace. The daily quest is one of the templates too, so both come from the catalog.
    var art: OutlineArt? { TemplateCatalog.design(id: templateID)?.art }

    /// What the painting was traced from, for page titles.
    var title: String? { TemplateCatalog.design(id: templateID)?.title }
}

/// Every template, easy → hard, all open from the start (no locks).
enum TemplateCatalog {
    /// The abstract shapes, the first ten pictures and the newer pictures, sorted by level (keeping that order
    /// within a level).
    static let all: [TemplateDesign] = {
        let shapes = TemplateKind.allCases.map {
            TemplateDesign(id: $0.id, title: $0.title, level: $0.level, art: $0.art)
        }
        let firstPictures = QuestCatalog.all.map {
            TemplateDesign(id: $0.id, title: $0.title, level: $0.level, art: $0.art)
        }
        let everything = shapes + firstPictures + TemplateDesign.pictures
        return everything.enumerated()
            .sorted { ($0.element.level, $0.offset) < ($1.element.level, $1.offset) }
            .map(\.element)
    }()

    private static let byID: [String: TemplateDesign] = Dictionary(all.map { ($0.id, $0) }) { first, _ in first }

    static func design(id: String) -> TemplateDesign? { byID[id] }

    /// The abstract shape with this id (its ids are stored with old paintings), if it is one.
    static func kind(id: String) -> TemplateKind? { TemplateKind(rawValue: id) }

    /// The levels that have templates, easy first.
    static var levels: [Int] { Array(Set(all.map(\.level))).sorted() }
}

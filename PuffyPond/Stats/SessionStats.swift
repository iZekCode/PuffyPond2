import Foundation

/// A person's left or right hand/arm, not a screen side (the front camera is mirrored).
enum Side: String, Codable, CaseIterable, CodingKeyRepresentable {
    case left, right
}

/// Movement stats of one drawing session, saved next to the painting.
struct SessionStats: Codable, Equatable {
    static let heatmapColumns = 32
    static let heatmapRows = 20

    /// Seconds spent on the canvas page.
    var duration: TimeInterval = 0
    /// Highest shoulder abduction reached per arm, in degrees.
    var romDegrees: [Side: Double] = [:]
    /// Time the drawing hands spent painting, per canvas cell (`heatmapColumns` × `heatmapRows`, row-major).
    var heatmap: [UInt16] = Array(repeating: 0, count: heatmapColumns * heatmapRows)
    /// Seconds each hand spent painting. Named after the original pinch; with the fist controls it counts fist time.
    var pinchSeconds: [Side: Double] = [:]
}

/// What is remembered about one saved painting: when, which template, and the session's movement stats.
struct PaintingRecord: Codable, Equatable {
    var date: Date
    var templateID: String?
    var isDailyQuest: Bool
    /// Nil for paintings made before stats existed and for paintings drawn by touch or mouse.
    var stats: SessionStats?

    init(date: Date, templateID: String? = nil, isDailyQuest: Bool = false, stats: SessionStats? = nil) {
        self.date = date
        self.templateID = templateID
        self.isDailyQuest = isDailyQuest
        self.stats = stats
    }
}

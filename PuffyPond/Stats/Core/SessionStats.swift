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
    /// Time the drawing hands spent painting, per canvas cell (`heatmapColumns` × `heatmapRows`, row-major,
    /// top-left first), in hundredths of a second.
    var heatmap: [UInt16] = Array(repeating: 0, count: heatmapColumns * heatmapRows)
    /// The same heatmap split per hand (empty for sessions saved before it existed).
    var sideHeatmaps: [Side: [UInt16]] = [:]
    /// Seconds each hand spent painting. Named after the original pinch; with the fist controls it counts fist time.
    var pinchSeconds: [Side: Double] = [:]
    /// Straightest elbow per arm, in degrees (180 = fully straight).
    var elbowExtension: [Side: Double] = [:]
    /// Highest wrist above its shoulder per arm, in shoulder widths (negative = never got above it).
    var reachHeight: [Side: Double] = [:]
    /// Area the wrist covered per arm (convex hull), in shoulder widths squared.
    var reachArea: [Side: Double] = [:]
    /// Fist → open cycles per hand.
    var gripCycles: [Side: Int] = [:]
    /// Biggest tilt of the shoulder line, in degrees (over 15 means leaning over to reach).
    var maxTrunkLean: Double = 0

    init() {}

    /// Stats saved before a metric existed decode with that metric empty.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        romDegrees = try c.decodeIfPresent([Side: Double].self, forKey: .romDegrees) ?? [:]
        heatmap = try c.decodeIfPresent([UInt16].self, forKey: .heatmap) ?? heatmap
        sideHeatmaps = try c.decodeIfPresent([Side: [UInt16]].self, forKey: .sideHeatmaps) ?? [:]
        pinchSeconds = try c.decodeIfPresent([Side: Double].self, forKey: .pinchSeconds) ?? [:]
        elbowExtension = try c.decodeIfPresent([Side: Double].self, forKey: .elbowExtension) ?? [:]
        reachHeight = try c.decodeIfPresent([Side: Double].self, forKey: .reachHeight) ?? [:]
        reachArea = try c.decodeIfPresent([Side: Double].self, forKey: .reachArea) ?? [:]
        gripCycles = try c.decodeIfPresent([Side: Int].self, forKey: .gripCycles) ?? [:]
        maxTrunkLean = try c.decodeIfPresent(Double.self, forKey: .maxTrunkLean) ?? 0
    }
}

/// What is remembered about one saved painting: when, which template, and the session's movement stats.
struct PaintingRecord: Codable, Equatable {
    var date: Date
    var templateID: String?
    var isDailyQuest: Bool
    /// Nil for paintings made before stats existed and for paintings drawn by touch or mouse.
    var stats: SessionStats?
    /// The format version of the stored timelapse; nil when the painting has none (older ones, or nothing recorded).
    var timelapseVersion: Int?

    init(date: Date, templateID: String? = nil, isDailyQuest: Bool = false, stats: SessionStats? = nil,
         timelapseVersion: Int? = nil) {
        self.date = date
        self.templateID = templateID
        self.isDailyQuest = isDailyQuest
        self.stats = stats
        self.timelapseVersion = timelapseVersion
    }
}

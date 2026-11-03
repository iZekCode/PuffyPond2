import Foundation

// MARK: - Saved paintings

struct Painting: Identifiable, Equatable {
    let url: URL
    let record: PaintingRecord
    var id: URL { url }
    var date: Date { record.date }

    /// The JSON file with the record, next to the PNG.
    var sidecarURL: URL { Self.sidecarURL(for: url) }

    /// The paint alone on a clear background (PNG bytes, kept out of the `.png` files the gallery lists).
    var paintURL: URL { url.deletingPathExtension().appendingPathExtension("paint") }
    /// What was painted, stroke by stroke.
    var timelapseURL: URL { url.deletingPathExtension().appendingPathExtension("timelapse") }

    static func sidecarURL(for png: URL) -> URL {
        png.deletingPathExtension().appendingPathExtension("json")
    }
}

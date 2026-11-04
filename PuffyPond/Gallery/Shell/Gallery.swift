import Foundation
import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// Finished paintings, kept as PNGs on the device (newest first), each with a JSON record beside it.
@Observable
final class Gallery {
    private(set) var paintings: [Painting] = []
    @ObservationIgnored private let folder: URL

    init(folder: URL? = nil) {
        if let folder {
            self.folder = folder
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.folder = base.appendingPathComponent("Gallery", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
        reload()
    }

    private func reload() {
        let keys: [URLResourceKey] = [.creationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
        paintings = files
            .filter { $0.pathExtension == "png" }
            .map { url in
                let sidecar = Painting.sidecarURL(for: url)
                if let data = try? Data(contentsOf: sidecar),
                   let record = try? JSONDecoder().decode(PaintingRecord.self, from: data) {
                    return Painting(url: url, record: record)
                }
                // A PNG from before records existed (or a broken sidecar): keep its date, write an empty record.
                let created = (try? url.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast
                let record = PaintingRecord(date: created)
                Self.write(record, to: sidecar)
                return Painting(url: url, record: record)
            }
            .sorted { $0.date > $1.date }
    }

    private static func write(_ record: PaintingRecord, to url: URL) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Hangs a new painting at the front of the gallery.
    @discardableResult
    func add(_ image: CGImage, record: PaintingRecord = PaintingRecord(date: Date())) -> Painting? {
        let url = folder.appendingPathComponent("painting-\(Int(record.date.timeIntervalSince1970 * 1000)).png")
        guard Self.writePNG(image, to: url) else { return nil }
        Self.write(record, to: Painting.sidecarURL(for: url))
        let painting = Painting(url: url, record: record)
        paintings.append(painting)
        paintings.sort { $0.date > $1.date }
        return painting
    }

    /// Hangs a finished painting with everything the review page needs to play with it again: the paint alone, the
    /// stroke-by-stroke timelapse (when something was recorded), and, once for all paintings, the bare canvas.
    @discardableResult
    func add(_ photos: CanvasPhotos, recording: StrokeRecording?, camera: CameraTimelapse? = nil,
             record: PaintingRecord = PaintingRecord(date: Date())) -> Painting? {
        var record = record
        let usable = recording.flatMap { $0.isEmpty ? nil : $0 }
        record.timelapseVersion = usable == nil ? nil : StrokeRecording.formatVersion
        guard let painting = add(photos.whole, record: record) else { return nil }
        _ = Self.writePNG(photos.paint, to: painting.paintURL)
        if let usable { try? usable.encoded().write(to: painting.timelapseURL, options: .atomic) }
        if let camera, !camera.isEmpty { try? camera.encoded().write(to: painting.cameraURL, options: .atomic) }
        let canvas = Self.bareCanvasURL(in: folder)
        if !FileManager.default.fileExists(atPath: canvas.path) { _ = Self.writePNG(photos.canvas, to: canvas) }
        return painting
    }

    private static func bareCanvasURL(in folder: URL) -> URL { folder.appendingPathComponent("canvas.bare") }

    private static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    /// What was painted, or nil when the painting has no recording or it cannot be read.
    nonisolated static func recording(of painting: Painting) -> StrokeRecording? {
        guard let data = try? Data(contentsOf: painting.timelapseURL) else { return nil }
        return StrokeRecording(data: data)
    }

    /// The child painting it, or nil when the painting has no camera timelapse.
    nonisolated static func cameraTimelapse(of painting: Painting) -> CameraTimelapse? {
        guard let data = try? Data(contentsOf: painting.cameraURL) else { return nil }
        return CameraTimelapse(data: data)
    }

    /// The painting's three photos for the review page, or nil when its image cannot be read. A painting made before
    /// the paint layer was kept comes back with the whole picture as its paint, over a plain white canvas.
    nonisolated static func photos(of painting: Painting) -> CanvasPhotos? {
        guard let whole = loadImage(at: painting.url) else { return nil }
        let paint = loadImage(at: painting.paintURL) ?? whole
        let canvas = loadImage(at: bareCanvasURL(in: painting.url.deletingLastPathComponent())) ?? plainCanvas(like: whole)
        return CanvasPhotos(whole: whole, canvas: canvas, paint: paint)
    }

    private nonisolated static func plainCanvas(like image: CGImage) -> CGImage {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()!
    }

    func remove(_ painting: Painting) {
        try? FileManager.default.removeItem(at: painting.url)
        try? FileManager.default.removeItem(at: painting.sidecarURL)
        try? FileManager.default.removeItem(at: painting.paintURL)
        try? FileManager.default.removeItem(at: painting.timelapseURL)
        try? FileManager.default.removeItem(at: painting.cameraURL)
        paintings.removeAll { $0 == painting }
    }

    // MARK: Queries

    /// Paintings made on the given local day, newest first.
    func paintings(on day: Date, calendar: Calendar = .current) -> [Painting] {
        paintings.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// The local days (as start-of-day dates) in the month of `month` that have at least one painting.
    func daysWithPaintings(in month: Date, calendar: Calendar = .current) -> Set<Date> {
        Set(paintings
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .map { calendar.startOfDay(for: $0.date) })
    }

    /// Ids of the templates that have at least one saved painting.
    var savedTemplateIDs: Set<String> {
        Set(paintings.compactMap(\.record.templateID))
    }

    /// Reads a saved PNG, scaled down to fit `maxPixels` on its long side when given. Safe off the main thread.
    nonisolated static func loadImage(at url: URL, maxPixels: Int? = nil) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let maxPixels else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func image(of painting: Painting) -> PlatformImage? {
        #if os(macOS)
        return NSImage(contentsOf: painting.url)
        #else
        return UIImage(contentsOfFile: painting.url.path)
        #endif
    }
}

extension PlatformImage {
    var cgImageValue: CGImage? {
        #if os(macOS)
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return cgImage
        #endif
    }
}

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PuffyPond

struct PaintingStoreTests {
    private func makeFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PaintingStoreTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeImage() -> CGImage {
        let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0.5, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return context.makeImage()!
    }

    private func writePNG(_ image: CGImage, to url: URL) {
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    private func sidecar(of painting: Painting) -> URL {
        painting.url.deletingPathExtension().appendingPathExtension("json")
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func legacyPngGetsEmptyRecord() throws {
        let folder = makeFolder()
        let png = folder.appendingPathComponent("painting-1000.png")
        writePNG(makeImage(), to: png)
        let made = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.creationDate: made], ofItemAtPath: png.path)

        let gallery = Gallery(folder: folder)

        #expect(gallery.paintings.count == 1)
        let painting = try #require(gallery.paintings.first)
        #expect(painting.record.templateID == nil)
        #expect(painting.record.isDailyQuest == false)
        #expect(painting.record.stats == nil)
        #expect(abs(painting.date.timeIntervalSince(made)) < 1)
        #expect(FileManager.default.fileExists(atPath: sidecar(of: painting).path))

        // Reloading reads the written sidecar and keeps the same record.
        let again = Gallery(folder: folder)
        #expect(again.paintings.first?.record == painting.record)
    }

    @Test func addWritesSidecar() throws {
        let folder = makeFolder()
        var stats = SessionStats()
        stats.duration = 42
        stats.romDegrees[.left] = 88.5
        stats.pinchSeconds[.right] = 12
        stats.heatmap[3] = 7
        let record = PaintingRecord(date: Date(timeIntervalSince1970: 1_700_000_000), templateID: "fish",
                                    isDailyQuest: true, stats: stats)

        let gallery = Gallery(folder: folder)
        let painting = try #require(gallery.add(makeImage(), record: record))

        #expect(FileManager.default.fileExists(atPath: painting.url.path))
        #expect(FileManager.default.fileExists(atPath: sidecar(of: painting).path))
        #expect(painting.url.lastPathComponent == "painting-1700000000000.png")
        #expect(sidecar(of: painting).lastPathComponent == "painting-1700000000000.json")
        #expect(gallery.paintings.first == painting)

        let reloaded = Gallery(folder: folder)
        let back = try #require(reloaded.paintings.first)
        #expect(back.record == record)
        #expect(back.record.stats?.heatmap.count == SessionStats.heatmapColumns * SessionStats.heatmapRows)
    }

    @Test func removeDeletesBoth() throws {
        let folder = makeFolder()
        let gallery = Gallery(folder: folder)
        let painting = try #require(gallery.add(makeImage(), record: PaintingRecord(date: Date())))

        gallery.remove(painting)

        #expect(gallery.paintings.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: painting.url.path))
        #expect(!FileManager.default.fileExists(atPath: sidecar(of: painting).path))
    }

    @Test func paintingsGroupByLocalDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Jakarta"))   // UTC+7
        let folder = makeFolder()
        let gallery = Gallery(folder: folder)

        // 23:30 and 00:30 local fall on different days, but 16:30 UTC and 17:30 UTC are one UTC day apart too;
        // 00:30 local on the 2nd is still the 1st in UTC, so a UTC grouping would merge these wrongly.
        let lateFirst = day(2026, 11, 1, hour: 23, calendar: calendar).addingTimeInterval(30 * 60)
        let earlySecond = day(2026, 11, 2, hour: 0, calendar: calendar).addingTimeInterval(30 * 60)
        let noonSecond = day(2026, 11, 2, calendar: calendar)
        let nextMonth = day(2026, 12, 5, calendar: calendar)
        for date in [lateFirst, earlySecond, noonSecond, nextMonth] {
            #expect(gallery.add(makeImage(), record: PaintingRecord(date: date)) != nil)
        }

        #expect(gallery.paintings(on: lateFirst, calendar: calendar).count == 1)
        #expect(gallery.paintings(on: noonSecond, calendar: calendar).count == 2)
        #expect(gallery.paintings(on: day(2026, 11, 3, calendar: calendar), calendar: calendar).isEmpty)

        let days = gallery.daysWithPaintings(in: noonSecond, calendar: calendar)
        #expect(days == [calendar.startOfDay(for: lateFirst), calendar.startOfDay(for: noonSecond)])
    }

    @Test func savedTemplateIDsCollectsTemplatesOnly() throws {
        let folder = makeFolder()
        let gallery = Gallery(folder: folder)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        gallery.add(makeImage(), record: PaintingRecord(date: base, templateID: "fish"))
        gallery.add(makeImage(), record: PaintingRecord(date: base + 1, templateID: "fish"))
        gallery.add(makeImage(), record: PaintingRecord(date: base + 2, templateID: "duck"))
        gallery.add(makeImage(), record: PaintingRecord(date: base + 3, templateID: nil))

        #expect(gallery.savedTemplateIDs == ["fish", "duck"])
    }

    // MARK: Timelapse files

    private func image(side: Int) -> CGImage {
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0, green: 0.5, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()!
    }

    private func photos() -> CanvasPhotos {
        CanvasPhotos(whole: image(side: 4), canvas: image(side: 5), paint: image(side: 6))
    }

    private func recording() -> StrokeRecording {
        let dab = RecordedDab(t: 0, from: .zero, to: SIMD2(1, 1), radius: 0.1, speed: 1, color: SIMD3(1, 0, 0), seed: 1,
                              strokeSeed: 1, style: .brush, drag: nil, ncaModel: 0, brush: .butterfly)
        var later = dab
        later.t = 2
        return StrokeRecording(events: [.dab(dab), .dab(later)])
    }

    private let stamp = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func addStoresPaintLayerAndRecording() throws {
        let gallery = Gallery(folder: makeFolder())
        let saved = recording()
        let painting = try #require(gallery.add(photos(), recording: saved, record: PaintingRecord(date: stamp)))

        let back = try #require(Gallery.photos(of: painting))
        #expect(back.whole.width == 4)
        #expect(back.canvas.width == 5)
        #expect(back.paint.width == 6)
        #expect(Gallery.recording(of: painting) == saved)
        #expect(painting.record.timelapseVersion == StrokeRecording.formatVersion)
    }

    @Test func extraFilesAreNotPaintings() throws {
        let folder = makeFolder()
        _ = Gallery(folder: folder).add(photos(), recording: recording(), record: PaintingRecord(date: stamp))

        #expect(Gallery(folder: folder).paintings.count == 1)
    }

    @Test func removeDeletesTheExtrasButKeepsTheSharedCanvas() throws {
        let folder = makeFolder()
        let gallery = Gallery(folder: folder)
        let painting = try #require(gallery.add(photos(), recording: recording(), record: PaintingRecord(date: stamp)))

        gallery.remove(painting)

        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(left == ["canvas.bare"])
    }

    @Test func canvasIsStoredOnce() throws {
        let folder = makeFolder()
        let gallery = Gallery(folder: folder)
        gallery.add(photos(), recording: nil, record: PaintingRecord(date: stamp))
        gallery.add(photos(), recording: nil, record: PaintingRecord(date: stamp + 5))

        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(files.filter { $0 == "canvas.bare" }.count == 1)
        #expect(files.filter { $0.hasSuffix(".paint") }.count == 2)
    }

    @Test func emptyRecordingStoresNone() throws {
        let gallery = Gallery(folder: makeFolder())
        for (offset, saved) in [nil, StrokeRecording()].enumerated() {
            let painting = try #require(gallery.add(photos(), recording: saved,
                                                    record: PaintingRecord(date: stamp + Double(offset))))
            #expect(painting.record.timelapseVersion == nil)
            #expect(!FileManager.default.fileExists(atPath: painting.timelapseURL.path))
            #expect(Gallery.recording(of: painting) == nil)
            #expect(Gallery.photos(of: painting) != nil)
        }
    }

    @Test func oldRecordsStillDecode() throws {
        let json = Data(#"{"date": 700000000, "isDailyQuest": false}"#.utf8)
        let record = try JSONDecoder().decode(PaintingRecord.self, from: json)
        #expect(record.timelapseVersion == nil)
    }

    @Test func legacyPaintingHasNoRecording() throws {
        let folder = makeFolder()
        writePNG(makeImage(), to: folder.appendingPathComponent("painting-1000.png"))
        let painting = try #require(Gallery(folder: folder).paintings.first)

        #expect(Gallery.recording(of: painting) == nil)
        let back = try #require(Gallery.photos(of: painting))
        #expect(back.paint.width == 4)
        #expect(back.canvas.width == 4)
    }

    @Test func corruptRecordingIsIgnored() throws {
        let gallery = Gallery(folder: makeFolder())
        let painting = try #require(gallery.add(photos(), recording: recording(), record: PaintingRecord(date: stamp)))
        try Data(repeating: 0xAB, count: 300).write(to: painting.timelapseURL)

        #expect(Gallery.recording(of: painting) == nil)
    }
}

import SwiftUI

/// A saved painting opened from a gallery: its timelapse when it has one, then the sheet to play with. It reads the
/// painting's files off the main thread and shows the same page as right after "Save image".
struct PaintingViewerPage: View {
    let painting: Painting
    let origin: ViewOrigin
    let router: AppRouter
    let audio: GrooveEngine
    let relay: HandFrameRelay
    @State private var loaded: Loaded?

    private struct Loaded: @unchecked Sendable {
        let photos: CanvasPhotos
        let recording: StrokeRecording?
        let camera: CameraTimelapse?
    }

    var body: some View {
        ZStack {
            if let loaded {
                ReviewView(photos: loaded.photos, recording: loaded.recording, title: title, date: painting.date,
                           mode: .viewing, audio: audio, relay: relay, keepDrawing: {}, save: {},
                           back: { router.go(origin.route) }, camera: loaded.camera)
            } else {
                PageBackground()
                ProgressView()
            }
        }
        .task(id: painting.url) {
            let painting = painting
            let result = await Task.detached(priority: .userInitiated) { () -> Loaded? in
                guard let photos = Gallery.photos(of: painting) else { return nil }
                return Loaded(photos: photos, recording: Gallery.recording(of: painting),
                              camera: Gallery.cameraTimelapse(of: painting))
            }.value
            if let result {
                loaded = result
            } else {
                router.go(origin.route)
            }
        }
    }

    private var title: String {
        guard let id = painting.record.templateID else { return "Bebas" }
        return TemplateChoice(templateID: id, isDailyQuest: painting.record.isDailyQuest).title ?? "Bebas"
    }
}

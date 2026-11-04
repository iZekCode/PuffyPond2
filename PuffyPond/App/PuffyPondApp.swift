import SwiftUI

@main
struct PuffyPondApp: App {
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 460)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}

struct ContentView: View {
    @State private var router = AppRouter()
    @State private var playground = Playground()
    @State private var tracker = HandTracker()
    @State private var gallery = Gallery()
    @State private var pageHands = HandFrameRelay()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let onCanvas = router.route.isCanvas
        ZStack {
            // The easel stays alive under every page so SceneKit isn't rebuilt; it only shows on the canvas.
            PlaygroundView(playground: playground)
                .ignoresSafeArea()
                .opacity(onCanvas ? 1 : 0)
                .allowsHitTesting(onCanvas)
            if onCanvas {
                HUDView(playground: playground, previewLayer: tracker.previewLayer, saveImage: saveImage, goHome: router.home)
                    .transition(.opacity)
            }
            page
        }
        .immersive()
        .environment(\.uiScale, Platform.isPad ? 1.2 : 1)
        .onChange(of: onCanvas, initial: true) { _, canvas in
            playground.isAway = !canvas
            watchBody(canvas)
        }
        .onChange(of: router.route) { old, new in
            // Coming from the distance check is a new session; coming back from the review page is not.
            if case .canvas(let choice) = new, case .instruction = old { playground.begin(choice) }
        }
        .onAppear {
            Platform.keepAwake()
            playground.start()
            startTracking()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                playground.start()
                startTracking()
            case .background:
                tracker.stop()
                playground.pause()
            default:
                break
            }
        }
    }

    @ViewBuilder private var page: some View {
        switch router.route {
        case .canvas:
            EmptyView()
        case .home:
            HomeView(router: router).transition(.opacity)
        case let .gallery3D(start, justHung):
            GalleryView(gallery: gallery, relay: pageHands, startAt: start, justHung: justHung,
                        home: router.home, show2D: { router.go(.gallery2D) },
                        startDrawing: { router.go(.modePicker) },
                        watch: { painting in
                            let index = gallery.paintings.firstIndex(of: painting) ?? start
                            router.go(.viewPainting(painting, origin: .gallery3D(index: index)))
                        })
                .id(start)
                .transition(.opacity)
        case .modePicker:
            ModePickerView(router: router).transition(.opacity)
        case .templates:
            TemplatesView(router: router, gallery: gallery).transition(.opacity)
        case let .instruction(choice):
            InstructionView(router: router, tracker: tracker, cameraStatus: playground.cameraStatus, choice: choice)
                .transition(.opacity)
        case let .review(draft):
            ReviewView(photos: draft.photos, recording: draft.recording, title: draft.choice?.title ?? "Bebas",
                       date: Date(), mode: .fresh, audio: playground.audio, relay: pageHands,
                       keepDrawing: { router.go(.canvas(draft.choice)) }, save: { save(draft) }, back: {})
                .id(draft.id)
                .transition(.opacity)
        case let .viewPainting(painting, origin):
            PaintingViewerPage(painting: painting, origin: origin, router: router, audio: playground.audio,
                               relay: pageHands)
                .id(painting.id)
                .transition(.opacity)
        case .gallery2D:
            Gallery2DView(gallery: gallery, router: router).transition(.opacity)
        case .report:
            ReportView(gallery: gallery, router: router).transition(.opacity)
        }
    }

    /// Photographs the painting off the easel and takes it to the review page.
    private func saveImage() {
        guard case .canvas(let choice) = router.route, let photo = playground.finishPainting() else { return }
        router.go(.review(ReviewDraft(photos: photo, choice: choice, stats: playground.sessionStats(),
                                        recording: playground.timelapseRecording())))
    }

    /// Hangs the reviewed painting, with its template and movement stats, and walks over to see it.
    private func save(_ draft: ReviewDraft) {
        let record = PaintingRecord(date: Date(), templateID: draft.choice?.templateID,
                                    isDailyQuest: draft.choice?.isDailyQuest ?? false, stats: draft.stats)
        guard gallery.add(draft.photos, recording: draft.recording, record: record) != nil else { return }
        playground.clearCanvas()
        router.go(.gallery3D(start: 0, justHung: true))
    }

    /// Body pose runs on the canvas for the range-of-motion stats, and stops when the canvas closes
    /// (the distance check page switches it on for itself).
    private func watchBody(_ canvas: Bool) {
        if canvas {
            let playground = playground
            tracker.onBody = { frame in playground.ingest(frame) }
            tracker.bodyPoseEnabled = true
        } else if case .instruction = router.route {
            return
        } else {
            tracker.bodyPoseEnabled = false
            tracker.onBody = nil
        }
    }

    private func startTracking() {
        let playground = playground
        let pageHands = pageHands
        tracker.onFrame = { frame in
            playground.ingest(frame)
            pageHands.send(frame)
        }
        tracker.start { status in
            switch status {
            case .running: playground.cameraStatus = .running
            case .denied: playground.cameraStatus = .denied
            case .unavailable: playground.cameraStatus = .unavailable
            }
        }
    }
}

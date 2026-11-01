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
                HUDView(playground: playground, session: tracker.session,
                        paintingCount: gallery.paintings.count, finish: hangPainting,
                        openGallery: { router.go(.gallery3D(start: 0, justHung: false)) },
                        goHome: router.home)
                    .transition(.opacity)
            }
            page
        }
        .immersive()
        .environment(\.uiScale, Platform.isPad ? 1.2 : 1)
        .onChange(of: onCanvas, initial: true) { _, canvas in playground.isAway = !canvas }
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
            GalleryView(gallery: gallery, startAt: start, justHung: justHung, close: router.home)
                .id(start)
                .transition(.opacity)
        case .modePicker:
            ModePickerView(router: router).transition(.opacity)
        case .templates:
            TemplatesView(router: router, gallery: gallery).transition(.opacity)
        case let .instruction(choice):
            // The distance check arrives with the instruction page; until then go straight on.
            PlaceholderPage(title: "Get ready", router: router, next: ("Start", .canvas(choice)))
                .transition(.opacity)
        case .review:
            PlaceholderPage(title: "Review", router: router).transition(.opacity)
        case .gallery2D:
            PlaceholderPage(title: "Gallery", router: router).transition(.opacity)
        case .report:
            PlaceholderPage(title: "Report", router: router).transition(.opacity)
        }
    }

    /// Photographs the painting off the easel and walks over to see it hanging in the gallery.
    private func hangPainting() {
        guard let photo = playground.finishPainting(), gallery.add(photo) != nil else { return }
        router.go(.gallery3D(start: 0, justHung: true))
    }

    private func startTracking() {
        let playground = playground
        tracker.onFrame = { frame in playground.ingest(frame) }
        tracker.start { status in
            switch status {
            case .running: playground.cameraStatus = .running
            case .denied: playground.cameraStatus = .denied
            case .unavailable: playground.cameraStatus = .unavailable
            }
        }
    }
}

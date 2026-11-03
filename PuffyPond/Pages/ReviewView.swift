import SceneKit
import SwiftUI

/// Whether the page is the one right after "Save image" or a painting opened from the gallery.
enum ReviewMode {
    case fresh
    case viewing
}

/// A painting's timelapse, then the paint on a wet, elastic sheet over the still canvas to push and grab. After
/// "Save image" it ends with hanging the painting in the gallery or going back to the easel; opened from the gallery
/// it ends with going back. The play never touches the saved image, which is always the undeformed photo.
struct ReviewView: View {
    let photos: CanvasPhotos
    let recording: StrokeRecording?
    let title: String
    let date: Date
    let mode: ReviewMode
    let audio: GrooveEngine
    let relay: HandFrameRelay
    let keepDrawing: () -> Void
    let save: () -> Void
    let back: () -> Void
    @State private var stage = ReviewStage()
    @State private var frames: [String: CGRect] = [:]
    @State private var leaving = false
    @Environment(\.uiScale) private var scale

    private static let space = "review"
    private static let keepID = "keep"
    private static let saveID = "save"
    private static let replayID = "replay"
    private static let skipID = "skip"
    private static let backID = "back"

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SceneView(scene: stage.scene, pointOfView: stage.cameraNode, options: [.rendersContinuously],
                          antialiasingMode: .multisampling4X)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                        .onChanged { drag in stage.pointer = uv(drag.location, in: proxy.size) }
                        .onEnded { _ in stage.pointer = nil })

                VStack {
                    titleBadge
                    Spacer()
                    HStack(spacing: 20 * scale) { buttons }
                    hint
                }
                .padding(20 * scale)

                ForEach(stage.cursors) { cursor in
                    HandCursor(fist: cursor.fist)
                        .position(x: CGFloat(cursor.position.x) * proxy.size.width,
                                  y: CGFloat(cursor.position.y) * proxy.size.height)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(.named(Self.space))
            .onAppear {
                stage.layout(size: proxy.size)
                updateTargets(size: proxy.size)
            }
            .onChange(of: proxy.size) { _, size in
                stage.layout(size: size)
                updateTargets(size: size)
            }
            .onChange(of: frames) { _, _ in updateTargets(size: proxy.size) }
        }
        .ignoresSafeArea()
        .onAppear {
            audio.setTune(.silly)
            stage.show(photos, recording: recording, audio: audio)
            stage.onPress = { id in
                switch id {
                case Self.skipID: stage.skipTimelapse()
                case Self.replayID: stage.replay()
                case Self.saveID: leave(save)
                case Self.backID: leave(back)
                default: leave(keepDrawing)
                }
            }
            let stage = stage
            relay.listener = { frame in stage.ingest(frame) }
            stage.start()
        }
        .onDisappear {
            audio.setTune(.groove)
            relay.listener = nil
            stage.stop()
        }
    }

    @ViewBuilder private var buttons: some View {
        if stage.phase == .timelapse {
            button(Self.skipID, "Skip", "forward.fill", .teal) { stage.skipTimelapse() }
        } else {
            if stage.canReplay {
                button(Self.replayID, "Replay", "arrow.counterclockwise", .purple) { stage.replay() }
            }
            switch mode {
            case .fresh:
                button(Self.keepID, "Keep drawing", "paintbrush.pointed.fill", .orange) { leave(keepDrawing) }
                button(Self.saveID, "Save to gallery", "building.columns.fill", .pink) { leave(save) }
            case .viewing:
                button(Self.backID, "Back", "chevron.left", .blue) { leave(back) }
            }
        }
    }

    /// A button a tap presses, or a hand holds still on; it only takes hand hovers while it is on the page.
    private func button(_ id: String, _ title: String, _ symbol: String, _ tint: Color,
                        action: @escaping () -> Void) -> some View {
        DwellButton(title: title, symbol: symbol, tint: tint, progress: progress(id), action: action)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[id] = $0 }
            .onDisappear { frames[id] = nil }
    }

    private var titleBadge: some View {
        VStack(spacing: 4 * scale) {
            Text(title)
                .font(.system(size: 26 * scale, weight: .black, design: .rounded))
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22 * scale)
        .padding(.vertical, 10 * scale)
        .background(.white.opacity(0.85), in: Capsule())
        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
    }

    private var hint: some View {
        Text(stage.phase == .timelapse
             ? "Watch your painting come to life · hold an open hand on Skip to jump ahead"
             : "Fist to grab · two fists to stretch · open hand to splash · hold an open hand on a button")
            .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35).opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.top, 6 * scale)
    }

    /// A tap and a hover-and-hold can land together; only the first one counts.
    private func leave(_ action: () -> Void) {
        guard !leaving else { return }
        leaving = true
        audio.play(.honk)
        action()
    }

    private func progress(_ id: String) -> Double {
        guard let dwell = stage.dwell, dwell.id == id else { return 0 }
        return dwell.progress
    }

    private func uv(_ point: CGPoint, in size: CGSize) -> SIMD2<Float> {
        SIMD2(Float(point.x / max(size.width, 1)), Float(point.y / max(size.height, 1)))
    }

    /// Button frames in view UV, so camera hands can hover over them.
    private func updateTargets(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        stage.targets = frames.map { id, frame in
            ReviewStage.HoverTarget(id: id, frame: CGRect(x: frame.minX / size.width, y: frame.minY / size.height,
                                                          width: frame.width / size.width,
                                                          height: frame.height / size.height))
        }
    }
}

extension TemplateChoice {
    /// What the painting was traced from, for page titles.
    var title: String? {
        isDailyQuest ? QuestCatalog.quest(id: templateID)?.title : TemplateCatalog.kind(id: templateID)?.title
    }
}

/// A `HomeButton` that also fills a ring while an open hand rests on it.
private struct DwellButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let progress: Double
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        HomeButton(title: title, symbol: symbol, tint: tint, action: action)
            .overlay(alignment: .trailing) {
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 6 * scale, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40 * scale, height: 40 * scale)
                        .padding(.trailing, 22 * scale)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(1 + 0.05 * progress)
    }
}

/// Where a camera hand is: an open hand or a fist in a soft bubble.
struct HandCursor: View {
    let fist: Bool
    @Environment(\.uiScale) private var scale

    var body: some View {
        Text(fist ? "✊" : "🖐️")
            .font(.system(size: 28 * scale))
            .frame(width: 56 * scale, height: 56 * scale)
            .background((fist ? Color.pink : Color.blue).opacity(0.75).gradient, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            .scaleEffect(fist ? 0.85 : 1)
            .animation(.spring(duration: 0.2), value: fist)
    }
}

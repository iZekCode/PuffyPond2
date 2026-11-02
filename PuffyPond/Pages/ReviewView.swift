import SceneKit
import SwiftUI

/// After "Save image": the paint on a wet, elastic sheet over the still canvas to push and grab, then hang
/// it in the gallery or go back to the easel. The play never touches the saved image, which is always the
/// undeformed photo.
struct ReviewView: View {
    let draft: ReviewDraft
    let audio: GrooveEngine
    let relay: HandFrameRelay
    let keepDrawing: () -> Void
    let save: () -> Void
    @State private var stage = ReviewStage()
    @State private var date = Date()
    @State private var frames: [String: CGRect] = [:]
    @State private var leaving = false
    @Environment(\.uiScale) private var scale

    private static let space = "review"
    private static let keepID = "keep"
    private static let saveID = "save"

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SceneView(scene: stage.scene, pointOfView: stage.cameraNode, options: [.rendersContinuously],
                          antialiasingMode: .multisampling4X)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                        .onChanged { drag in stage.pointer = uv(drag.location, in: proxy.size) }
                        .onEnded { _ in stage.pointer = nil })

                VStack {
                    title
                    Spacer()
                    HStack(spacing: 20 * scale) {
                        DwellButton(title: "Keep drawing", symbol: "paintbrush.pointed.fill", tint: .orange,
                                    progress: progress(Self.keepID)) { leave(keepDrawing) }
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                                frames[Self.keepID] = $0
                            }
                        DwellButton(title: "Save to gallery", symbol: "building.columns.fill", tint: .pink,
                                    progress: progress(Self.saveID)) { leave(save) }
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                                frames[Self.saveID] = $0
                            }
                    }
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
            stage.show(draft.photos, audio: audio)
            stage.onPress = { id in leave(id == Self.saveID ? save : keepDrawing) }
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

    private var title: some View {
        VStack(spacing: 4 * scale) {
            Text(draft.choice?.title ?? "Freeform")
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
        Text("Fist to grab · two fists to stretch · open hand to splash · hold an open hand on a button")
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

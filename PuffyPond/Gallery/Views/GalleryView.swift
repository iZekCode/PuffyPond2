import SceneKit
import SwiftUI
import simd

// MARK: - Gallery screen

struct GalleryView: View {
    let gallery: Gallery
    let relay: HandFrameRelay
    let home: () -> Void
    let show2D: () -> Void
    let startDrawing: () -> Void
    let watch: (Painting) -> Void
    @State private var index: Int
    @State private var hall = GalleryHall()
    @State private var confirmingRemoval = false
    @State private var viewSize = CGSize.zero
    @State private var watchFrame = CGRect.zero
    @Environment(\.uiScale) private var scale
    private let cheerOnOpen: Bool

    init(gallery: Gallery, relay: HandFrameRelay, startAt index: Int = 0, justHung: Bool = false,
         home: @escaping () -> Void, show2D: @escaping () -> Void, startDrawing: @escaping () -> Void,
         watch: @escaping (Painting) -> Void) {
        self.gallery = gallery
        self.relay = relay
        self.home = home
        self.show2D = show2D
        self.startDrawing = startDrawing
        self.watch = watch
        _index = State(initialValue: index)
        cheerOnOpen = justHung
    }

    private var current: Painting? {
        gallery.paintings.indices.contains(index) ? gallery.paintings[index] : nil
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack {
                    SceneView(scene: hall.scene, pointOfView: hall.cameraNode, options: [.rendersContinuously],
                              antialiasingMode: .multisampling4X)
                    // Small hand markers, so the person sees the camera has their hands.
                    ForEach(hall.cursors) { cursor in
                        HandCursor(fist: cursor.fist)
                            .scaleEffect(0.6)
                            .opacity(0.8)
                            .position(x: CGFloat(cursor.position.x) * proxy.size.width,
                                      y: CGFloat(cursor.position.y) * proxy.size.height)
                    }
                    .allowsHitTesting(false)
                    // The ring a held fist fills over the painting.
                    if let progress = hall.fistProgress {
                        HoldRing(progress: progress)
                            .scaleEffect(1.8)
                            .position(x: hall.paintingFrame.midX * proxy.size.width,
                                      y: hall.paintingFrame.midY * proxy.size.height)
                    }
                }
                .onAppear { hall.layout(size: proxy.size) }
                .onChange(of: proxy.size) { _, size in hall.layout(size: size) }
            }
            .ignoresSafeArea()
            .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
                if drag.translation.width < -60 { step(1) } else if drag.translation.width > 60 { step(-1) }
            })

            VStack {
                HStack(alignment: .top) {
                    RoundButton(symbol: "house.fill", tint: .blue, action: home)
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Puffy Pond Gallery")
                            .font(.system(size: 26 * scale, weight: .black, design: .rounded))
                        if let current {
                            Text("\(current.date.formatted(.dateTime.month(.wide).day().hour().minute()))"
                                 + (gallery.paintings.count > 1 ? " · \(index + 1) of \(gallery.paintings.count)" : ""))
                                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.85), in: Capsule())
                    .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
                    Spacer()
                    RoundButton(symbol: "trash.fill", tint: .red) { confirmingRemoval = true }
                        .opacity(current == nil ? 0 : 1)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    PillButton(title: "View gallery in 2D", symbol: "square.grid.2x2.fill", tint: .orange,
                               action: show2D)
                    Spacer()
                    if gallery.paintings.count > 1 {
                        SwipeHint()
                    }
                    Spacer()
                    PillButton(title: "Watch it being painted", symbol: "play.fill", tint: .pink) {
                        if let current { watch(current) }
                    }
                    .overlay(alignment: .trailing) {
                        if let ring = hall.dwell, ring.id == Self.watchID {
                            HoldRing(progress: ring.progress).padding(.trailing, 10)
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                        watchFrame = $0
                        updateTargets()
                    }
                    .opacity(current == nil ? 0 : 1)
                    .disabled(current == nil)
                }
            }
            .padding(16 * scale)

            // Page buttons sit at the middle of the two sides, where thumbs rest on a wide screen.
            HStack {
                RoundButton(symbol: "chevron.left", tint: .indigo) { step(-1) }
                    .opacity(index > 0 ? 1 : 0)
                Spacer()
                RoundButton(symbol: "chevron.right", tint: .indigo) { step(1) }
                    .opacity(index < gallery.paintings.count - 1 ? 1 : 0)
            }
            .padding(.horizontal, 16 * scale)

            if gallery.paintings.isEmpty {
                VStack(spacing: 20 * scale) {
                    Text("No paintings yet")
                        .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
                    HomeButton(title: "Start drawing", symbol: "paintbrush.pointed.fill", tint: .pink,
                               action: startDrawing)
                }
                .padding(32 * scale)
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 36 * scale, style: .continuous))
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self) { $0.size } action: {
            viewSize = $0
            updateTargets()
        }
        .onChange(of: index) { _, _ in updateTargets() }
        .confirmationDialog("Take this painting down?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Take it down", role: .destructive, action: removeCurrent)
        }
        .onAppear {
            hall.hang(gallery.paintings.map(\.url))
            hall.focus(index, animated: false)
            if cheerOnOpen { hall.cheer() }
            hall.onSwipe = { swipe in step(swipe == .next ? 1 : -1) }
            hall.onPress = { id in
                if id == Self.watchID || id == GalleryHall.paintingID, let current { watch(current) }
            }
            updateTargets()
            let hall = hall
            relay.listen(owner: hall) { frame in hall.ingest(frame) }
            hall.start()
        }
        .onDisappear {
            relay.stopListening(owner: hall)
            hall.onSwipe = nil
            hall.onPress = nil
            hall.stop()
        }
    }

    private static let watchID = "watch"
    private static let space = "gallery"

    /// The Watch button in view UV, so a camera hand can hold on it.
    private func updateTargets() {
        guard current != nil, viewSize.width > 0, viewSize.height > 0, !watchFrame.isEmpty else {
            hall.targets = []
            return
        }
        hall.targets = [HoverTarget(id: Self.watchID,
                                    frame: CGRect(x: watchFrame.minX / viewSize.width, y: watchFrame.minY / viewSize.height,
                                                  width: watchFrame.width / viewSize.width,
                                                  height: watchFrame.height / viewSize.height))]
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard gallery.paintings.indices.contains(next) else { return }
        index = next
        hall.focus(index)
    }

    private func removeCurrent() {
        guard let current else { return }
        gallery.remove(current)
        index = min(index, max(gallery.paintings.count - 1, 0))
        hall.hang(gallery.paintings.map(\.url))
        hall.focus(index, animated: false)
        updateTargets()
    }
}

/// A rounded pill with an icon and a label, smaller than the home page's buttons.
struct PillButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 17 * scale, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18 * scale)
                .frame(minHeight: 50 * scale)
                .background(tint.gradient, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 3))
                .shadow(color: tint.opacity(0.4), radius: 8, y: 4)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Shows how to use the hands: swipe an open palm to walk, hold a fist on the painting to watch it.
private struct SwipeHint: View {
    @Environment(\.uiScale) private var scale
    @State private var swiped = false

    var body: some View {
        HStack(spacing: 10 * scale) {
            Text("🖐️")
                .font(.system(size: 24 * scale))
                .offset(x: swiped ? -10 * scale : 10 * scale)
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text("Swipe your palm left to walk on, right to go back")
                Text("Hold a fist on the painting to watch it being painted")
            }
            .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
        }
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 10 * scale)
        .background(.white.opacity(0.85), in: Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { swiped = true }
        }
    }
}

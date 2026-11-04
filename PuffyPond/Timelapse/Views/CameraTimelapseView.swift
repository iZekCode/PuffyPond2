import ImageIO
import SwiftUI

/// Plays a camera timelapse on a loop: the child painting, sped up.
struct CameraTimelapseView: View {
    let timelapse: CameraTimelapse
    @State private var images: [CGImage] = []
    @State private var start = Date()

    var body: some View {
        TimelineView(.periodic(from: start, by: 1 / CameraTimelapse.framesPerSecond)) { context in
            let index = images.isEmpty ? 0
                : Int(context.date.timeIntervalSince(start) * CameraTimelapse.framesPerSecond) % images.count
            ZStack {
                Color.black
                if index < images.count {
                    Image(decorative: images[index], scale: 1).resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .task(id: timelapse.frames.count) {
            let frames = timelapse.frames
            images = await Task.detached(priority: .userInitiated) { frames.compactMap(Self.decode) }.value
            start = Date()
        }
    }

    nonisolated private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

/// A small window in the corner of the review page with the camera timelapse; tap it to watch it big.
struct CameraTimelapseBadge: View {
    let timelapse: CameraTimelapse
    @State private var expanded = false
    @Environment(\.uiScale) private var scale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
        Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded = true } } label: {
            VStack(spacing: 6 * scale) {
                CameraTimelapseView(timelapse: timelapse)
                    .frame(width: 200 * scale, height: 150 * scale)
                    .clipShape(shape)
                    .overlay(shape.stroke(.white, lineWidth: 3))
                Label("Timelapse kamera", systemImage: "video.fill")
                    .font(.system(size: 13 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
            }
            .padding(8 * scale)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24 * scale, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresentedCompat: $expanded) {
            ZStack(alignment: .topTrailing) {
                CameraTimelapseView(timelapse: timelapse).ignoresSafeArea()
                RoundButton(symbol: "xmark", tint: .pink) { expanded = false }
                    .padding(24 * scale)
            }
        }
    }
}

private extension View {
    /// Full screen on iPhone and iPad; a sheet on the Mac (which has no full-screen cover).
    @ViewBuilder
    func fullScreenCover<Content: View>(isPresentedCompat: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresentedCompat, content: content)
        #else
        sheet(isPresented: isPresentedCompat) { content().frame(minWidth: 800, minHeight: 600) }
        #endif
    }
}

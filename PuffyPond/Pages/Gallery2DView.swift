import SwiftUI

/// Every saved painting as a flat grid of thumbnails, newest first, grouped by the day it was made.
/// Tapping one walks to it in the 3D gallery.
struct Gallery2DView: View {
    let gallery: Gallery
    let router: AppRouter
    @Environment(\.uiScale) private var scale

    private struct Day: Identifiable {
        let date: Date
        /// Paintings with their index in `gallery.paintings` (the 3D gallery's order).
        let paintings: [(index: Int, painting: Painting)]
        var id: Date { date }
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let indexed = gallery.paintings.enumerated().map { (index: $0.offset, painting: $0.element) }
        let grouped = Dictionary(grouping: indexed) { calendar.startOfDay(for: $0.painting.date) }
        return grouped.map { Day(date: $0.key, paintings: $0.value.sorted { $0.index < $1.index }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 12 * scale) {
                HStack {
                    RoundButton(symbol: "house.fill", tint: .blue, action: router.home)
                    Spacer()
                    Text("Gallery")
                        .font(.system(size: 30 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(PageBackground.titleGradient)
                    Spacer()
                    PillButton(title: "3D", symbol: "building.columns.fill", tint: .orange) {
                        router.go(.gallery3D(start: 0, justHung: false))
                    }
                }
                if gallery.paintings.isEmpty {
                    Spacer()
                    Text("No paintings yet")
                        .font(.system(size: 30 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
                    HomeButton(title: "Start drawing", symbol: "paintbrush.pointed.fill", tint: .pink) {
                        router.go(.modePicker)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20 * scale) {
                            ForEach(days) { day in
                                Text(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                                    .font(.system(size: 18 * scale, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200 * scale), spacing: 14 * scale)],
                                          spacing: 14 * scale) {
                                    ForEach(day.paintings, id: \.painting.id) { item in
                                        Button {
                                            router.go(.gallery3D(start: item.index, justHung: false))
                                        } label: {
                                            Thumbnail(painting: item.painting)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 24 * scale)
                    }
                }
            }
            .padding(16 * scale)
        }
    }
}

/// One painting, loaded small in the background, in a white frame with its time underneath.
private struct Thumbnail: View {
    let painting: Painting
    @State private var image: CGImage?
    @Environment(\.uiScale) private var scale

    var body: some View {
        VStack(spacing: 6 * scale) {
            ZStack {
                Color.white
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                }
            }
            .aspectRatio(CGFloat(Playground.canvasSize.x / Playground.canvasSize.y), contentMode: .fit)
            .padding(6 * scale)
            .background(.white, in: RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            Text(painting.date.formatted(.dateTime.hour().minute()))
                .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .task(id: painting.url) {
            let url = painting.url
            image = await Task.detached(priority: .utility) { Gallery.loadImage(at: url, maxPixels: 400) }.value
        }
    }
}

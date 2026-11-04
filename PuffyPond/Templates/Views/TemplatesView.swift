import SwiftUI

/// The daily quest on top (any template, picked at random for the day), then every template by level, easy first.
/// All of them are open. The tiles show the picture big; the name is only a small caption.
struct TemplatesView: View {
    let router: AppRouter
    let gallery: Gallery
    @State private var quest = DailyQuestStore().quest(for: Date())
    @State private var icons: [String: CGImage] = TemplatesView.makeIcons()
    @Environment(\.uiScale) private var scale

    var body: some View {
        let questDone = gallery.paintings(on: Date()).contains { $0.record.isDailyQuest }
        ZStack {
            PageBackground()
            VStack(spacing: 16 * scale) {
                HStack {
                    Button { router.go(.modePicker) } label: {
                        Label("Kembali", systemImage: "chevron.left")
                            .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.indigo)
                    Spacer()
                    Text("Templat")
                        .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(PageBackground.titleGradient)
                    Spacer()
                    Button { router.home() } label: {
                        Label("Beranda", systemImage: "house.fill")
                            .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.indigo)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 22 * scale) {
                        HStack(spacing: 14 * scale) {
                            QuestCard(quest: quest, icon: icons[quest.id], done: questDone) {
                                router.go(.instruction(TemplateChoice(templateID: quest.id, isDailyQuest: true)))
                            }
                            // Another random template for today's quest.
                            RoundButton(symbol: "shuffle", tint: .purple) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    quest = DailyQuestStore().reroll(for: Date())
                                }
                            }
                        }
                        ForEach(TemplateCatalog.levels, id: \.self) { level in
                            levelSection(level)
                        }
                    }
                    .padding(.horizontal, 4 * scale)
                    .padding(.bottom, 24 * scale)
                }
            }
            .padding(.horizontal, 28 * scale)
            .padding(.top, 20 * scale)
        }
    }

    private func levelSection(_ level: Int) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16 * scale), count: 4),
                      spacing: 16 * scale) {
                ForEach(TemplateCatalog.all.filter { $0.level == level }) { design in
                    TemplateTile(design: design, icon: icons[design.id]) {
                        router.go(.instruction(TemplateChoice(templateID: design.id, isDailyQuest: false)))
                    }
                }
            }
        }
    }

    private static func makeIcons() -> [String: CGImage] {
        var icons: [String: CGImage] = [:]
        for design in TemplateCatalog.all { icons[design.id] = design.art.iconImage(side: 256) }
        return icons
    }
}

private struct QuestCard: View {
    let quest: TemplateDesign
    let icon: CGImage?
    let done: Bool
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
        Button(action: action) {
            HStack(spacing: 20 * scale) {
                TileIcon(image: icon, side: 150 * scale)
                    .padding(8 * scale)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
                VStack(alignment: .leading, spacing: 6 * scale) {
                    Label("Tantangan harian", systemImage: "star.fill")
                        .font(.system(size: 16 * scale, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 12 * scale).padding(.vertical, 4 * scale)
                        .background(.white.opacity(0.28), in: Capsule())
                    Text(quest.title)
                        .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                    Text(done ? "Selesai hari ini. Lukis lagi kalau mau" : "Lukis dan simpan ke galeri")
                        .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
                        .opacity(0.9)
                }
                Spacer()
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52 * scale))
                }
            }
            .foregroundStyle(.white)
            .padding(18 * scale)
            .frame(maxWidth: .infinity)
            .background(Color.purple.gradient, in: shape)
            .overlay(shape.stroke(.white, lineWidth: 4))
            .shadow(color: .purple.opacity(0.35), radius: 10, y: 5)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

private struct TemplateTile: View {
    let design: TemplateDesign
    let icon: CGImage?
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26 * scale, style: .continuous)
        Button(action: action) {
            VStack(spacing: 4 * scale) {
                // The picture is the tile; the name is just a small caption under it.
                TileIcon(image: icon, side: 150 * scale)
                Text(design.title)
                    .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10 * scale)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.95), in: shape)
            .overlay(shape.stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

private struct TileIcon: View {
    let image: CGImage?
    let side: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: side, height: side)
    }
}

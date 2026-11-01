import SwiftUI

/// The daily quest on top, then every template in unlock order. A template opens once a painting of
/// the one before it is saved in the gallery.
struct TemplatesView: View {
    let router: AppRouter
    let gallery: Gallery
    @State private var quest = DailyQuestStore().quest(for: Date())
    @State private var icons: [String: CGImage] = TemplatesView.makeIcons()
    @Environment(\.uiScale) private var scale

    var body: some View {
        let saved = gallery.savedTemplateIDs
        let questDone = gallery.paintings(on: Date()).contains { $0.record.isDailyQuest }
        ZStack {
            PageBackground()
            VStack(spacing: 16 * scale) {
                HStack {
                    Button { router.go(.modePicker) } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.indigo)
                    Spacer()
                    Text("Templates")
                        .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(PageBackground.titleGradient)
                    Spacer()
                    Button { router.home() } label: {
                        Label("Home", systemImage: "house.fill")
                            .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.indigo)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 22 * scale) {
                        QuestCard(quest: quest, icon: icons[quest.id], done: questDone) {
                            router.go(.instruction(TemplateChoice(templateID: quest.id, isDailyQuest: true)))
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16 * scale), count: 3),
                                  spacing: 16 * scale) {
                            ForEach(TemplateCatalog.ordered, id: \.id) { kind in
                                let unlocked = TemplateCatalog.isUnlocked(kind, saved: saved)
                                TemplateTile(kind: kind, icon: icons[kind.id], unlocked: unlocked,
                                             lockedHint: TemplateCatalog.previous(of: kind)?.title) {
                                    router.go(.instruction(TemplateChoice(templateID: kind.id, isDailyQuest: false)))
                                }
                            }
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

    private static func makeIcons() -> [String: CGImage] {
        var icons: [String: CGImage] = [:]
        for kind in TemplateKind.allCases { icons[kind.id] = kind.art.iconImage(side: 192) }
        for quest in QuestCatalog.all { icons[quest.id] = quest.art.iconImage(side: 192) }
        return icons
    }
}

private struct QuestCard: View {
    let quest: Quest
    let icon: CGImage?
    let done: Bool
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
        Button(action: action) {
            HStack(spacing: 20 * scale) {
                TileIcon(image: icon, side: 110 * scale)
                    .padding(8 * scale)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
                VStack(alignment: .leading, spacing: 6 * scale) {
                    Label("Daily quest", systemImage: "star.fill")
                        .font(.system(size: 16 * scale, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 12 * scale).padding(.vertical, 4 * scale)
                        .background(.white.opacity(0.28), in: Capsule())
                    Text(quest.title)
                        .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                    Text(done ? "Done today. Paint it again if you like" : "Paint it and save it to the gallery")
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
    let kind: TemplateKind
    let icon: CGImage?
    let unlocked: Bool
    let lockedHint: String?
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26 * scale, style: .continuous)
        Button(action: action) {
            VStack(spacing: 8 * scale) {
                ZStack {
                    TileIcon(image: icon, side: 110 * scale)
                        .saturation(unlocked ? 1 : 0)
                        .opacity(unlocked ? 1 : 0.35)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 34 * scale, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                }
                Text(kind.title)
                    .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(unlocked ? Color(red: 0.25, green: 0.2, blue: 0.35) : .gray)
                if !unlocked, let lockedHint {
                    Text("Save a painting of \(lockedHint) to unlock")
                        .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(14 * scale)
            .frame(maxWidth: .infinity, minHeight: 190 * scale)
            .background(.white.opacity(unlocked ? 0.95 : 0.55), in: shape)
            .overlay(shape.stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(unlocked ? 0.12 : 0.04), radius: 8, y: 4)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
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

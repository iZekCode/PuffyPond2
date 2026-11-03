import SwiftUI

/// The first page: start drawing, visit the gallery, or look at the report. Touch only, since the
/// hands aren't in the camera yet.
struct HomeView: View {
    let router: AppRouter
    @Environment(\.uiScale) private var scale

    var body: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 36 * scale) {
                VStack(spacing: 6 * scale) {
                    Text("Puffy Pond")
                        .font(.system(size: 64 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(PageBackground.titleGradient)
                        .shadow(color: .white, radius: 0, x: 0, y: 3)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    Text("Paint with your hands")
                        .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35).opacity(0.7))
                }
                HomeButton(title: "Start drawing", symbol: "paintbrush.pointed.fill", tint: .pink) {
                    router.go(.modePicker)
                }
                HStack(spacing: 20 * scale) {
                    HomeButton(title: "View gallery", symbol: "building.columns.fill", tint: .orange) {
                        router.go(.gallery3D(start: 0, justHung: false))
                    }
                    HomeButton(title: "Report", symbol: "calendar", tint: .indigo) {
                        router.go(.report)
                    }
                }
            }
            .padding(24 * scale)
        }
    }
}

/// A big rounded pill in the HUD's style: gradient fill, white rim, soft colored shadow.
struct HomeButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14 * scale) {
                Image(systemName: symbol)
                    .font(.system(size: 26 * scale, weight: .bold))
                Text(title)
                    .font(.system(size: 26 * scale, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(minWidth: 280 * scale, minHeight: 84 * scale)
            .padding(.horizontal, 24 * scale)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 32 * scale, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32 * scale, style: .continuous).stroke(.white, lineWidth: 4))
            .shadow(color: tint.opacity(0.4), radius: 12, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 32 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Soft leaf-green and sunlight backdrop shared by the full-screen pages.
struct PageBackground: View {
    static let titleGradient = LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.3),
                                                       Color(red: 0.95, green: 0.35, blue: 0.65),
                                                       Color(red: 0.4, green: 0.55, blue: 1)],
                                              startPoint: .leading, endPoint: .trailing)

    var body: some View {
        LinearGradient(colors: [Color(red: 0.88, green: 0.97, blue: 0.84),
                                Color(red: 1, green: 0.96, blue: 0.86)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

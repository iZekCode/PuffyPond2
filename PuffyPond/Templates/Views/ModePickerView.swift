import SwiftUI

/// Freeform or a template: the first choice after Start drawing. Touch only.
struct ModePickerView: View {
    let router: AppRouter
    @Environment(\.uiScale) private var scale

    var body: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 32 * scale) {
                Text("What do you want to paint?")
                    .font(.system(size: 40 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(PageBackground.titleGradient)
                    .multilineTextAlignment(.center)
                HStack(spacing: 24 * scale) {
                    ModeCard(title: "Freeform", detail: "A blank canvas, anything you like",
                             symbol: "scribble.variable", tint: .pink) { router.go(.instruction(nil)) }
                    ModeCard(title: "Choose template", detail: "Trace a dotted outline",
                             symbol: "square.grid.2x2.fill", tint: .orange) { router.go(.templates) }
                }
                HomeButton(title: "Home", symbol: "house.fill", tint: .green) { router.home() }
            }
            .padding(24 * scale)
        }
    }
}

private struct ModeCard: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 36 * scale, style: .continuous)
        Button(action: action) {
            VStack(spacing: 14 * scale) {
                Image(systemName: symbol)
                    .font(.system(size: 64 * scale, weight: .bold))
                Text(title)
                    .font(.system(size: 30 * scale, weight: .heavy, design: .rounded))
                Text(detail)
                    .font(.system(size: 17 * scale, weight: .semibold, design: .rounded))
                    .opacity(0.9)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(24 * scale)
            .frame(width: 300 * scale, height: 260 * scale)
            .background(tint.gradient, in: shape)
            .overlay(shape.stroke(.white, lineWidth: 4))
            .shadow(color: tint.opacity(0.4), radius: 12, y: 6)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

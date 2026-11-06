import SwiftUI
import AVFoundation

/// The overlay on the full-screen canvas: a settings menu (top left), the eye that shows the camera's view of the
/// player (top right), and the tracing direction while an outline is on the canvas. No titles or hint bubbles.
struct HUDView: View {
    @Bindable var playground: Playground
    let previewLayer: CameraPreviewLayer
    let saveImage: () -> Void
    let goHome: () -> Void

    @Environment(\.uiScale) private var scale
    @State private var showingSettings = false
    @State private var showingVoiceSettings = false
    @State private var confirmingHome = false
    @State private var confirmingRestart = false

    var body: some View {
        ZStack {
            // Guide text for the dotted outline (only while tracing).
            VStack {
                guideBubble
                Spacer()
            }
            .padding(.top, 16 * scale)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            // Top left: settings.
            VStack {
                HStack {
                    settingsButton
                    Spacer()
                }
                Spacer()
            }
            .padding(16 * scale)

            // Top right: the eye, and the camera's view under it.
            VStack(alignment: .trailing, spacing: 10 * scale) {
                HStack {
                    Spacer()
                    RoundButton(symbol: playground.showCameraPreview ? "eye.fill" : "eye.slash.fill",
                                tint: playground.showCameraPreview ? .teal : .gray) {
                        withAnimation(.easeInOut(duration: 0.2)) { playground.showCameraPreview.toggle() }
                    }
                }
                if playground.showCameraPreview && playground.cameraStatus == .running {
                    cameraPreview.transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(16 * scale)

            if playground.showGuide {
                GuideCard { withAnimation(.easeOut(duration: 0.3)) { playground.showGuide = false } }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            if playground.cameraStatus == .denied || playground.cameraStatus == .unavailable {
                CameraNotice(denied: playground.cameraStatus == .denied)
            }
        }
        .confirmationDialog("Keluar tanpa menyimpan?", isPresented: $confirmingHome, titleVisibility: .visible) {
            Button("Keluar", role: .destructive, action: goHome)
            Button("Lanjut menggambar", role: .cancel) {}
        } message: {
            Text("Lukisan ini belum disimpan.")
        }
        .confirmationDialog("Ulangi kanvas?", isPresented: $confirmingRestart, titleVisibility: .visible) {
            Button("Ulangi", role: .destructive) { playground.clearAll() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Semua cat di kanvas akan dihapus.")
        }
    }

    // MARK: Settings

    private var settingsButton: some View {
        RoundButton(symbol: "gearshape.fill", tint: .indigo) { showingSettings.toggle() }
            .popover(isPresented: $showingSettings, arrowEdge: .top) { settingsPanel }
    }

    /// Grouped from what you tweak most to what leaves the page: size, sound, canvas, help, and last of all quit.
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pengaturan")
                .font(.system(size: 22, weight: .black, design: .rounded))

            settingsGroup("Kuas") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Ukuran karakter", systemImage: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Spacer()
                        Text(String(format: "%.1f×", playground.brushSize))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.secondary)
                        Slider(value: $playground.brushSize, in: Playground.brushSizeRange)
                        Image(systemName: "circle.fill").font(.system(size: 17)).foregroundStyle(.secondary)
                    }
                }
            }

            settingsGroup("Suara") {
                Toggle(isOn: Binding(get: { playground.musicOn }, set: { _ in playground.toggleMusic() })) {
                    Label("Musik & efek suara", systemImage: playground.musicOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                if playground.guideText != nil {
                    Toggle(isOn: Binding(get: { playground.guideVoiceOn }, set: { _ in playground.toggleGuideVoice() })) {
                        Label("Suara arahan", systemImage: "megaphone.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    if playground.guideVoiceOn {
                        actionRow("Atur suara arahan", symbol: "waveform", tint: .purple) { showingVoiceSettings.toggle() }
                            .popover(isPresented: $showingVoiceSettings) { GuideVoicePanel(voice: playground.voice) }
                    }
                }
            }

            settingsGroup("Kanvas") {
                actionRow("Simpan gambar", symbol: "photo.artframe", tint: .pink, enabled: playground.hasDrawing) {
                    showingSettings = false
                    saveImage()
                }
                actionRow("Ulangi kanvas", symbol: "arrow.counterclockwise", tint: .orange, enabled: playground.hasDrawing) {
                    showingSettings = false
                    confirmingRestart = true
                }
            }

            settingsGroup("Bantuan") {
                actionRow("Panduan", symbol: "questionmark.circle.fill", tint: .blue) {
                    showingSettings = false
                    withAnimation { playground.showGuide = true }
                }
            }

            actionRow("Keluar ke beranda", symbol: "house.fill", tint: .red) {
                showingSettings = false
                if playground.hasDrawing { confirmingHome = true } else { goHome() }
            }
        }
        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
        .padding(20)
        .frame(width: 320)
        #if os(iOS)
        .presentationCompactAdaptation(.popover)
        #endif
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func actionRow(_ title: String, symbol: String, tint: Color, enabled: Bool = true,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(tint.gradient, in: Circle())
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    // MARK: Tracing direction

    /// What to do next along the dotted outline, in words. Stays on screen when the spoken directions are muted.
    @ViewBuilder
    private var guideBubble: some View {
        if let text = playground.guideText {
            HStack(spacing: 10 * scale) {
                Image(systemName: "signpost.right.fill")
                    .font(.system(size: 16 * scale, weight: .bold))
                Text(text)
                    .font(.system(size: 17 * scale, weight: .heavy, design: .rounded))
            }
            .padding(.horizontal, 18 * scale)
            .padding(.vertical, 8 * scale)
            .background(Color(red: 1, green: 0.93, blue: 0.8).opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .foregroundStyle(Color(red: 0.55, green: 0.25, blue: 0.1))
        }
    }

    // MARK: Camera preview

    private var cameraPreview: some View {
        let height: CGFloat = (Platform.isPad ? 110 : 120) * scale
        let width = height * max(playground.imageAspect, 0.3)
        return ZStack {
            CameraPreview(previewLayer: previewLayer)
            Canvas { context, size in
                for hand in playground.previewHands {
                    for joint in hand {
                        let p = CGPoint(x: joint.x * size.width, y: joint.y * size.height)
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                                     with: .color(.white))
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .allowsHitTesting(false)
    }
}

struct RoundButton: View {
    let symbol: String
    let tint: Color
    var faded = false
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18 * scale, weight: .bold))
                .foregroundStyle(.white.opacity(faded ? 0.75 : 1))
                .frame(width: 46 * scale, height: 46 * scale)
                .background(tint.opacity(faded ? 0.45 : 1).gradient, in: Circle())
                .overlay(Circle().stroke(.white.opacity(faded ? 0.5 : 1), lineWidth: 2.5))
                .shadow(color: tint.opacity(faded ? 0.15 : 0.4), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// Which voice, how fast, how bright: opens from the purple button next to the megaphone.
private struct GuideVoicePanel: View {
    let voice: GuideVoice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Suara arahan")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
            if GuideVoice.hasClips {
                Text("Memakai rekaman suara.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            } else {
                group("Suara") {
                    VStack(alignment: .leading, spacing: 6) {
                        voiceRow("Otomatis (terbaik)", selected: voice.voiceID == nil) { voice.voiceID = nil }
                        ForEach(GuideVoice.indonesianVoices, id: \.identifier) { v in
                            voiceRow("\(v.name) · \(GuideVoice.qualityLabel(v))", selected: voice.voiceID == v.identifier) {
                                voice.voiceID = v.identifier
                            }
                        }
                    }
                }
                group("Kecepatan") {
                    HStack(spacing: 8) {
                        ForEach(GuideVoice.Pace.allCases) { pace in
                            chip(pace.label, selected: voice.pace == pace) { voice.pace = pace }
                        }
                    }
                }
                group("Nada") {
                    HStack(spacing: 8) {
                        ForEach(GuideVoice.Tone.allCases) { tone in
                            chip(tone.label, selected: voice.tone == tone) { voice.tone = tone }
                        }
                    }
                }
                Text("Suara yang lebih natural bisa diunduh di Pengaturan > Aksesibilitas > Konten Terucap > Suara.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
        .padding(18)
        .frame(width: 300, alignment: .leading)
        #if os(iOS)
        .presentationCompactAdaptation(.popover)
        #endif
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.secondary)
            content()
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            voice.sample()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : Color(red: 0.25, green: 0.2, blue: 0.35))
                .background(selected ? Color.purple : Color.purple.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func voiceRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            voice.sample()
        } label: {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.purple : .secondary)
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct GuideCard: View {
    let dismiss: () -> Void
    @Environment(\.uiScale) private var scale

    private struct Row: Identifiable {
        let symbol: String
        let color: Color
        let title: String
        let detail: String
        var id: String { title }
    }

    private let rows: [Row] = [
        Row(symbol: "hand.raised.fill", color: .orange, title: "Tangan terbuka = bergerak",
            detail: "Setiap tangan punya satu teman cat yang mengikutimu ke mana-mana. Tangan terbuka tidak pernah melukis."),
        Row(symbol: "paintbrush.pointed.fill", color: .blue, title: "Kepalan = melukis",
            detail: "Kepalkan tanganmu lalu ayunkan lenganmu. Buka tangan untuk berhenti."),
        Row(symbol: "sparkles", color: .green, title: "Satu teman, satu warna",
            detail: "Kepik merah, kupu-kupu biru, katak hijau, dan siput jingga. Gosok temanmu di atas salah satunya untuk berganti."),
        Row(symbol: "gearshape.fill", color: .indigo, title: "Pengaturan di pojok kiri atas",
            detail: "Atur ukuran, suara, ulangi kanvas, simpan gambar, atau keluar."),
        Row(symbol: "eye.fill", color: .teal, title: "Mata di pojok kanan atas",
            detail: "Lihat dirimu lewat kamera depan untuk memastikan tanganmu terlihat."),
        Row(symbol: "photo.artframe", color: .purple, title: "Sudah selesai? Simpan!",
            detail: "Buka Pengaturan lalu pilih Simpan gambar untuk melihatnya dulu, lalu gantung di galeri."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
            VStack(alignment: .leading, spacing: 18 * scale) {
                Text("Ayo berteman!")
                    .font(.system(size: 30 * scale, weight: .black, design: .rounded))
                Text("Mundur sedikit supaya kamera bisa melihat kedua tanganmu. Gerakan besar dan ceria paling bagus.")
                    .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 28 * scale, alignment: .top),
                                         count: Platform.isPad ? 2 : 1),
                          alignment: .leading, spacing: 18 * scale) {
                    ForEach(rows) { row in
                        HStack(spacing: 14 * scale) {
                            Image(systemName: row.symbol)
                                .font(.system(size: 22 * scale, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 48 * scale, height: 48 * scale)
                                .background(row.color.gradient, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).font(.system(size: 17 * scale, weight: .bold, design: .rounded))
                                Text(row.detail).font(.system(size: 14 * scale, design: .rounded)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Text("Angkat tanganmu untuk mulai · ketuk untuk menutup")
                    .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(28 * scale)
            .frame(maxWidth: Platform.isPad ? 900 : 480)
            .background(.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.pink.opacity(0.3), lineWidth: 4))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
            .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
            .padding(24)
            .onTapGesture(perform: dismiss)
        }
    }
}

private struct CameraNotice: View {
    let denied: Bool
    @Environment(\.uiScale) private var scale

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash.fill").font(.largeTitle)
            Text(denied ? "Akses kamera mati" : "Kamera tidak ditemukan")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(denied
                 ? "Puffy Pond butuh kamera untuk melihat tanganmu. Video tidak pernah keluar dari perangkatmu. Kamu tetap bisa menggambar dengan mouse atau jarimu."
                 : "Kamu tetap bisa menggambar dengan mouse atau jarimu.")
                .font(.system(size: 14, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if denied {
                Button("Buka Pengaturan") { Platform.openCameraSettings() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24 * scale)
        .frame(maxWidth: 360 * scale)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
    }
}

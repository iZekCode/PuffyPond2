import CoreGraphics
import SwiftUI

/// A month calendar on the left (days with paintings get a dot, a star when the daily quest was done)
/// and the selected day's paintings and movement stats on the right. Touch only.
struct ReportView: View {
    let gallery: Gallery
    let router: AppRouter
    @Environment(\.uiScale) private var scale
    @State private var month = Calendar.current.startOfDay(for: Date())
    @State private var selected = Calendar.current.startOfDay(for: Date())

    private var report: DayReport { DayReport(day: selected, paintings: gallery.paintings) }

    var body: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 12 * scale) {
                HStack {
                    RoundButton(symbol: "house.fill", tint: .blue, action: router.home)
                    Spacer()
                    Text("Report")
                        .font(.system(size: 30 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(PageBackground.titleGradient)
                    Spacer()
                    Color.clear.frame(width: 46 * scale, height: 46 * scale)
                }
                HStack(alignment: .top, spacing: 20 * scale) {
                    MonthCalendar(month: $month, selected: $selected,
                                  marked: gallery.daysWithPaintings(in: month),
                                  questDays: questDays)
                        .frame(maxWidth: .infinity)
                    DayDetail(report: report, gallery: gallery, router: router)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16 * scale)
        }
    }

    private var questDays: Set<Date> {
        let calendar = Calendar.current
        return Set(gallery.paintings.filter(\.record.isDailyQuest).map { calendar.startOfDay(for: $0.date) })
    }
}

private let ink = Color(red: 0.25, green: 0.2, blue: 0.35)

/// White rounded card the report's panels sit on.
private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.uiScale) private var scale

    var body: some View {
        content
            .padding(16 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Calendar

private struct MonthCalendar: View {
    @Binding var month: Date
    @Binding var selected: Date
    /// Start-of-day dates in `month` that have paintings.
    let marked: Set<Date>
    /// Start-of-day dates on which a daily quest painting was saved.
    let questDays: Set<Date>
    @Environment(\.uiScale) private var scale

    private var calendar: Calendar { .current }

    /// The month's days, with nils before the first so it starts on the right weekday column.
    private var cells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let lead = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: lead) + days.map { $0 }
    }

    private var weekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        Card {
            VStack(spacing: 14 * scale) {
                HStack {
                    RoundButton(symbol: "chevron.left", tint: .indigo) { shift(-1) }
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                    Spacer()
                    RoundButton(symbol: "chevron.right", tint: .indigo) { shift(1) }
                }
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4 * scale), count: 7)
                LazyVGrid(columns: columns, spacing: 6 * scale) {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day {
                            DayCell(day: day, isToday: calendar.isDateInToday(day),
                                    isSelected: calendar.isDate(day, inSameDayAs: selected),
                                    hasPaintings: marked.contains(day), questDone: questDays.contains(day)) {
                                selected = day
                            }
                        } else {
                            Color.clear.frame(height: 44 * scale)
                        }
                    }
                }
            }
        }
    }

    private func shift(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { month = next }
    }
}

private struct DayCell: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let hasPaintings: Bool
    let questDone: Bool
    let select: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        Button(action: select) {
            VStack(spacing: 2 * scale) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 16 * scale, weight: isSelected ? .black : .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : ink)
                HStack(spacing: 2 * scale) {
                    Circle().fill(hasPaintings ? (isSelected ? .white : .pink) : .clear)
                        .frame(width: 6 * scale, height: 6 * scale)
                    if questDone {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8 * scale, weight: .bold))
                            .foregroundStyle(isSelected ? .white : .orange)
                    }
                }
                .frame(height: 8 * scale)
            }
            .frame(maxWidth: .infinity, minHeight: 44 * scale)
            .background {
                Circle()
                    .fill(isSelected ? AnyShapeStyle(Color.indigo.gradient) : AnyShapeStyle(Color.clear))
                    .overlay(Circle().stroke(isToday ? Color.pink : .clear, lineWidth: 2.5))
                    .frame(width: 44 * scale, height: 44 * scale)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day detail

private struct DayDetail: View {
    let report: DayReport
    let gallery: Gallery
    let router: AppRouter
    @Environment(\.uiScale) private var scale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14 * scale) {
                Text(report.day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                if report.paintings.isEmpty {
                    Card {
                        VStack(spacing: 8 * scale) {
                            Text("🎨").font(.system(size: 44 * scale))
                            Text("No drawing this day")
                                .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24 * scale)
                    }
                } else {
                    paintingsCard
                    if let stats = report.stats {
                        romCard(stats)
                        heatmapCard(stats)
                        dominanceCard(stats)
                    } else {
                        Card {
                            Text("No movement data — these were drawn by touch or before tracking existed.")
                                .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.bottom, 24 * scale)
        }
    }

    private var paintingsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10 * scale) {
                HStack(spacing: 8 * scale) {
                    Text(report.paintings.count == 1 ? "1 painting" : "\(report.paintings.count) paintings")
                        .font(.system(size: 18 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                    if report.questDone {
                        Label("Quest done", systemImage: "star.fill")
                            .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12 * scale) {
                        ForEach(report.paintings) { painting in
                            Button {
                                let index = gallery.paintings.firstIndex(of: painting) ?? 0
                                router.go(.gallery3D(start: index, justHung: false))
                            } label: {
                                StripThumbnail(painting: painting)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4 * scale)
                }
            }
        }
    }

    private func romCard(_ stats: DayReport.Stats) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10 * scale) {
                Text("Highest ROM")
                    .font(.system(size: 18 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text("Arm raised out to the side")
                    .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12 * scale) {
                    SideValue(side: .left, text: degrees(stats.highestROM[.left]), tint: .teal)
                    SideValue(side: .right, text: degrees(stats.highestROM[.right]), tint: .pink)
                }
                Divider()
                StatRow(title: "Straightest elbow",
                        value: "L \(degrees(stats.elbowExtension[.left])) · R \(degrees(stats.elbowExtension[.right]))")
                StatRow(title: "Hand above shoulder",
                        value: "L \(widths(stats.reachHeight[.left])) · R \(widths(stats.reachHeight[.right]))")
                StatRow(title: "Grip cycles",
                        value: "L \(stats.gripCycles[.left] ?? 0) · R \(stats.gripCycles[.right] ?? 0)")
                if stats.maxTrunkLean > 15 {
                    Label("Leaned over to reach (\(Int(stats.maxTrunkLean.rounded()))°)",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                Text("Camera estimates, not a clinical measurement.")
                    .font(.system(size: 11 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func heatmapCard(_ stats: DayReport.Stats) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10 * scale) {
                Text("Heatmap")
                    .font(.system(size: 18 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text("Where your hands painted on the canvas")
                    .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                HeatmapView(cells: stats.heatmap)
            }
        }
    }

    private func dominanceCard(_ stats: DayReport.Stats) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10 * scale) {
                Text("Hand dominance")
                    .font(.system(size: 18 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                if stats.dominance.isEmpty {
                    Text("No painting time recorded")
                        .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    let left = stats.dominance[.left] ?? 0
                    let right = stats.dominance[.right] ?? 0
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.teal.gradient).frame(width: geometry.size.width * left)
                            Rectangle().fill(Color.pink.gradient).frame(width: geometry.size.width * right)
                        }
                    }
                    .frame(height: 22 * scale)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 2))
                    HStack {
                        Text("Left \(percent(left))").foregroundStyle(.teal)
                        Spacer()
                        Text("Right \(percent(right))").foregroundStyle(.pink)
                    }
                    .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
                }
            }
        }
    }

    private func degrees(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))°" } ?? "—"
    }

    private func widths(_ value: Double?) -> String {
        value.map { String(format: "%+.1f", $0) } ?? "—"
    }

    private func percent(_ share: Double) -> String { "\(Int((share * 100).rounded()))%" }
}

private struct SideValue: View {
    let side: Side
    let text: String
    let tint: Color
    @Environment(\.uiScale) private var scale

    var body: some View {
        VStack(spacing: 2 * scale) {
            Text(side == .left ? "Left" : "Right")
                .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                .foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8 * scale)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }
}

private struct StatRow: View {
    let title: String
    let value: String
    @Environment(\.uiScale) private var scale

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(ink)
        }
        .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
    }
}

/// The day's painting time per canvas cell, drawn as a soft glow over a blank canvas frame.
private struct HeatmapView: View {
    let cells: [Double]
    @Environment(\.uiScale) private var scale

    var body: some View {
        Color.white
            .aspectRatio(CGFloat(Playground.canvasSize.x / Playground.canvasSize.y), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if let image = Self.image(cells) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .blur(radius: 6 * scale)
                }
            }
        .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
        .padding(6 * scale)
        .background(Color(red: 0.55, green: 0.4, blue: 0.3), in: RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
    }

    /// One pixel per cell, top row first: transparent where nothing was painted, yellow → red as time grows.
    static func image(_ cells: [Double]) -> CGImage? {
        let columns = SessionStats.heatmapColumns, rows = SessionStats.heatmapRows
        guard cells.count == columns * rows, let peak = cells.max(), peak > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)
        for (i, value) in cells.enumerated() where value > 0 {
            let t = sqrt(value / peak)   // square root so light use still shows
            let alpha = 0.25 + 0.75 * t
            let rgb = (1.0, 0.85 - 0.65 * t, 0.2 - 0.2 * t)
            // Premultiplied alpha.
            pixels[i * 4 + 0] = UInt8(rgb.0 * alpha * 255)
            pixels[i * 4 + 1] = UInt8(rgb.1 * alpha * 255)
            pixels[i * 4 + 2] = UInt8(rgb.2 * alpha * 255)
            pixels[i * 4 + 3] = UInt8(alpha * 255)
        }
        return pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: columns, height: rows, bitsPerComponent: 8,
                      bytesPerRow: columns * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }
}

/// One painting in the day's strip, loaded small in the background, with its template and time.
private struct StripThumbnail: View {
    let painting: Painting
    @State private var image: CGImage?
    @Environment(\.uiScale) private var scale

    private var title: String {
        guard let id = painting.record.templateID else { return "Freeform" }
        return TemplateChoice(templateID: id, isDailyQuest: painting.record.isDailyQuest).title ?? "Freeform"
    }

    var body: some View {
        VStack(spacing: 4 * scale) {
            ZStack {
                Color.white
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                }
            }
            .frame(width: 150 * scale, height: 150 * scale * CGFloat(Playground.canvasSize.y / Playground.canvasSize.x))
            .padding(5 * scale)
            .background(.white, in: RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
            Text("\(title) · \(painting.date.formatted(.dateTime.hour().minute()))")
                .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .task(id: painting.url) {
            let url = painting.url
            image = await Task.detached(priority: .utility) { Gallery.loadImage(at: url, maxPixels: 320) }.value
        }
    }
}

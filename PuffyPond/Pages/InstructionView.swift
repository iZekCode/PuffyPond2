import SwiftUI
import AVFoundation

/// Before painting: stand about 1 m from the camera, inside the outline, until the ring fills.
/// Moves on to the canvas by itself; Skip is there for touch and no-camera use.
struct InstructionView: View {
    let router: AppRouter
    let tracker: HandTracker
    let cameraStatus: CameraStatus
    let choice: TemplateChoice?

    @Environment(\.uiScale) private var scale
    @State private var gate = DistanceGate()
    @State private var state: DistanceGate.State = .noPerson
    @State private var bodyFrame: BodyFrame?
    @State private var aspect: CGFloat = 4.0 / 3.0
    @State private var advanced = false

    private var inBand: Bool {
        switch state {
        case .holding, .ready: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 14 * scale) {
                Text("Get ready")
                    .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(PageBackground.titleGradient)
                    .shadow(color: .white, radius: 0, x: 0, y: 2)
                if cameraStatus == .running {
                    preview
                    hint
                } else {
                    Text(cameraStatus == .starting ? "Waking up the camera…"
                         : "No camera, so no distance check. Tap Skip to draw with your finger.")
                        .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                }
                Button(action: advance) {
                    Text("Skip")
                        .font(.system(size: 18 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28 * scale)
                        .padding(.vertical, 10 * scale)
                        .background(Color.pink.gradient, in: Capsule())
                        .overlay(Capsule().stroke(.white, lineWidth: 3))
                        .shadow(color: Color.pink.opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 20 * scale)
            .padding(.horizontal, 24 * scale)

            VStack {
                HStack {
                    RoundButton(symbol: "house.fill", tint: .green, action: router.home)
                    Spacer()
                }
                Spacer()
            }
            .padding(16 * scale)
        }
        .onAppear {
            gate = DistanceGate()
            state = .noPerson
            advanced = false
            tracker.onBody = { frame in receive(frame) }
            tracker.bodyPoseEnabled = true
        }
        .onDisappear {
            tracker.bodyPoseEnabled = false
            tracker.onBody = nil
        }
    }

    private func receive(_ frame: BodyFrame) {
        guard !advanced else { return }
        bodyFrame = frame
        aspect = CGFloat(max(frame.imageAspect, 0.3))
        let shoulders = frame.shoulders
        state = gate.update(shoulderWidth: shoulders?.width, centerX: shoulders?.centerX,
                            at: ProcessInfo.processInfo.systemUptime)
        if state == .ready { advance() }
    }

    private func advance() {
        guard !advanced else { return }
        advanced = true
        router.go(.canvas(choice))
    }

    // MARK: Preview

    private var preview: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = min(height * aspect, proxy.size.width)
            ZStack {
                CameraPreview(session: tracker.session)
                Canvas { context, size in
                    drawTarget(context, size: size)
                    drawBody(context, size: size)
                }
            }
            .frame(width: width, height: width / aspect)
            .clipShape(RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                .stroke(inBand ? Color.green : .white, lineWidth: 5))
            .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    /// The fixed outline to stand in: a head and a shoulder line as wide as the middle of the band.
    private func drawTarget(_ context: GraphicsContext, size: CGSize) {
        let color: Color = inBand ? .green : .white
        let shoulderWidth = CGFloat((DistanceGate.nearWidth + DistanceGate.farWidth) / 2) * size.width
        let centerX = size.width / 2
        let shoulderY = size.height * 0.62
        let headRadius = shoulderWidth * 0.3
        var outline = Path()
        outline.addEllipse(in: CGRect(x: centerX - headRadius, y: shoulderY - headRadius * 3.1,
                                      width: headRadius * 2, height: headRadius * 2.3))
        outline.move(to: CGPoint(x: centerX - shoulderWidth / 2, y: size.height))
        outline.addLine(to: CGPoint(x: centerX - shoulderWidth / 2, y: shoulderY + headRadius))
        outline.addQuadCurve(to: CGPoint(x: centerX, y: shoulderY - headRadius * 0.7),
                             control: CGPoint(x: centerX - shoulderWidth / 2, y: shoulderY - headRadius * 0.7))
        outline.addQuadCurve(to: CGPoint(x: centerX + shoulderWidth / 2, y: shoulderY + headRadius),
                             control: CGPoint(x: centerX + shoulderWidth / 2, y: shoulderY - headRadius * 0.7))
        outline.addLine(to: CGPoint(x: centerX + shoulderWidth / 2, y: size.height))
        context.stroke(outline, with: .color(color.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: inBand ? [] : [14, 10]))
    }

    /// What the camera currently sees of the arms: shoulder line, upper arms and forearms.
    private func drawBody(_ context: GraphicsContext, size: CGSize) {
        guard let bodyFrame else { return }
        func point(_ joint: BodyJoint) -> CGPoint? {
            guard let p = bodyFrame[joint] else { return nil }
            return CGPoint(x: CGFloat(p.location.x) * size.width, y: CGFloat(p.location.y) * size.height)
        }
        let links: [(BodyJoint, BodyJoint)] = [
            (.leftShoulder, .rightShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist), (.neck, .leftShoulder), (.neck, .rightShoulder),
        ]
        var bones = Path()
        for (a, b) in links {
            guard let pa = point(a), let pb = point(b) else { continue }
            bones.move(to: pa)
            bones.addLine(to: pb)
        }
        context.stroke(bones, with: .color(.pink), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        for joint in BodyJoint.allCases {
            guard let p = point(joint) else { continue }
            context.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(.white))
        }
    }

    // MARK: Hint

    private var hintText: (symbol: String, text: String) {
        switch state {
        case .noPerson: return ("person.fill.questionmark", "Stand in front of the camera")
        case .tooFar: return ("arrow.down.right.and.arrow.up.left", "Come closer")
        case .tooClose: return ("arrow.up.left.and.arrow.down.right", "Step back a little")
        case .offCenter: return ("arrow.left.and.right", "Stand in the middle")
        case .holding, .ready: return ("checkmark.circle.fill", "Perfect, hold still")
        }
    }

    private var progress: Double {
        switch state {
        case let .holding(progress): return progress
        case .ready: return 1
        default: return 0
        }
    }

    private var hint: some View {
        HStack(spacing: 14 * scale) {
            ZStack {
                Circle().stroke(Color.black.opacity(0.1), lineWidth: 6)
                Circle().trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: hintText.symbol)
                    .font(.system(size: 16 * scale, weight: .bold))
                    .foregroundStyle(inBand ? Color.green : Color.pink)
            }
            .frame(width: 44 * scale, height: 44 * scale)
            Text(hintText.text)
                .font(.system(size: 22 * scale, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
            Text("About 1 m from the screen")
                .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20 * scale)
        .padding(.vertical, 10 * scale)
        .background(.white.opacity(0.9), in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        .animation(.easeOut(duration: 0.15), value: progress)
    }
}

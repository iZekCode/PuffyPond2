import SceneKit
import simd

// MARK: - Outline art (dotted shapes to trace)

/// Line art kids can trace when they don't know what to draw: SVG-style path data plus eye dots.
/// Shared by the template list and the daily quests. Only a guide: it never goes into the gallery
/// photo, only their own paint does.
struct OutlineArt: Equatable {
    /// Outline as SVG-style path data (absolute M, L, C, Z) in a 300×220 sketch space, y down.
    let paths: [String]
    let eyes: [SIMD2<Float>]
    /// Icon color.
    let color: SIMD3<Float>

    /// Outline polylines and eye dots, scaled to fit `size` around `center` (world units, y up).
    func shape(center: SIMD2<Float>, size: SIMD2<Float>) -> (lines: [[SIMD2<Float>]], eyes: [SIMD2<Float>]) {
        let lines = paths.flatMap { Self.polylines($0) }
        let all = lines.flatMap { $0 } + eyes
        let lo = all.reduce(all[0], simd_min)
        let hi = all.reduce(all[0], simd_max)
        let scale = min(size.x / (hi.x - lo.x), size.y / (hi.y - lo.y))
        let mid = (lo + hi) * 0.5
        func place(_ p: SIMD2<Float>) -> SIMD2<Float> { center + SIMD2(p.x - mid.x, mid.y - p.y) * scale }
        return (lines.map { $0.map(place) }, eyes.map(place))
    }

    /// The outline drawn solid in the art's color, on a transparent square.
    func iconImage(side: Int = 256) -> CGImage? {
        let shape = shape(center: SIMD2(0.5, 0.5), size: SIMD2(0.86, 0.86))
        let c = color
        let ink = CGColor(red: CGFloat(c.x) * 0.8, green: CGFloat(c.y) * 0.8, blue: CGFloat(c.z) * 0.8, alpha: 1)
        let unit = CGFloat(side) / 256
        return Toybox.image(width: side, height: side) { ctx in
            func px(_ p: SIMD2<Float>) -> CGPoint { CGPoint(x: CGFloat(p.x) * CGFloat(side), y: CGFloat(p.y) * CGFloat(side)) }
            ctx.setStrokeColor(ink)
            ctx.setFillColor(ink)
            ctx.setLineWidth(14 * unit)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for line in shape.lines {
                ctx.move(to: px(line[0]))
                for p in line.dropFirst() { ctx.addLine(to: px(p)) }
                ctx.strokePath()
            }
            for eye in shape.eyes {
                let e = px(eye)
                ctx.fillEllipse(in: CGRect(x: e.x - 10 * unit, y: e.y - 10 * unit, width: 20 * unit, height: 20 * unit))
            }
        }
    }

    /// Flattens path data into polylines (curves sampled into short straight pieces).
    private static func polylines(_ path: String) -> [[SIMD2<Float>]] {
        let spaced = path.reduce(into: "") { s, ch in s += ch.isLetter ? " \(ch) " : String(ch) }
        var tokens = spaced.split(separator: " ").map(String.init)[...]
        func point() -> SIMD2<Float> {
            let x = Float(tokens.removeFirst()) ?? 0
            let y = Float(tokens.removeFirst()) ?? 0
            return SIMD2(x, y)
        }
        var lines: [[SIMD2<Float>]] = []
        var current: [SIMD2<Float>] = []
        var command = "M"
        while let token = tokens.first {
            if token.first?.isLetter == true {
                command = token
                tokens.removeFirst()
            }
            switch command {
            case "M":
                if current.count > 1 { lines.append(current) }
                current = [point()]
                command = "L"
            case "L":
                current.append(point())
            case "C":
                let a = current.last ?? .zero
                let c1 = point(), c2 = point(), b = point()
                for k in 1...16 {
                    let t = Float(k) / 16, u = 1 - t
                    current.append(a * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + b * (t * t * t))
                }
            case "Z":
                if let first = current.first { current.append(first) }
                if current.count > 1 { lines.append(current) }
                current = []
            default:
                tokens.removeFirst()
            }
        }
        if current.count > 1 { lines.append(current) }
        return lines
    }
}

// MARK: - Templates (a faint dotted pond animal to trace)

enum TemplateDifficulty: Int, Comparable {
    case easy, medium, hard

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

/// A shape to trace. The raw value is the id stored with saved paintings, so fish/turtle/duck keep theirs.
enum TemplateKind: String, CaseIterable {
    case fish, turtle, duck
    case sun, snail, cat
    case octopus, seahorse, butterfly

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var difficulty: TemplateDifficulty {
        switch self {
        case .fish, .duck, .sun: return .easy
        case .turtle, .snail, .cat: return .medium
        case .octopus, .seahorse, .butterfly: return .hard
        }
    }

    /// The three bubbles of the legacy tray on the easel.
    static let legacyTray: [TemplateKind] = [.fish, .turtle, .duck]

    /// Bubble icon color.
    var signatureColor: SIMD3<Float> { art.color }

    func shape(center: SIMD2<Float>, size: SIMD2<Float>) -> (lines: [[SIMD2<Float>]], eyes: [SIMD2<Float>]) {
        art.shape(center: center, size: size)
    }

    var art: OutlineArt {
        switch self {
        case .fish:
            return OutlineArt(paths: ["M60 110 C90 50 190 50 220 110 C190 170 90 170 60 110 Z",     // body
                                      "M220 110 L270 70 L262 110 L270 150 Z",                       // tail
                                      "M130 62 C140 35 170 35 175 60"],                             // fin
                              eyes: [SIMD2(100, 100)], color: Paint.colors[0])    // tangerine
        case .turtle:
            return OutlineArt(paths: ["M80 140 C80 70 220 70 220 140 Z",                            // shell
                                      "M220 125 C250 110 270 120 265 140 C258 155 235 150 222 140", // head
                                      "M95 140 L90 170 L115 170 L115 142",                          // legs
                                      "M185 142 L185 170 L210 170 L205 140",
                                      "M120 100 L150 85 L180 100 L170 128 L130 128 Z"],             // shell pattern
                              eyes: [SIMD2(252, 128)], color: Paint.colors[4])    // mint
        case .duck:
            return OutlineArt(paths: ["M70 130 C70 175 220 180 235 135 C240 115 210 110 190 120 C170 95 175 60 150 55 "
                                          + "C120 50 110 85 125 110 C100 105 70 110 70 130 Z",      // body and neck
                                      "M112 72 L85 78 L112 86"],                                    // beak
                              eyes: [SIMD2(138, 72)], color: Paint.colors[2])     // lemon
        case .sun:
            return OutlineArt(paths: ["M205 110 C205 140.4 180.4 165 150 165 C119.6 165 95 140.4 95 110 "
                                          + "C95 79.6 119.6 55 150 55 C180.4 55 205 79.6 205 110 Z", // face
                                      "M222 110 L250 110", "M78 110 L50 110", "M150 38 L150 10", "M150 182 L150 210",
                                      "M200.9 59.1 L220.7 39.3", "M99.1 59.1 L79.3 39.3",         // rays
                                      "M200.9 160.9 L220.7 180.7", "M99.1 160.9 L79.3 180.7",
                                      "M130 125 C140 140 160 140 170 125"],                         // smile
                              eyes: [SIMD2(133, 100), SIMD2(167, 100)], color: Paint.colors[2])
        case .snail:
            return OutlineArt(paths: ["M175 90 C175 120.4 150.4 145 120 145 C89.6 145 65 120.4 65 90 "
                                          + "C65 59.6 89.6 35 120 35 C150.4 35 175 59.6 175 90 Z",   // shell
                                      "M120 90 C120 75 140 75 140 92 C140 112 105 115 100 88 C95 62 135 52 152 78", // spiral
                                      "M30 150 C100 160 200 160 245 150 C270 145 268 115 258 100 C254 85 256 70 250 55", // body
                                      "M30 150 C70 140 95 144 118 145", "M170 138 C205 140 235 135 247 112", // body top
                                      "M262 100 C268 85 272 70 278 58"],                            // feelers
                              eyes: [SIMD2(258, 122)], color: Paint.colors[4])
        case .cat:
            return OutlineArt(paths: ["M235 125 C235 163.7 197 195 150 195 C103 195 65 163.7 65 125 "
                                          + "C65 86.3 103 55 150 55 C197 55 235 86.3 235 125 Z",     // head
                                      "M82 85 L72 30 L120 62", "M218 85 L228 30 L180 62",           // ears
                                      "M142 138 L158 138 L150 148 Z",                               // nose
                                      "M150 148 C150 160 138 162 130 156", "M150 148 C150 160 162 162 170 156",
                                      "M60 135 L100 140", "M60 155 L100 150",                       // whiskers
                                      "M240 135 L200 140", "M240 155 L200 150"],
                              eyes: [SIMD2(118, 115), SIMD2(182, 115)], color: Paint.colors[3])
        case .octopus:
            return OutlineArt(paths: ["M90 100 C80 20 220 20 210 100 Z",                            // head
                                      "M135 88 C145 96 155 96 165 88",                              // smile
                                      "M100 100 C90 130 70 140 60 165 C55 180 70 190 80 180",       // arms
                                      "M125 100 C120 135 105 150 105 180 C105 195 120 195 122 182",
                                      "M150 100 C150 135 140 160 145 190 C147 205 162 203 160 188",
                                      "M175 100 C180 135 195 150 195 180 C195 195 180 195 178 182",
                                      "M200 100 C210 130 230 140 240 165 C245 180 230 190 220 180"],
                              eyes: [SIMD2(125, 70), SIMD2(175, 70)], color: Paint.colors[5])
        case .seahorse:
            return OutlineArt(paths: ["M130 30 C150 15 175 25 175 50 C175 70 160 80 165 100 C172 125 150 140 150 160 "
                                          + "C150 185 175 195 190 180 C205 165 190 150 175 158",   // back and curled tail
                                      "M130 30 C115 35 105 50 100 58 L72 55 L74 68 L102 75 "
                                          + "C96 100 135 108 132 135 C130 158 140 172 152 182",         // snout and belly
                                      "M172 92 C194 84 200 112 170 118",                            // fin
                                      "M140 22 L145 8", "M155 20 L162 6"],                          // crown
                              eyes: [SIMD2(128, 48)], color: Paint.colors[1])
        case .butterfly:
            return OutlineArt(paths: ["M155 105 C170 40 260 15 270 55 C275 85 200 115 155 110",     // right wings
                                      "M155 112 C200 118 245 140 232 175 C220 200 170 175 155 125",
                                      "M145 105 C130 40 40 15 30 55 C25 85 100 115 145 110",        // left wings
                                      "M145 112 C100 118 55 140 68 175 C80 200 130 175 145 125",
                                      "M150 85 C156 85 158 95 158 115 C158 135 155 150 150 150 "
                                          + "C145 150 142 135 142 115 C142 95 144 85 150 85 Z",     // body
                                      "M147 88 C140 65 135 55 128 45", "M153 88 C160 65 165 55 172 45"],
                              eyes: [SIMD2(205, 60), SIMD2(95, 60)], color: Paint.colors[3])
        }
    }
}

/// The dotted outline lying on the canvas, just under the paint. The starfish scrubs it away dash by dash.
final class TemplateOutline {
    /// The template it came from (nil for a daily-quest outline).
    let kind: TemplateKind?
    let node = SCNNode()
    private let material = SCNMaterial()
    private let origin: SIMD2<Float>        // bottom-left of the canvas
    private let size: SIMD2<Float>
    private var marks: [[SIMD2<Float>]]     // dashes; a single point is an eye dot
    private var dirty = true
    private var fading = false

    private static let pixelsPerUnit: Float = 200
    private static let lineWidth: Float = 0.06
    private static let eyeRadius: Float = 0.07
    private static let dash: Float = 0.18
    private static let gap: Float = 0.14
    private static let ink = CGColor(red: 0.42, green: 0.36, blue: 0.3, alpha: 0.5)

    convenience init(kind: TemplateKind, canvasCenter: SIMD2<Float>, canvasSize: SIMD2<Float>, z: Float) {
        self.init(art: kind.art, kind: kind, canvasCenter: canvasCenter, canvasSize: canvasSize, z: z)
    }

    init(art: OutlineArt, kind: TemplateKind? = nil, canvasCenter: SIMD2<Float>, canvasSize: SIMD2<Float>, z: Float) {
        self.kind = kind
        origin = canvasCenter - canvasSize * 0.5
        size = canvasSize
        // Big and bold so small kids can follow it; nudged up a little, clear of the bubbles on the tray.
        let shape = art.shape(center: canvasCenter + SIMD2(0, 0.15), size: canvasSize * SIMD2(0.72, 0.68))
        marks = shape.lines.flatMap { Self.dashes($0) } + shape.eyes.map { [$0] }

        let plane = SCNPlane(width: CGFloat(canvasSize.x), height: CGFloat(canvasSize.y))
        material.lightingModel = .physicallyBased
        material.roughness.contents = NSNumber(value: 1.0)
        material.metalness.contents = NSNumber(value: 0.0)
        material.transparencyMode = .aOne
        material.writesToDepthBuffer = false
        plane.materials = [material]
        node.geometry = plane
        node.castsShadow = false
        node.simdPosition = SIMD3(canvasCenter.x, canvasCenter.y, z)
        node.opacity = 0
        node.runAction(.fadeIn(duration: 0.4))
        render()
    }

    var isEmpty: Bool { marks.isEmpty }

    /// Starfish scrub: wipes the dashes it touches. Returns true if anything was wiped.
    @discardableResult
    func erase(at p: SIMD2<Float>, radius: Float) -> Bool {
        guard !fading else { return false }
        let before = marks.count
        marks.removeAll { mark in mark.contains { simd_distance($0, p) < radius + Self.lineWidth * 0.5 } }
        if marks.count != before { dirty = true }
        return marks.count != before
    }

    func update() {
        if dirty { render() }
    }

    /// Fades out and leaves the scene.
    func fadeAway() {
        fading = true
        node.runAction(.sequence([.fadeOut(duration: 0.35), .removeFromParentNode()]))
    }

    private func render() {
        dirty = false
        let s = Self.pixelsPerUnit
        let image = Toybox.image(width: Int(size.x * s), height: Int(size.y * s)) { ctx in
            func px(_ p: SIMD2<Float>) -> CGPoint {
                CGPoint(x: CGFloat((p.x - origin.x) * s), y: CGFloat((p.y - origin.y) * s))
            }
            ctx.setStrokeColor(Self.ink)
            ctx.setFillColor(Self.ink)
            ctx.setLineWidth(CGFloat(Self.lineWidth * s))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for mark in marks {
                if mark.count == 1 {
                    let c = px(mark[0])
                    let r = CGFloat(Self.eyeRadius * s)
                    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                } else {
                    ctx.move(to: px(mark[0]))
                    for p in mark.dropFirst() { ctx.addLine(to: px(p)) }
                    ctx.strokePath()
                }
            }
        }
        material.diffuse.contents = Toybox.platformImage(image)
    }

    /// Cuts a polyline into dashes of `dash` length separated by `gap`.
    private static func dashes(_ line: [SIMD2<Float>]) -> [[SIMD2<Float>]] {
        guard let first = line.first else { return [] }
        var out: [[SIMD2<Float>]] = []
        var piece = [first]
        var drawing = true
        var left = dash
        for (start, end) in zip(line, line.dropFirst()) {
            var a = start
            var length = simd_distance(a, end)
            while length > 0 && length >= left {
                let q = a + (end - a) * (left / length)
                if drawing {
                    piece.append(q)
                    out.append(piece)
                } else {
                    piece = [q]
                }
                drawing.toggle()
                a = q
                length -= left
                left = drawing ? dash : gap
            }
            left -= length
            if drawing { piece.append(end) }
        }
        if drawing && piece.count > 1 { out.append(piece) }
        return out
    }
}

// MARK: - Template bubbles (rub one to get its outline on the canvas)

/// A glass bubble on the easel tray with a little picture of the animal to trace.
final class TemplatePot {
    let root = SCNNode()
    let kind: TemplateKind
    private let bubble: SCNNode
    private let icon: SCNNode
    private let progressRing: SCNNode
    private let halo: SCNNode
    private var squash = Spring3(SIMD3(1, 1, 1))
    private var ringScale = Spring1(0)
    private var clock: Float = 0

    init(kind: TemplateKind, at position: SIMD3<Float>) {
        self.kind = kind
        root.simdPosition = position
        clock = Float(TemplateKind.legacyTray.firstIndex(of: kind) ?? 0) * 1.7

        let glass = SCNMaterial()
        glass.lightingModel = .blinn
        glass.diffuse.contents = PlatformColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0.14)
        glass.specular.contents = PlatformColor.white
        glass.shininess = 0.9
        glass.transparencyMode = .aOne
        glass.writesToDepthBuffer = false
        bubble = Toybox.node(SCNSphere(radius: CGFloat(PaintPot.radius)), glass)
        root.addChildNode(bubble)
        let stand = Toybox.balloon(kind.signatureColor, wobble: 0, roughness: 0.25)
        root.addChildNode(Toybox.node(SCNTorus(ringRadius: 0.14, pipeRadius: 0.035), stand, at: SIMD3(0, -0.19, 0)))

        // The animal's outline, drawn solid in its color, floating inside the bubble.
        let picture = SCNMaterial()
        picture.lightingModel = .constant
        picture.diffuse.contents = Toybox.platformImage(Self.iconImage(kind))
        picture.transparencyMode = .aOne
        picture.writesToDepthBuffer = false
        let plane = SCNPlane(width: 0.3, height: 0.3)
        plane.materials = [picture]
        icon = SCNNode(geometry: plane)
        icon.castsShadow = false
        root.addChildNode(icon)

        let ringMaterial = SCNMaterial()
        ringMaterial.lightingModel = .constant
        ringMaterial.diffuse.contents = PlatformColor.white
        progressRing = SCNNode(geometry: SCNTorus(ringRadius: 0.27, pipeRadius: 0.022))
        progressRing.geometry?.materials = [ringMaterial]
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, 0, 0)
        progressRing.simdScale = SIMD3(repeating: 0.001)
        root.addChildNode(progressRing)

        halo = SCNNode(geometry: SCNTorus(ringRadius: 0.22, pipeRadius: 0.014))
        halo.geometry?.materials = [ringMaterial]
        halo.simdPosition = SIMD3(0, -0.17, 0)
        root.addChildNode(halo)
    }

    func bounce(_ strength: Float = 1) {
        squash.velocity += SIMD3(3, -5, 3) * strength
    }

    /// - Parameters:
    ///   - rubProgress: 0…1 while a buddy is rubbing this bubble.
    ///   - selected: this animal's outline is on the canvas right now.
    func update(dt: Float, beatPulse: Float, rubProgress: Float, selected: Bool) {
        clock += dt
        let jiggle = rubProgress > 0 ? sin(clock * 30) * 0.05 * rubProgress : 0
        squash.step(to: SIMD3(1 + beatPulse * 0.04 + jiggle, 1 - beatPulse * 0.05 - jiggle, 1 + jiggle),
                    stiffness: 260, damping: 9, dt: dt)
        bubble.simdScale = squash.value
        icon.simdScale = squash.value
        icon.simdPosition = SIMD3(0, sin(clock * 1.3) * 0.015, 0.02)
        icon.simdEulerAngles = SIMD3(0, 0, sin(clock * 0.9) * 0.08)
        ringScale.step(to: rubProgress > 0 ? 0.35 + rubProgress * 0.65 : 0, stiffness: 300, damping: 18, dt: dt)
        progressRing.simdScale = SIMD3(repeating: max(ringScale.value, 0.001))
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, clock * 3, 0)
        halo.isHidden = !selected
        halo.simdScale = SIMD3(repeating: 1 + sin(clock * 4) * 0.04)
        halo.simdEulerAngles = SIMD3(0.25, clock, 0)
    }

    static func iconImage(_ kind: TemplateKind) -> CGImage? { kind.art.iconImage() }
}

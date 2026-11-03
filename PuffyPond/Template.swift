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
    /// How much of the canvas the outline covers, relative to the usual size.
    var spread: Float = 1

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

// MARK: - Templates (a faint dotted abstract shape to trace)

/// Sets the unlock order and how far a shape reaches across the canvas. Never shown to kids.
enum TemplateDifficulty: Int, Comparable {
    case easy, medium, hard

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// An abstract shape to trace. Blobs on purpose, not animals: the kid decides what it becomes.
/// The raw value is the id stored with saved paintings, so the shapes that replaced fish/duck/turtle keep those ids.
enum TemplateKind: String, CaseIterable {
    case pebble = "fish", bean = "duck", puddle
    case bumpy = "turtle", wiggle, peanut
    case reach, sprawl, zigzag

    var id: String { rawValue }

    var title: String { "\(self)".capitalized }

    var difficulty: TemplateDifficulty {
        switch self {
        case .pebble, .bean, .puddle: return .easy
        case .bumpy, .wiggle, .peanut: return .medium
        case .reach, .sprawl, .zigzag: return .hard
        }
    }

    /// The three bubbles of the legacy tray on the easel.
    static let legacyTray: [TemplateKind] = [.pebble, .bumpy, .bean]

    /// Bubble icon color.
    var signatureColor: SIMD3<Float> { art.color }

    func shape(center: SIMD2<Float>, size: SIMD2<Float>) -> (lines: [[SIMD2<Float>]], eyes: [SIMD2<Float>]) {
        art.shape(center: center, size: size)
    }

    /// Easy and medium shapes stay near the middle. Hard ones push into the corners and edges
    /// (`spread` > 1 draws them bigger), so the arms have to travel further: more range of motion.
    var art: OutlineArt {
        switch self {
        case .pebble:
            return OutlineArt(paths: [
                                      "M150 28 C168 28 193 27 212 34 C231 41 252 58 262 72 "
                                          + "C272 86 274 102 270 118 C266 134 255 156 240 168 "
                                          + "C225 180 199 185 178 188 C157 191 132 189 112 184 "
                                          + "C92 179 71 171 58 158 C45 145 36 125 36 108 C36 91 47 70 58 58 "
                                          + "C69 46 89 39 104 34 C119 29 132 28 150 28 Z"],
                              eyes: [], color: Paint.colors[0])
        case .bean:
            return OutlineArt(paths: [
                                      "M60 70 C72 57 93 40 110 36 C127 32 146 38 160 44 "
                                          + "C174 50 180 73 192 74 C204 75 218 53 232 52 "
                                          + "C246 51 268 59 276 70 C284 81 287 102 282 118 "
                                          + "C277 134 261 155 246 166 C231 177 211 181 190 184 "
                                          + "C169 187 142 190 120 186 C98 182 72 172 58 160 "
                                          + "C44 148 38 127 38 112 C38 97 48 83 60 70 Z"],
                              eyes: [], color: Paint.colors[2])
        case .puddle:
            return OutlineArt(paths: [
                                      "M90 150 C77 140 64 129 62 118 C60 107 69 91 80 82 "
                                          + "C91 73 117 74 130 66 C143 58 143 42 156 36 "
                                          + "C169 30 191 25 206 28 C221 31 239 41 246 52 "
                                          + "C253 63 254 85 250 96 C246 107 222 109 222 118 "
                                          + "C222 127 250 139 252 150 C254 161 244 177 232 184 "
                                          + "C220 191 196 191 180 190 C164 189 153 183 138 176 "
                                          + "C123 169 103 160 90 150 Z"],
                              eyes: [], color: Paint.colors[4])
        case .bumpy:
            return OutlineArt(paths: [
                                      "M150 24 C163 23 183 17 196 22 C209 27 214 45 226 52 "
                                          + "C238 59 260 53 270 62 C280 71 287 93 286 106 "
                                          + "C285 119 265 128 262 140 C259 152 277 169 270 178 "
                                          + "C263 187 237 196 222 196 C207 196 193 178 178 178 "
                                          + "C163 178 147 197 132 198 C117 199 96 190 86 182 "
                                          + "C76 174 84 155 74 148 C64 141 37 147 28 138 "
                                          + "C19 129 17 105 22 92 C27 79 46 72 56 62 C66 52 70 35 80 30 "
                                          + "C90 25 104 31 116 30 C128 29 137 25 150 24 Z",
                                      "M184 108 C184 115 182 126 176 131 C170 136 159 137 150 136 "
                                          + "C141 136 130 135 125 130 C119 126 115 115 116 108 "
                                          + "C117 101 122 94 128 88 C133 83 142 77 150 76 "
                                          + "C158 76 168 82 173 87 C179 93 184 101 184 108 Z"],
                              eyes: [], color: Paint.colors[3])
        case .wiggle:
            return OutlineArt(paths: [
                                      "M26 112 C24 95 24 76 30 66 C36 56 50 49 62 50 "
                                          + "C74 51 87 64 100 72 C113 80 127 100 140 100 "
                                          + "C153 100 167 81 180 72 C193 63 202 49 216 46 "
                                          + "C230 43 251 47 262 56 C273 65 282 84 284 100 "
                                          + "C286 116 280 137 272 150 C264 163 249 175 236 176 "
                                          + "C223 177 209 163 196 154 C183 145 173 121 160 120 "
                                          + "C147 119 133 137 120 146 C107 155 97 172 84 176 "
                                          + "C71 180 54 181 44 170 C34 159 28 129 26 112 Z"],
                              eyes: [], color: Paint.colors[5])
        case .peanut:
            return OutlineArt(paths: [
                                      "M40 96 C40 80 45 62 56 52 C67 42 90 34 104 36 "
                                          + "C118 38 129 61 140 66 C151 71 159 71 170 66 "
                                          + "C181 61 192 38 206 36 C220 34 241 41 252 52 "
                                          + "C263 63 272 84 272 100 C272 116 265 137 254 148 "
                                          + "C243 159 220 169 206 168 C192 167 181 146 170 142 "
                                          + "C159 138 151 138 140 142 C129 146 118 167 104 168 "
                                          + "C90 169 67 162 56 150 C45 138 40 112 40 96 Z",
                                      "M110 100 C110 106 107 115 103 118 C98 122 89 122 83 120 "
                                          + "C77 119 70 115 67 110 C65 105 67 96 69 91 C72 86 78 79 83 78 "
                                          + "C88 76 97 79 102 83 C106 87 110 94 110 100 Z",
                                      "M237 100 C237 106 232 114 228 117 C223 121 215 121 209 120 "
                                          + "C204 119 196 115 193 110 C190 105 191 96 194 90 "
                                          + "C197 85 204 81 209 79 C215 78 224 79 228 82 "
                                          + "C233 85 237 94 237 100 Z"],
                              eyes: [], color: Paint.colors[1])
        case .reach:
            return OutlineArt(paths: [
                                      "M16 66 C11 54 16 37 22 28 C28 19 44 15 54 14 "
                                          + "C64 13 74 15 84 24 C94 33 105 64 116 70 C127 76 139 62 150 62 "
                                          + "C161 62 173 76 184 70 C195 64 206 33 216 24 "
                                          + "C226 15 236 13 246 14 C256 15 272 19 278 28 "
                                          + "C284 37 289 54 284 66 C279 78 246 88 246 100 "
                                          + "C246 112 279 128 284 140 C289 152 284 164 278 172 "
                                          + "C272 180 256 187 246 188 C236 189 226 186 216 176 "
                                          + "C206 166 195 135 184 128 C173 121 161 136 150 136 "
                                          + "C139 136 127 121 116 128 C105 135 94 166 84 176 "
                                          + "C74 186 64 189 54 188 C44 187 28 180 22 172 "
                                          + "C16 164 11 152 16 140 C21 128 54 112 54 100 "
                                          + "C54 88 21 78 16 66 Z"],
                              eyes: [], color: Paint.colors[0], spread: 1.25)
        case .sprawl:
            return OutlineArt(paths: [
                                      "M18 46 C16 34 25 20 34 14 C43 8 64 6 74 10 C84 14 94 27 96 38 "
                                          + "C98 49 92 68 84 76 C76 84 57 89 46 84 C35 79 20 58 18 46 Z",
                                      "M204 28 C209 18 233 8 246 8 C259 8 277 18 284 28 "
                                          + "C291 38 295 57 290 66 C285 75 267 84 254 84 "
                                          + "C241 84 222 77 214 68 C206 59 199 38 204 28 Z",
                                      "M14 130 C18 119 37 110 50 108 C63 106 82 110 90 118 "
                                          + "C98 126 103 143 100 154 C97 165 82 180 70 184 "
                                          + "C58 188 37 185 28 176 C19 167 10 141 14 130 Z",
                                      "M210 122 C217 112 239 104 252 104 C265 104 283 113 288 124 "
                                          + "C293 135 291 158 284 168 C277 178 260 187 248 186 "
                                          + "C236 185 218 173 212 162 C206 151 203 132 210 122 Z",
                                      "M112 76 C117 67 137 60 150 60 C163 60 183 69 190 78 "
                                          + "C197 87 198 104 192 112 C186 120 168 128 156 128 "
                                          + "C144 128 125 121 118 112 C111 103 107 85 112 76 Z"],
                              eyes: [], color: Paint.colors[4], spread: 1.25)
        case .zigzag:
            return OutlineArt(paths: [
                                      "M12 34 C12 23 21 14 32 14 L268 14 "
                                          + "C279 14 288 23 288 34 L288 36 C288 47 280 60 270 65 L122 135 "
                                          + "C112 140 113 144 124 144 L268 144 "
                                          + "C279 144 288 153 288 164 L288 166 "
                                          + "C288 177 279 186 268 186 L32 186 C21 186 12 177 12 166 L12 164 "
                                          + "C12 153 20 140 30 135 L178 65 C188 60 187 56 176 56 L32 56 "
                                          + "C21 56 12 47 12 36 Z"],
                              eyes: [], color: Paint.colors[3], spread: 1.25)
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
        let shape = art.shape(center: canvasCenter + SIMD2(0, 0.15), size: canvasSize * SIMD2(0.72, 0.68) * art.spread)
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

    /// How many dashes and eye dots are left to trace.
    var markCount: Int { marks.count }

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

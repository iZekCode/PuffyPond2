import Foundation
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

    var title: String {
        switch self {
        case .pebble: return "Kerikil"
        case .bean: return "Kacang"
        case .puddle: return "Genangan"
        case .bumpy: return "Benjol"
        case .wiggle: return "Meliuk"
        case .peanut: return "Kacang tanah"
        case .reach: return "Jangkauan"
        case .sprawl: return "Menyebar"
        case .zigzag: return "Zig-zag"
        }
    }

    /// Where it sits in the template list (1 = easy).
    var level: Int {
        switch difficulty {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    var difficulty: TemplateDifficulty {
        switch self {
        case .pebble, .bean, .puddle: return .easy
        case .bumpy, .wiggle, .peanut: return .medium
        case .reach, .sprawl, .zigzag: return .hard
        }
    }

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

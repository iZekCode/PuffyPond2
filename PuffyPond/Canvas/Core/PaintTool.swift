import simd

/// The four paint characters. Each one is its own animal with its own single colour and paints its own way.
enum PaintTool: Int, CaseIterable, Equatable {
    case ladybug, butterfly, frog, snail

    var name: String {
        switch self {
        case .ladybug: return "Kepik"
        case .butterfly: return "Kupu-kupu"
        case .frog: return "Katak"
        case .snail: return "Siput"
        }
    }

    /// The critter that carries this tool.
    var critterKind: CritterKind {
        switch self {
        case .ladybug: return .ladybug
        case .butterfly: return .butterfly
        case .frog: return .frog
        case .snail: return .snail
        }
    }

    /// The character's one colour: an index into `Paint.colors` (red, blue, green, orange).
    var colorIndex: Int {
        switch self {
        case .ladybug: return 0
        case .butterfly: return 1
        case .frog: return 4
        case .snail: return 3
        }
    }

    var color: SIMD3<Float> { Paint.colors[colorIndex] }

    /// Paint for this frame's segment a → b of the character's path across the canvas.
    /// (The ladybug paints with its legs too, so the playground asks the critter itself for its dabs.)
    func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        switch self {
        case .ladybug, .frog:
            return [BrushDab(from: a, to: b, radius: radius, speed: speed, style: .wash)]
        case .butterfly:
            // Round, textured stroke, a touch broader than a single limb.
            return [BrushDab(from: a, to: b, radius: radius * 1.15, speed: speed, style: .wash)]
        case .snail:
            return [BrushDab(from: a, to: b, radius: radius * 1.3, speed: speed, style: .wash)]
        }
    }
}

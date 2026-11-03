import simd

/// The five paint characters of the fist controls. Each one is its own animal and paints its own way.
enum PaintTool: Int, CaseIterable, Equatable {
    case thickOil, liquidOil, brush, eraser, blender

    var name: String {
        switch self {
        case .thickOil: return "Thick oil"
        case .liquidOil: return "Liquid oil"
        case .brush: return "Brush"
        case .eraser: return "Eraser"
        case .blender: return "Blender"
        }
    }

    var symbol: String {
        switch self {
        case .thickOil: return "rectangle.portrait.fill"
        case .liquidOil: return "drop.fill"
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "star.fill"
        case .blender: return "tornado"
        }
    }

    /// The brush animal that carries this tool (the eraser is the starfish, which isn't a brush animal).
    var critterKind: CritterKind? {
        switch self {
        case .thickOil: return .snail
        case .liquidOil: return .jellyfish
        case .brush: return .spider
        case .eraser: return nil
        case .blender: return .sponge
        }
    }

    /// Eraser and blender lay no paint of their own, so the paint pots don't matter to them.
    var usesColor: Bool { self != .eraser && self != .blender }

    /// Paint for this frame's segment a → b of the character's path across the canvas.
    func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        let d = b - a
        let moving = smoothStep(0.002, 0.02, simd_length(d))
        switch self {
        case .thickOil:
            // Heavy impasto: a wide knife-like sheet, piled high with ridged edges.
            let angle = simd_length(d) > 1e-5 ? atan2(d.y, d.x) + Float.pi / 2 : Float.pi / 2
            var style = BrushStyle(push: 0.9, bristles: 0.4, nibAngle: angle, nibAspect: 1.4, knife: 0.6, impasto: 1)
            style.amount = 0.08 + 0.4 * moving
            return [BrushDab(from: a, to: b, radius: radius * 1.5, speed: speed, style: style)]
        case .liquidOil:
            // Thinned oil: a translucent glaze that spreads out and runs downhill.
            let style = BrushStyle(amount: 0.08 + 0.12 * moving, push: 0.35, bristles: 0.15, watery: 0.4, runs: 1)
            return [BrushDab(from: a, to: b, radius: radius * 1.25, speed: speed, style: style)]
        case .brush:
            return [BrushDab(from: a, to: b, radius: radius, speed: speed, style: .octopus)]
        case .eraser:
            return []
        case .blender:
            return [BrushDab(from: a, to: b, radius: radius * 1.6, speed: speed, style: .blend)]
        }
    }
}

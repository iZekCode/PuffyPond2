import simd

/// The four paint characters of the fist controls. Each one is its own animal and paints its own way. The
/// butterfly and the ladybug are both brushes; they differ in their colours (`Paint.palette(for:)`).
enum PaintTool: Int, CaseIterable, Equatable {
    case wingBrush, brush, eraser, blender

    var name: String {
        switch self {
        case .wingBrush: return "Kuas sayap"
        case .brush: return "Kuas"
        case .eraser: return "Penghapus"
        case .blender: return "Pencampur"
        }
    }

    var symbol: String {
        switch self {
        case .wingBrush: return "paintbrush.fill"
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "star.fill"
        case .blender: return "tornado"
        }
    }

    /// The critter that carries this tool.
    var critterKind: CritterKind {
        switch self {
        case .wingBrush: return .butterfly
        case .brush: return .ladybug
        case .eraser: return .mushroom
        case .blender: return .snail
        }
    }

    /// Eraser and blender lay no paint of their own, so the paint pots don't matter to them.
    var usesColor: Bool { self != .eraser && self != .blender }

    /// Paint for this frame's segment a → b of the character's path across the canvas.
    func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        switch self {
        case .wingBrush:
            // The butterfly's brush: one round, textured stroke, a touch broader than a single limb.
            return [BrushDab(from: a, to: b, radius: radius * 1.15, speed: speed, style: .wash)]
        case .brush:
            return [BrushDab(from: a, to: b, radius: radius, speed: speed, style: .wash)]
        case .eraser:
            return []
        case .blender:
            return [BrushDab(from: a, to: b, radius: radius * 1.6, speed: speed, style: .blend)]
        }
    }
}

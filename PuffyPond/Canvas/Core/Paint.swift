import simd

enum Paint {
    /// The six paint colours, each the mid tone of its NCA texture (tools/nca/targets/), so a pot, an animal and its paint match.
    /// The order matches the NCA model file (PuffyPond/NCA/nca.bin) and keeps the old palette's roles
    /// (templates and animals refer to colours by index: 0 warm, 1 cool, 2 light, 3 orange, 4 green, 5 purple).
    static let colors: [SIMD3<Float>] = [
        SIMD3(0.97, 0.38, 0.40), // red      (ladybug)
        SIMD3(0.36, 0.64, 0.89), // blue     (butterfly)
        SIMD3(0.97, 0.82, 0.10), // yellow   (ladybug)
        SIMD3(0.99, 0.55, 0.12), // orange   (ladybug)
        SIMD3(0.08, 0.66, 0.35), // green    (butterfly)
        SIMD3(0.54, 0.42, 0.77), // purple   (butterfly)
    ]

    static let names = ["Merah", "Biru", "Kuning", "Jingga", "Hijau", "Ungu"]

    /// The colours (indices into `colors`) each brush animal paints with, in the order its pots are shown.
    /// Only the garden brushes are limited to a palette; every other animal paints with any colour.
    static func palette(for kind: CritterKind) -> [Int]? {
        switch kind {
        case .butterfly: return [1, 4, 5]   // blue, green, purple
        case .ladybug: return [0, 3, 2]     // red, orange, yellow
        default: return nil
        }
    }

    /// The animal that owns a colour (the brush that has it in its palette), if any.
    static func owner(of index: Int) -> CritterKind? {
        [CritterKind.butterfly, .ladybug].first { palette(for: $0)?.contains(index) == true }
    }

    /// The order the paint pots stand in: the butterfly's colours, then the ladybug's.
    static let potOrder: [Int] = [1, 4, 5, 0, 3, 2]
}

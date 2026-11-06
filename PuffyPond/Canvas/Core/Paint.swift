import simd

enum Paint {
    /// The six paint colours, each the mid tone of its NCA texture (tools/nca/targets/), so a pot, an animal and its paint match.
    /// The order matches the NCA model file (PuffyPond/NCA/nca.bin) and keeps the old palette's roles
    /// (templates and animals refer to colours by index: 0 warm, 1 cool, 2 light, 3 orange, 4 green, 5 purple).
    static let colors: [SIMD3<Float>] = [
        SIMD3(0.97, 0.38, 0.40), // red      (ladybug)
        SIMD3(0.36, 0.64, 0.89), // blue     (butterfly)
        SIMD3(0.97, 0.82, 0.10), // yellow
        SIMD3(0.99, 0.55, 0.12), // orange  (snail)
        SIMD3(0.08, 0.66, 0.35), // green   (frog)
        SIMD3(0.54, 0.42, 0.77), // purple
    ]
}

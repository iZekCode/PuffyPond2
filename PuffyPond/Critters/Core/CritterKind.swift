import simd

/// The garden cast: the characters that carry the paint tools. The raw values are written into saved timelapse
/// recordings, so they stay put when a character is removed.
enum CritterKind: Int, CaseIterable, Equatable {
    case snail = 1
    case ladybug = 7, butterfly = 8, mushroom = 9

    /// The cast in tool-column order (butterfly brush, ladybug brush, eraser, blender).
    static let gardenCast: [CritterKind] = [.butterfly, .ladybug, .mushroom, .snail]

    /// Its own color while it waits in a critter bubble.
    var signatureColor: SIMD3<Float> {
        switch self {
        case .snail: return Paint.colors[2]
        case .ladybug: return Paint.colors[0]
        case .butterfly: return Paint.colors[1]
        case .mushroom: return SIMD3(0.98, 0.53, 0.72)
        }
    }
}

/// One paint dab a critter lays this frame.
struct BrushDab {
    var from: SIMD2<Float>
    var to: SIMD2<Float>
    var radius: Float
    var speed: Float
    var style: BrushStyle = .brush
    /// How far the brush moved this frame, when that isn't `to - from` (a leg lying on the canvas).
    var drag: SIMD2<Float>? = nil
}

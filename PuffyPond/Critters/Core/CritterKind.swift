import simd

/// The garden cast: the characters that carry the paint tools. The raw values are written into saved timelapse
/// recordings, so they stay put when a character is removed.
enum CritterKind: Int, CaseIterable, Equatable {
    case snail = 1
    case ladybug = 7, butterfly = 8, frog = 10

    /// The cast along the bottom of the canvas, left to right. One character, one colour.
    static let gardenCast: [CritterKind] = [.ladybug, .butterfly, .frog, .snail]

    /// Its own colour: the only paint it ever lays.
    var signatureColor: SIMD3<Float> {
        switch self {
        case .ladybug: return Paint.colors[0]      // red
        case .butterfly: return Paint.colors[1]    // blue
        case .frog: return Paint.colors[4]         // green
        case .snail: return Paint.colors[3]        // orange
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

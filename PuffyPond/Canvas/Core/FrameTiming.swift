import Foundation

/// Per-frame numbers of the easel's loop that only depend on time.
enum FrameTiming {
    /// Frame time kept between 1/240 s and 1/20 s, so a hitch never makes the springs jump.
    static func clampedDT(_ raw: Float) -> Float { min(max(raw, 1.0 / 240.0), 1.0 / 20.0) }

    /// 1 right on the beat, fading fast until the next one.
    static func beatPulse(beat: Double) -> Float {
        exp(-Float(beat - beat.rounded(.down)) * 6)
    }

    /// The music's energy eases toward how much the hands move (`movement` 3 or more is full energy).
    static func energy(_ energy: Float, movement: Float, dt: Float) -> Float {
        energy + (min(movement / 3, 1) - energy) * min(1, dt * 1.5)
    }
}

import Foundation
import QuartzCore
import simd

/// Logs every paint dab and erase of a session, for the timelapse. It runs on every painting frame, so it does
/// nothing beyond building a value and appending it.
final class TimelapseRecorder {
    private let clock: () -> Double
    private var recording = StrokeRecording()
    private var start: Double?
    private var lastErase: (t: Double, center: SIMD2<Float>)?
    /// Scrubbing time of the erases that were skipped, carried into the next one kept: how hard an erase scrubs
    /// depends on its `dt`, so a replay must not erase more gently than the eraser did.
    private var skippedEraseTime: Float = 0

    init(clock: @escaping () -> Double = CACurrentMediaTime) {
        self.clock = clock
    }

    /// The same arguments `Playground.lay` gives `PaintLayer.stamp`: dab k gets `seed + k * 5.1`, the stroke shares `seed`.
    func record(dabs: [BrushDab], color: SIMD3<Float>, ncaModel: Int, seed: Float, brush: CritterKind) {
        guard !dabs.isEmpty else { return }
        let t = elapsed()
        for (k, dab) in dabs.enumerated() {
            recording.append(.dab(RecordedDab(t: t, from: dab.from, to: dab.to, radius: dab.radius, speed: dab.speed,
                                              color: color, seed: seed + Float(k) * 5.1, strokeSeed: seed,
                                              style: dab.style, drag: dab.drag, ncaModel: ncaModel, brush: brush)))
        }
    }

    /// An eraser held on one spot reports every frame; only a sound's worth of it is kept: a new erase must be a
    /// tenth of a second after the last one, or move half a brush away.
    func recordErase(at center: SIMD2<Float>, radius: Float, dt: Float) {
        let t = elapsed()
        if let last = lastErase, t - last.t < 0.1, simd_distance(center, last.center) < radius * 0.5 {
            skippedEraseTime += dt
            return
        }
        lastErase = (t, center)
        recording.append(.erase(RecordedErase(t: t, center: center, radius: radius, dt: dt + skippedEraseTime)))
        skippedEraseTime = 0
    }

    func reset() {
        recording = StrokeRecording()
        start = nil
        lastErase = nil
        skippedEraseTime = 0
    }

    /// A copy of everything recorded so far; nil when nothing was.
    func snapshot() -> StrokeRecording? {
        recording.isEmpty ? nil : recording
    }

    private func elapsed() -> Double {
        let now = clock()
        let origin = start ?? now
        start = origin
        return now - origin
    }
}

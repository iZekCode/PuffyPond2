import Foundation
import Testing
import simd
@testable import PuffyPond

@MainActor
struct SessionRecorderTests {
    private let frameTime = 1.0 / 30

    private func hand(slot: Int, pose: HandPose, painting: Bool = false,
                      canvas: SIMD2<Float>? = SIMD2(0.5, 0.5)) -> SessionRecorder.Hand {
        SessionRecorder.Hand(slot: slot, pose: pose, painting: painting, canvas: canvas)
    }

    /// A body in a square image, shoulders at y 0.4. The image-right arm is posed by `elbow` / `wrist`;
    /// the other arm hangs down.
    private func body(elbow: SIMD2<Float>, wrist: SIMD2<Float>? = nil, confidence: Float = 0.9,
                      hips: Bool = true) -> BodyFrame {
        var points = [BodyPoint?](repeating: nil, count: BodyJoint.allCases.count)
        func put(_ joint: BodyJoint, _ p: SIMD2<Float>, _ c: Float = 0.9) {
            points[joint.rawValue] = BodyPoint(location: p, confidence: c)
        }
        // Vision's labels don't matter: sides come from where the shoulders sit in the image.
        put(.leftShoulder, SIMD2(0.4, 0.4))
        put(.rightShoulder, SIMD2(0.6, 0.4))
        put(.leftElbow, SIMD2(0.4, 0.55))
        put(.leftWrist, SIMD2(0.4, 0.7))
        put(.rightElbow, elbow, confidence)
        put(.rightWrist, wrist ?? elbow + (elbow - SIMD2(0.6, 0.4)), confidence)
        if hips {
            put(.leftHip, SIMD2(0.42, 0.75))
            put(.rightHip, SIMD2(0.58, 0.75))
        }
        return BodyFrame(points: points, imageAspect: 1)
    }

    /// The image-right arm raised `degrees` out to the side (0 = hanging down, 90 = horizontal).
    private func raised(_ degrees: Double) -> BodyFrame {
        let a = Float(degrees * .pi / 180)
        return body(elbow: SIMD2(0.6, 0.4) + SIMD2(sin(a), cos(a)) * 0.15, hips: false)
    }

    private func feed(_ recorder: inout SessionRecorder, _ frames: [BodyFrame], from start: Double = 0) -> Double {
        var t = start
        for frame in frames {
            recorder.record(body: frame, at: t)
            t += frameTime
        }
        return t
    }

    @Test func dominanceUsesPersonSides() {
        // Mirrored preview: the hand on the right of the screen is the person's right hand.
        var mirrored = SessionRecorder(mirrored: true)
        for _ in 0..<30 {
            mirrored.record(hands: [hand(slot: 1, pose: .fist, painting: true),
                                    hand(slot: 0, pose: .open)], dt: frameTime)
        }
        let stats = mirrored.finish()
        #expect(abs((stats?.pinchSeconds[.right] ?? 0) - 1) < 0.01)
        #expect((stats?.pinchSeconds[.left] ?? 0) == 0)

        // A plain (unmirrored) camera image shows the person's right hand on the left.
        var plain = SessionRecorder(mirrored: false)
        for _ in 0..<30 { plain.record(hands: [hand(slot: 1, pose: .fist, painting: true)], dt: frameTime) }
        #expect(abs((plain.finish()?.pinchSeconds[.left] ?? 0) - 1) < 0.01)

        // Body joints follow the same rule, whatever Vision calls them.
        var arms = SessionRecorder(mirrored: true)
        _ = feed(&arms, Array(repeating: raised(90), count: 15))
        #expect(arms.finish()?.romDegrees[.right] != nil)
        #expect((arms.finish()?.romDegrees[.left] ?? 0) < 10)
    }

    @Test func heatmapCountsOnlyFistOnCanvas() {
        var recorder = SessionRecorder(mirrored: true)
        for _ in 0..<10 {
            recorder.record(hands: [hand(slot: 0, pose: .fist, painting: true, canvas: SIMD2(0.01, 0.01)),
                                    hand(slot: 1, pose: .open, painting: false, canvas: SIMD2(0.99, 0.99))],
                            dt: 0.1)
            recorder.record(hands: [hand(slot: 1, pose: .fist, painting: false, canvas: nil)], dt: 0.1)
        }
        let heatmap = recorder.finish()?.heatmap ?? []
        #expect(heatmap.count == SessionStats.heatmapColumns * SessionStats.heatmapRows)
        #expect(heatmap[0] == 100)                     // 1 s in the top-left cell, in hundredths
        #expect(heatmap.reduce(0) { $0 + Int($1) } == 100)
    }

    @Test func romTakesMaxAngle() {
        var recorder = SessionRecorder(mirrored: true)
        var frames: [BodyFrame] = []
        for degrees in stride(from: 30.0, through: 120, by: 10) { frames += Array(repeating: raised(degrees), count: 3) }
        frames += Array(repeating: raised(120), count: 15)
        for degrees in stride(from: 110.0, through: 60, by: -10) { frames += Array(repeating: raised(degrees), count: 3) }
        _ = feed(&recorder, frames)
        let rom = recorder.finish()?.romDegrees[.right] ?? 0
        #expect(abs(rom - 120) < 1)
    }

    @Test func romAngleOfHorizontalArmIs90() {
        var recorder = SessionRecorder(mirrored: true)
        // With hips: the trunk runs from the shoulder down to the hip.
        let withHips = body(elbow: SIMD2(0.75, 0.4))
        _ = feed(&recorder, Array(repeating: withHips, count: 15))
        let stats = recorder.finish()
        #expect(abs((stats?.romDegrees[.right] ?? 0) - 90) < 4)
        #expect(abs((stats?.elbowExtension[.right] ?? 0) - 180) < 1)
        #expect(abs(stats?.reachHeight[.right] ?? 1) < 0.01)

        // Without hips: perpendicular to the shoulder line.
        var noHips = SessionRecorder(mirrored: true)
        _ = feed(&noHips, Array(repeating: raised(90), count: 15))
        #expect(abs((noHips.finish()?.romDegrees[.right] ?? 0) - 90) < 0.5)
    }

    @Test func lowConfidenceJointsIgnored() {
        var recorder = SessionRecorder(mirrored: true)
        _ = feed(&recorder, Array(repeating: body(elbow: SIMD2(0.6, 0.25), confidence: 0.4), count: 15))
        #expect(recorder.finish()?.romDegrees[.right] == nil)
    }

    @Test func singleFrameSpikeIgnored() {
        var recorder = SessionRecorder(mirrored: true)
        var frames = Array(repeating: raised(45), count: 10)
        frames.append(raised(170))
        frames += Array(repeating: raised(45), count: 10)
        _ = feed(&recorder, frames)
        #expect(abs((recorder.finish()?.romDegrees[.right] ?? 0) - 45) < 0.5)
    }

    @Test func gripCycleCountsFistOpenPairs() {
        var recorder = SessionRecorder(mirrored: true)
        // open → fist → open → fist → pinch (counts as open) → fist: two full cycles, one still closed.
        for pose in [HandPose.open, .fist, .fist, .open, .fist, .pinch, .fist] {
            recorder.record(hands: [hand(slot: 0, pose: pose)], dt: frameTime)
        }
        #expect(recorder.finish()?.gripCycles[.left] == 2)
        #expect(recorder.finish()?.gripCycles[.right] == nil)
    }

    @Test func touchOnlySessionHasNoStats() {
        var recorder = SessionRecorder(mirrored: true)
        for _ in 0..<30 { recorder.record(hands: [], dt: frameTime) }
        #expect(recorder.finish() == nil)
    }

    @Test func statsSavedBeforeNewMetricsStillDecode() throws {
        let old = #"{"duration":12,"romDegrees":{"left":80},"heatmap":[],"pinchSeconds":{"right":3}}"#
        let stats = try JSONDecoder().decode(SessionStats.self, from: Data(old.utf8))
        #expect(stats.duration == 12)
        #expect(stats.romDegrees[.left] == 80)
        #expect(stats.gripCycles.isEmpty)
        #expect(stats.maxTrunkLean == 0)
    }
}

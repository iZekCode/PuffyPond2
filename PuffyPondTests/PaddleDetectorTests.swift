import Foundation
import Testing
import simd
@testable import PuffyPond

@MainActor
struct PaddleDetectorTests {
    private let dt = 1.0 / 30

    private func hand(_ slot: Int, _ pose: HandPose, _ p: SIMD2<Float>, tracking: Bool = true) -> HandState {
        HandState(slot: slot, pose: pose, position: p, velocity: .zero, tracking: tracking)
    }

    /// Moves one hand from `from` to `to` over `seconds`, starting at `start`, and collects the strokes.
    private func sweep(_ detector: inout PaddleDetector, slot: Int = 1, pose: HandPose = .open,
                       from: SIMD2<Float>, to: SIMD2<Float>, seconds: Double, start: Double = 0) -> [PaddleDetector.Stroke] {
        let frames = Int(seconds / dt)
        var strokes: [PaddleDetector.Stroke] = []
        for f in 0...frames {
            let t = Float(f) / Float(frames)
            if let stroke = detector.feed([hand(slot, pose, from + (to - from) * t)], now: start + Double(f) * dt) {
                strokes.append(stroke)
            }
        }
        return strokes
    }

    @Test func downSweepOnRightIsNext() {
        var detector = PaddleDetector()
        let strokes = sweep(&detector, from: SIMD2(0.75, 0.3), to: SIMD2(0.7, 0.7), seconds: 0.4)
        #expect(strokes == [.next])
    }

    @Test func downSweepOnLeftIsPrevious() {
        var detector = PaddleDetector()
        let strokes = sweep(&detector, slot: 0, from: SIMD2(0.25, 0.3), to: SIMD2(0.3, 0.7), seconds: 0.4)
        #expect(strokes == [.previous])
    }

    @Test func slowDriftIsIgnored() {
        var detector = PaddleDetector()
        let strokes = sweep(&detector, from: SIMD2(0.75, 0.2), to: SIMD2(0.75, 0.8), seconds: 3)
        #expect(strokes.isEmpty)
    }

    @Test func upSweepIsIgnored() {
        var detector = PaddleDetector()
        let strokes = sweep(&detector, from: SIMD2(0.75, 0.7), to: SIMD2(0.75, 0.3), seconds: 0.4)
        #expect(strokes.isEmpty)
    }

    @Test func fistSweepIsIgnored() {
        var detector = PaddleDetector()
        let strokes = sweep(&detector, pose: .fist, from: SIMD2(0.75, 0.3), to: SIMD2(0.75, 0.7), seconds: 0.4)
        #expect(strokes.isEmpty)
    }

    @Test func cooldownBlocksDoubleTrigger() {
        var detector = PaddleDetector()
        var strokes = sweep(&detector, from: SIMD2(0.75, 0.2), to: SIMD2(0.75, 0.6), seconds: 0.3)
        // The hand comes back up and paddles again right away: still inside the cooldown.
        strokes += sweep(&detector, from: SIMD2(0.75, 0.6), to: SIMD2(0.75, 0.2), seconds: 0.1, start: 0.33)
        strokes += sweep(&detector, from: SIMD2(0.75, 0.2), to: SIMD2(0.75, 0.6), seconds: 0.15, start: 0.46)
        #expect(strokes == [.next])
        // After the cooldown the next stroke counts.
        strokes += sweep(&detector, from: SIMD2(0.75, 0.2), to: SIMD2(0.75, 0.6), seconds: 0.3, start: 1.5)
        #expect(strokes == [.next, .next])
    }

    @Test func lostTrackingForgetsTheSweep() {
        var detector = PaddleDetector()
        _ = detector.feed([hand(1, .open, SIMD2(0.75, 0.2))], now: 0)
        _ = detector.feed([hand(1, .open, SIMD2(0.75, 0.3), tracking: false)], now: 0.1)
        let stroke = detector.feed([hand(1, .open, SIMD2(0.75, 0.6))], now: 0.2)
        #expect(stroke == nil)
    }
}

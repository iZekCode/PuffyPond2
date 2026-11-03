import Foundation
import Testing
import simd
@testable import PuffyPond

@MainActor
struct SwipeDetectorTests {
    private let dt = 1.0 / 30

    private func hand(_ slot: Int, _ pose: HandPose, _ p: SIMD2<Float>, tracking: Bool = true) -> HandState {
        HandState(slot: slot, pose: pose, position: p, velocity: .zero, tracking: tracking)
    }

    /// Moves one hand from `from` to `to` over `seconds`, starting at `start`, and collects the swipes.
    private func sweep(_ detector: inout SwipeDetector, slot: Int = 1, pose: HandPose = .open,
                       from: SIMD2<Float>, to: SIMD2<Float>, seconds: Double, start: Double = 0) -> [SwipeDetector.Swipe] {
        let frames = Int(seconds / dt)
        var swipes: [SwipeDetector.Swipe] = []
        for f in 0...frames {
            let t = Float(f) / Float(frames)
            if let swipe = detector.feed([hand(slot, pose, from + (to - from) * t)], now: start + Double(f) * dt) {
                swipes.append(swipe)
            }
        }
        return swipes
    }

    @Test func leftSwipeIsNext() {
        var detector = SwipeDetector()
        let swipes = sweep(&detector, from: SIMD2(0.8, 0.5), to: SIMD2(0.4, 0.55), seconds: 0.4)
        #expect(swipes == [.next])
    }

    @Test func rightSwipeIsPrevious() {
        var detector = SwipeDetector()
        let swipes = sweep(&detector, slot: 0, from: SIMD2(0.2, 0.5), to: SIMD2(0.6, 0.45), seconds: 0.4)
        #expect(swipes == [.previous])
    }

    @Test func slowDriftIsIgnored() {
        var detector = SwipeDetector()
        let swipes = sweep(&detector, from: SIMD2(0.9, 0.5), to: SIMD2(0.1, 0.5), seconds: 4)
        #expect(swipes.isEmpty)
    }

    @Test func verticalSweepIsIgnored() {
        var detector = SwipeDetector()
        let swipes = sweep(&detector, from: SIMD2(0.75, 0.2), to: SIMD2(0.7, 0.7), seconds: 0.4)
        #expect(swipes.isEmpty)
    }

    @Test func diagonalSweepIsIgnored() {
        var detector = SwipeDetector()
        let swipes = sweep(&detector, from: SIMD2(0.8, 0.2), to: SIMD2(0.45, 0.6), seconds: 0.4)
        #expect(swipes.isEmpty)
    }

    @Test func fistSwipeIsIgnored() {
        var detector = SwipeDetector()
        let swipes = sweep(&detector, pose: .fist, from: SIMD2(0.8, 0.5), to: SIMD2(0.4, 0.5), seconds: 0.4)
        #expect(swipes.isEmpty)
    }

    @Test func cooldownBlocksTheReturnStroke() {
        var detector = SwipeDetector()
        var swipes = sweep(&detector, from: SIMD2(0.8, 0.5), to: SIMD2(0.4, 0.5), seconds: 0.3)
        // The hand comes back right away: still inside the cooldown, so it doesn't walk the other way.
        swipes += sweep(&detector, from: SIMD2(0.4, 0.5), to: SIMD2(0.8, 0.5), seconds: 0.3, start: 0.33)
        #expect(swipes == [.next])
        // After the cooldown the next swipe counts.
        swipes += sweep(&detector, from: SIMD2(0.8, 0.5), to: SIMD2(0.4, 0.5), seconds: 0.3, start: 1.5)
        #expect(swipes == [.next, .next])
    }

    @Test func lostTrackingForgetsTheSwipe() {
        var detector = SwipeDetector()
        _ = detector.feed([hand(1, .open, SIMD2(0.8, 0.5))], now: 0)
        _ = detector.feed([hand(1, .open, SIMD2(0.7, 0.5), tracking: false)], now: 0.1)
        let swipe = detector.feed([hand(1, .open, SIMD2(0.4, 0.5))], now: 0.2)
        #expect(swipe == nil)
    }
}

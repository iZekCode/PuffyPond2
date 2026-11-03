import simd

/// Turns an open palm swiping sideways through the air into "walk to the next painting" (swipe left,
/// like turning a page) or "walk back" (swipe right). Slow drifts, fists and mostly-vertical moves are
/// ignored, and a short cooldown keeps one swipe, and the hand coming back, from counting twice.
struct SwipeDetector {
    enum Swipe: Equatable {
        case next
        case previous
    }

    /// How far across the hand must travel, as a share of the view width.
    static let minTravel: Float = 0.3
    /// Seconds the travel must happen in.
    static let window = 0.7
    /// The sideways travel must be at least this many times the up-and-down travel.
    static let straightness: Float = 1.8
    /// Seconds after a swipe in which no other swipe counts.
    static let cooldown = 0.7

    private struct Sample {
        var time: Double
        var position: SIMD2<Float>
    }

    private var history: [Int: [Sample]] = [:]
    private var cooldownUntil = -Double.infinity

    /// Feeds this frame's hands (view UV, y down). Returns a swipe when one just finished.
    mutating func feed(_ hands: [HandState], now: Double) -> Swipe? {
        let open = hands.filter { $0.tracking && $0.pose == .open && !$0.isPointer }
        // Hands that closed or left the camera start over.
        for slot in history.keys where !open.contains(where: { $0.slot == slot }) { history[slot] = nil }
        guard now >= cooldownUntil else {
            history.removeAll()
            return nil
        }

        for hand in open {
            var samples = history[hand.slot, default: []]
            samples.append(Sample(time: now, position: hand.position))
            samples.removeAll { now - $0.time > Self.window }
            history[hand.slot] = samples

            // The furthest point back in the window on either side, and how far across the hand is now.
            if let swipe = Self.swipe(ending: hand.position, after: samples) {
                history.removeAll()
                cooldownUntil = now + Self.cooldown
                return swipe
            }
        }
        return nil
    }

    private static func swipe(ending end: SIMD2<Float>, after samples: [Sample]) -> Swipe? {
        func straight(from origin: Sample, travel: Float) -> Bool {
            travel >= minTravel && abs(end.y - origin.position.y) * straightness <= travel
        }
        if let right = samples.max(by: { $0.position.x < $1.position.x }),
           straight(from: right, travel: right.position.x - end.x) {
            return .next
        }
        if let left = samples.min(by: { $0.position.x < $1.position.x }),
           straight(from: left, travel: end.x - left.position.x) {
            return .previous
        }
        return nil
    }

    mutating func reset() {
        history.removeAll()
        cooldownUntil = -Double.infinity
    }
}

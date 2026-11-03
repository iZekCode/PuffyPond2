import simd

/// Turns an open hand sweeping down through the air, like a paddle in water, into "walk to the next
/// painting" (stroke on the right half of the view) or "walk back" (left half). Slow drifts, fists and
/// upward moves are ignored, and a short cooldown keeps one stroke from counting twice.
struct PaddleDetector {
    enum Stroke: Equatable {
        case next
        case previous
    }

    /// How far down the hand must travel, as a share of the view height.
    static let minDrop: Float = 0.25
    /// Seconds the drop must happen in.
    static let window = 0.8
    /// Seconds after a stroke in which no other stroke counts.
    static let cooldown = 0.6

    private struct Sample {
        var time: Double
        var position: SIMD2<Float>
    }

    private var history: [Int: [Sample]] = [:]
    private var cooldownUntil = -Double.infinity

    /// Feeds this frame's hands (view UV, y down). Returns a stroke when one just finished.
    mutating func feed(_ hands: [HandState], now: Double) -> Stroke? {
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

            // The highest point in the window, and how far below it the hand is now.
            guard let top = samples.min(by: { $0.position.y < $1.position.y }),
                  hand.position.y - top.position.y >= Self.minDrop else { continue }
            let side = (top.position.x + hand.position.x) / 2
            history.removeAll()
            cooldownUntil = now + Self.cooldown
            return side >= 0.5 ? .next : .previous
        }
        return nil
    }

    mutating func reset() {
        history.removeAll()
        cooldownUntil = -Double.infinity
    }
}

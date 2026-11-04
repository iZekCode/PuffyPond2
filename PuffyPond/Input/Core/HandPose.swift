import simd

/// Big, forgiving poses only — no fiddly finger gestures.
enum HandPose: Equatable {
    case open   // the character moves along with you (and can dip into paint pots)
    case fist   // paints with the current tool
}

/// One hand as the game sees it, in view UV (0…1, y down).
struct HandState {
    var slot: Int            // 0 = left side of the screen, 1 = right
    var pose: HandPose
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var tracking: Bool
    var isPointer = false

    /// The mouse or finger as the left hand: always a fist, so it paints with the left buddy's tool.
    static func pointer(at p: SIMD2<Float>, previous: SIMD2<Float>, dt: Float) -> HandState {
        HandState(slot: 0, pose: .fist, position: p, velocity: (p - previous) / dt, tracking: true, isPointer: true)
    }
}

/// Palm-level reading of one Vision observation.
struct PalmReading {
    var palm: SIMD2<Float>
    var extendedFingers: Int

    init(palm: SIMD2<Float>, extendedFingers: Int) {
        self.palm = palm
        self.extendedFingers = extendedFingers
    }
}

/// Turns each frame's finger reading into a steady pose, with hysteresis so it doesn't flicker.
struct PoseFilter {
    private(set) var pose: HandPose
    private var candidateFrames = 0

    init(pose: HandPose) { self.pose = pose }

    mutating func feed(_ reading: PalmReading) {
        // The fist paints, so it holds on: a loose fist (one finger creeping out) or one noisy
        // frame keeps painting.
        let raw: HandPose
        if pose == .fist {
            raw = reading.extendedFingers >= 2 ? .open : .fist
        } else {
            raw = reading.extendedFingers == 0 ? .fist : .open
        }
        let needed = raw == .fist ? 2 : 3
        if raw != pose {
            candidateFrames += 1
            if candidateFrames >= needed {
                pose = raw
                candidateFrames = 0
            }
        } else {
            candidateFrames = 0
        }
    }
}

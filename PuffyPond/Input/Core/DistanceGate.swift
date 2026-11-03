import Foundation

/// Decides when the person is standing at the right distance to paint, from their shoulder width in
/// the camera image. Pure: feed it one reading per frame with a timestamp.
nonisolated struct DistanceGate {
    enum State: Equatable {
        case noPerson, tooClose, tooFar, offCenter
        /// In the band; `progress` runs 0...1 up to `holdDuration`.
        case holding(progress: Double)
        case ready
    }

    /// Shoulder width as a fraction of the image width. About 0.17 at 1 m on an iPad front camera:
    /// a 0.40 m shoulder span in a view about 2.4 m wide at that distance. An estimate from the
    /// camera's field of view, not yet measured on a device; adjust the band if it feels off.
    static let nearWidth: Float = 0.22
    static let farWidth: Float = 0.13
    /// How far the shoulder midpoint may sit from the image center (0.5), as a fraction of the width.
    static let centerTolerance: Float = 0.18
    /// How long the person must stay in the band before the page moves on.
    static let holdDuration: TimeInterval = 1.5
    /// A lost detection shorter than this keeps the hold running.
    static let dropoutGrace: TimeInterval = 0.3

    private var holdStart: TimeInterval?
    private var lastSeen: TimeInterval?
    private var lastState: State = .noPerson

    mutating func update(shoulderWidth: Float?, centerX: Float?, at time: TimeInterval) -> State {
        guard let width = shoulderWidth, let centerX else {
            if let lastSeen, time - lastSeen <= Self.dropoutGrace { return lastState }
            return set(.noPerson, holdStart: nil)
        }
        lastSeen = time

        if width < Self.farWidth { return set(.tooFar, holdStart: nil) }
        if width > Self.nearWidth { return set(.tooClose, holdStart: nil) }
        if abs(centerX - 0.5) > Self.centerTolerance { return set(.offCenter, holdStart: nil) }

        let start = holdStart ?? time
        let elapsed = time - start
        return set(elapsed >= Self.holdDuration ? .ready : .holding(progress: elapsed / Self.holdDuration),
                   holdStart: start)
    }

    private mutating func set(_ state: State, holdStart: TimeInterval?) -> State {
        self.holdStart = holdStart
        lastState = state
        return state
    }
}

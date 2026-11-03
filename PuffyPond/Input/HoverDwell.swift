import CoreGraphics

/// An on-screen button an open hand can hover over and hold to press, in view UV (0…1, y down).
struct HoverTarget: Equatable {
    var id: String
    var frame: CGRect
}

/// Hover-and-hold: an open hand resting on a button for a second presses it, once, until the hand leaves.
struct HoverDwell {
    /// Seconds an open hand rests on a button to press it.
    static let duration = 1.0

    /// The ring: which button is filling and how far (0…1); nil while idle or just after a press.
    private(set) var progress: (id: String, value: Double)?
    private var time = 0.0
    private var latched: String?

    /// `hoveredID`: the button an open hand is over, or nil. Returns the id when a full hold completes.
    mutating func update(hoveredID: String?, dt: Double) -> String? {
        guard let id = hoveredID else {
            time = 0
            latched = nil
            progress = nil
            return nil
        }
        if latched == id { return nil }
        latched = nil
        if progress?.id != id { time = 0 }
        time += dt
        if time + 1e-9 >= Self.duration {
            latched = id
            time = 0
            progress = nil
            return id
        }
        progress = (id, time / Self.duration)
        return nil
    }
}

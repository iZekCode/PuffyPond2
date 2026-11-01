/// Passes camera hand frames to whichever page outside the canvas is listening (the review page now,
/// the gallery later). The canvas gets its frames from `Playground` directly.
final class HandFrameRelay {
    var listener: ((HandFrame) -> Void)?

    func send(_ frame: HandFrame) { listener?(frame) }
}

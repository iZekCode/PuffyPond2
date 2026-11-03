/// Passes camera hand frames to whichever page outside the canvas is listening (the review page and
/// the 3D gallery). The canvas gets its frames from `Playground` directly.
///
/// A fading page's `onDisappear` runs after the next page's `onAppear`, so a page may only drop the
/// listener it installed itself, or it would silence the page that just took over.
final class HandFrameRelay {
    private var owner: AnyObject?
    private var listener: ((HandFrame) -> Void)?

    func listen(owner: AnyObject, _ listener: @escaping (HandFrame) -> Void) {
        self.owner = owner
        self.listener = listener
    }

    /// Drops the listener only if `owner` still holds it.
    func stopListening(owner: AnyObject) {
        guard self.owner === owner else { return }
        self.owner = nil
        listener = nil
    }

    func send(_ frame: HandFrame) { listener?(frame) }
}

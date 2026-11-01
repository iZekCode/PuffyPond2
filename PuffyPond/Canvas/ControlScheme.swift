/// How hand poses turn into painting on the easel.
enum ControlScheme: Equatable {
    /// Open hand moves the character, fist paints with its tool. Pinch counts as open.
    case fist
    /// The original controls: pinch paints with one of six brush animals, fist turns into the starfish.
    case legacy

    /// What a hand's buddy does for this pose (nil = no hand).
    func mode(for pose: HandPose?, tool: PaintTool) -> BuddyMode {
        guard let pose else { return .idle }
        switch self {
        case .legacy:
            switch pose {
            case .open: return .swim
            case .pinch: return .paint
            case .fist: return .erase
            }
        case .fist:
            switch pose {
            case .open, .pinch: return .swim
            case .fist: return tool == .eraser ? .erase : .paint
            }
        }
    }
}

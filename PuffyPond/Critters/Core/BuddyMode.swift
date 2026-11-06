enum BuddyMode: Equatable {
    case idle, roam, paint

    /// What a hand's buddy does for this pose (idle = no hand): an open hand moves it, a fist paints.
    static func mode(for pose: HandPose?) -> BuddyMode {
        guard let pose else { return .idle }
        switch pose {
        case .open: return .roam
        case .fist: return .paint
        }
    }
}

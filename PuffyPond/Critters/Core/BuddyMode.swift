enum BuddyMode: Equatable {
    case idle, roam, paint, erase

    /// What a hand's buddy does for this pose (idle = no hand): an open hand moves it, a fist paints with its tool.
    static func mode(for pose: HandPose?, tool: PaintTool) -> BuddyMode {
        guard let pose else { return .idle }
        switch pose {
        case .open: return .roam
        case .fist: return tool == .eraser ? .erase : .paint
        }
    }
}

/// What a buddy is rubbing: a paint pot (new color) or a tool bubble (new paint tool).
enum PotTarget: Equatable {
    case color(Int)
    case tool(PaintTool)
}

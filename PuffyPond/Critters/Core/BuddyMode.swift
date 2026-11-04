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

    /// How much one frame of rubbing fills the pot's progress (1 = picked). Slow animals (the snail) can't rub
    /// fast, so just sitting in the pot counts for a lot too.
    static func rubGain(dt: Float, speed: Float) -> Float {
        dt * 0.9 + min(speed, 3) * dt * 0.9
    }
}

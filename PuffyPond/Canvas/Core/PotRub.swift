import simd

/// Rubbing a buddy in a paint pot (new colour) or a critter bubble (new paint tool). The longer and faster it
/// rubs, the fuller the pot's progress; at 1 the buddy picks it up.
enum PotRub {
    /// A paint pot or a critter bubble, where it stands right now.
    struct Pot: Equatable {
        let target: PotTarget
        let position: SIMD3<Float>
    }

    /// The buddy doing the rubbing.
    struct Rubber {
        /// Idle buddies (no hand) never rub. The eraser is a critter like any other, so it can dip into pots and
        /// bubbles while it erases (a mouse or finger is always "fist", so the mushroom would otherwise be stuck).
        var idle: Bool
        var position: SIMD2<Float>
        var colorIndex: Int
        var tool: PaintTool
        var speed: Float
    }

    /// One frame of rubbing.
    struct Step: Equatable {
        /// What the buddy is rubbing after this frame, and how far along it is.
        var target: PotTarget?
        var amount: Float
        /// The pot it is in this frame; nil when it is in none (or already wears what that pot gives).
        var pot: Pot?
        /// It just started rubbing this pot.
        var started = false
        /// Progress this frame, 0…1.
        var progress: Float = 0
        /// It finished rubbing: the buddy takes what the pot gives.
        var picked = false
    }

    /// `colorPots` are checked before `toolPots`. Within a column only the first pot under the buddy counts, even
    /// when it gives what the buddy already has.
    static func step(target: PotTarget?, amount: Float, rubber: Rubber, colorPots: [Pot], toolPots: [Pot],
                     dt: Float) -> Step {
        guard !rubber.idle, let pot = pot(under: rubber, colorPots: colorPots, toolPots: toolPots) else {
            return Step(target: nil, amount: 0)
        }
        var step = Step(target: target, amount: amount, pot: pot)
        if target != pot.target {
            step.target = pot.target
            step.amount = 0
            step.started = true
        }
        step.amount += PotTarget.rubGain(dt: dt, speed: rubber.speed)
        step.progress = min(step.amount, 1)
        if step.progress >= 1 {
            step.target = nil
            step.amount = 0
            step.picked = true
        }
        return step
    }

    private static func pot(under rubber: Rubber, colorPots: [Pot], toolPots: [Pot]) -> Pot? {
        if let pot = colorPots.first(where: { CanvasLayout.touches(rubber.position, potAt: $0.position) }),
           pot.target != .color(rubber.colorIndex) {
            return pot
        }
        if let pot = toolPots.first(where: { CanvasLayout.touches(rubber.position, potAt: $0.position, radius: CanvasLayout.bubbleRadius) }),
           pot.target != .tool(rubber.tool) {
            return pot
        }
        return nil
    }

    /// A colour belongs to one brush animal: a brush that dips into the other animal's colour becomes that animal.
    /// The tool to switch to, or nil to keep the current one.
    static func tool(afterPicking colorIndex: Int, tool: PaintTool, critter: CritterKind) -> PaintTool? {
        guard tool.usesColor, let owner = Paint.owner(of: colorIndex), owner != critter else { return nil }
        return PaintTool.allCases.first { $0.critterKind == owner }
    }

    /// How far along the fastest buddy rubbing `target` is (0 when nobody is).
    static func progress(of target: PotTarget, rubs: [(target: PotTarget?, amount: Float)]) -> Float {
        rubs.filter { $0.target == target }.map(\.amount).max() ?? 0
    }
}

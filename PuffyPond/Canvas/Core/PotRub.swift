import simd

/// Rubbing a buddy over a character waiting along the bottom of the canvas. The longer and faster it rubs, the
/// fuller the character's progress; at 1 the buddy turns into that character (and its colour).
enum PotRub {
    /// How much one frame of rubbing fills the progress (1 = picked). Slow animals (the snail) can't rub fast,
    /// so just sitting on the character counts for a lot too.
    static func rubGain(dt: Float, speed: Float) -> Float {
        dt * 0.9 + min(speed, 3) * dt * 0.9
    }

    /// A character waiting at the bottom, where it stands right now.
    struct Perch: Equatable {
        let tool: PaintTool
        let position: SIMD3<Float>
    }

    /// The buddy doing the rubbing.
    struct Rubber {
        /// Idle buddies (no hand) never rub.
        var idle: Bool
        var position: SIMD2<Float>
        var tool: PaintTool
        var speed: Float
    }

    /// One frame of rubbing.
    struct Step: Equatable {
        /// What the buddy is rubbing after this frame, and how far along it is.
        var target: PaintTool?
        var amount: Float
        /// The perch it is on this frame; nil when it is on none (or already is that character).
        var perch: Perch?
        /// It just started rubbing this character.
        var started = false
        /// Progress this frame, 0…1.
        var progress: Float = 0
        /// It finished rubbing: the buddy becomes that character.
        var picked = false
    }

    static func step(target: PaintTool?, amount: Float, rubber: Rubber, perches: [Perch], dt: Float) -> Step {
        guard !rubber.idle, let perch = perch(under: rubber, perches: perches) else {
            return Step(target: nil, amount: 0)
        }
        var step = Step(target: target, amount: amount, perch: perch)
        if target != perch.tool {
            step.target = perch.tool
            step.amount = 0
            step.started = true
        }
        step.amount += rubGain(dt: dt, speed: rubber.speed)
        step.progress = min(step.amount, 1)
        if step.progress >= 1 {
            step.target = nil
            step.amount = 0
            step.picked = true
        }
        return step
    }

    private static func perch(under rubber: Rubber, perches: [Perch]) -> Perch? {
        guard let perch = perches.first(where: {
            CanvasLayout.touches(rubber.position, characterAt: $0.position)
        }), perch.tool != rubber.tool else { return nil }
        return perch
    }

    /// How far along the fastest buddy rubbing `tool` is (0 when nobody is).
    static func progress(of tool: PaintTool, rubs: [(target: PaintTool?, amount: Float)]) -> Float {
        rubs.filter { $0.target == tool }.map(\.amount).max() ?? 0
    }
}

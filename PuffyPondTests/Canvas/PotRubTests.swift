import Testing
import simd
@testable import PuffyPond

@MainActor
struct PotRubTests {
    private let snail = PotRub.Perch(tool: .snail, position: SIMD3(-1, -1.6, CanvasLayout.characterZ))
    private let worm = PotRub.Perch(tool: .frog, position: SIMD3(1, -1.6, CanvasLayout.characterZ))

    private func rubber(at perch: PotRub.Perch?, tool: PaintTool = .ladybug, idle: Bool = false,
                        speed: Float = 0) -> PotRub.Rubber {
        let p = perch.map { SIMD2($0.position.x, $0.position.y) } ?? SIMD2(0, 1)
        return PotRub.Rubber(idle: idle, position: p, tool: tool, speed: speed)
    }

    private func step(_ rubber: PotRub.Rubber, target: PaintTool? = nil, amount: Float = 0, dt: Float = 0.1) -> PotRub.Step {
        PotRub.step(target: target, amount: amount, rubber: rubber, perches: [snail, worm], dt: dt)
    }

    @Test func enteringACharacterStartsRubbingIt() {
        let s = step(rubber(at: snail))
        #expect(s.started && s.target == .snail && s.perch == snail)
        #expect(s.amount > 0 && !s.picked)
    }

    @Test func movingFasterRubsFaster() {
        #expect(step(rubber(at: snail, speed: 3)).amount > step(rubber(at: snail)).amount)
    }

    @Test func switchingCharactersStartsOver() {
        let s = step(rubber(at: snail), target: .frog, amount: 0.8)
        #expect(s.started && s.amount < 0.8)
    }

    @Test func rubbingToTheEndPicks() {
        let s = step(rubber(at: snail), target: .snail, amount: 0.95)
        #expect(s.picked && s.progress == 1)
        #expect(s.target == nil && s.amount == 0 && s.perch == snail)
    }

    @Test func ownCharacterDoesNothing() {
        #expect(step(rubber(at: snail, tool: .snail)).perch == nil)
    }

    @Test func idleOrAwayStops() {
        #expect(step(rubber(at: snail, idle: true), target: .snail, amount: 0.5) == PotRub.Step(target: nil, amount: 0))
        #expect(step(rubber(at: nil), target: .snail, amount: 0.5) == PotRub.Step(target: nil, amount: 0))
    }

    @Test func progressIsTheFastestRubber() {
        let rubs: [(target: PaintTool?, amount: Float)] = [(.snail, 0.3), (.snail, 0.6), (.frog, 0.9), (nil, 0)]
        #expect(PotRub.progress(of: .snail, rubs: rubs) == 0.6)
        #expect(PotRub.progress(of: .butterfly, rubs: rubs) == 0)
    }

    @Test func pointerIsALeftFist() {
        let hand = HandState.pointer(at: SIMD2(0.5, 0.5), previous: SIMD2(0.4, 0.5), dt: 0.1)
        #expect(hand.slot == 0 && hand.pose == .fist && hand.isPointer && hand.tracking)
        #expect(abs(hand.velocity.x - 1) < 1e-5)
    }
}

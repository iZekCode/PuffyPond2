import Testing
import simd
@testable import PuffyPond

@MainActor
struct PotRubTests {
    private let red = PotRub.Pot(target: .color(0), position: SIMD3(CanvasLayout.shelfX, 0.5, 0.3))
    private let blue = PotRub.Pot(target: .color(1), position: SIMD3(CanvasLayout.shelfX, -0.5, 0.3))
    private let eraser = PotRub.Pot(target: .tool(.eraser), position: SIMD3(-CanvasLayout.shelfX, 0.5, 0.3))

    private func rubber(at pot: PotRub.Pot?, color: Int = 1, tool: PaintTool = .brush, idle: Bool = false,
                        speed: Float = 0) -> PotRub.Rubber {
        let p = pot.map { SIMD2($0.position.x, $0.position.y) } ?? .zero
        return PotRub.Rubber(idle: idle, position: p, colorIndex: color, tool: tool, speed: speed)
    }

    private func step(_ rubber: PotRub.Rubber, target: PotTarget? = nil, amount: Float = 0, dt: Float = 0.1) -> PotRub.Step {
        PotRub.step(target: target, amount: amount, rubber: rubber, colorPots: [red, blue], toolPots: [eraser], dt: dt)
    }

    @Test func enteringAPotStartsRubbingIt() {
        let s = step(rubber(at: red))
        #expect(s.started && s.target == .color(0) && s.pot == red)
        #expect(s.amount > 0 && !s.picked)
    }

    @Test func movingFasterRubsFaster() {
        #expect(step(rubber(at: red, speed: 3)).amount > step(rubber(at: red)).amount)
    }

    @Test func switchingPotsStartsOver() {
        let s = step(rubber(at: red), target: .color(5), amount: 0.8)
        #expect(s.started && s.amount < 0.8)
    }

    @Test func rubbingToTheEndPicks() {
        let s = step(rubber(at: red), target: .color(0), amount: 0.95)
        #expect(s.picked && s.progress == 1)
        #expect(s.target == nil && s.amount == 0 && s.pot == red)
    }

    @Test func ownColourAndOwnToolDoNothing() {
        #expect(step(rubber(at: red, color: 0)).pot == nil)
        #expect(step(rubber(at: eraser, tool: .eraser)).pot == nil)
    }

    @Test func idleOrAwayStops() {
        #expect(step(rubber(at: red, idle: true), target: .color(0), amount: 0.5) == PotRub.Step(target: nil, amount: 0))
        #expect(step(rubber(at: nil), target: .color(0), amount: 0.5) == PotRub.Step(target: nil, amount: 0))
    }

    @Test func bubblesWorkToo() {
        let s = step(rubber(at: eraser))
        #expect(s.target == .tool(.eraser) && s.pot == eraser)
    }

    @Test func dippingIntoTheOtherAnimalsColourSwitchesBrush() {
        let butterflyColour = Paint.palette(for: .butterfly)![0]
        let ladybugColour = Paint.palette(for: .ladybug)![0]
        #expect(PotRub.tool(afterPicking: butterflyColour, tool: .brush, critter: .ladybug) == .wingBrush)
        #expect(PotRub.tool(afterPicking: ladybugColour, tool: .brush, critter: .ladybug) == nil)
        #expect(PotRub.tool(afterPicking: butterflyColour, tool: .eraser, critter: .mushroom) == nil)
    }

    @Test func potProgressIsTheFastestRubber() {
        let rubs: [(target: PotTarget?, amount: Float)] = [(.color(0), 0.3), (.color(0), 0.6), (.color(1), 0.9), (nil, 0)]
        #expect(PotRub.progress(of: .color(0), rubs: rubs) == 0.6)
        #expect(PotRub.progress(of: .tool(.eraser), rubs: rubs) == 0)
    }

    @Test func pointerIsALeftFist() {
        let hand = HandState.pointer(at: SIMD2(0.5, 0.5), previous: SIMD2(0.4, 0.5), dt: 0.1)
        #expect(hand.slot == 0 && hand.pose == .fist && hand.isPointer && hand.tracking)
        #expect(abs(hand.velocity.x - 1) < 1e-5)
    }
}

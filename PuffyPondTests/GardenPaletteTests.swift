import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct GardenPaletteTests {
    private func makePlayground() -> Playground {
        let playground = Playground(controlScheme: .fist)
        playground.layout(size: CGSize(width: 1600, height: 1000))
        return playground
    }

    /// Parks the buddy's character on a pot or bubble and rubs it there until it takes.
    private func rub(_ playground: Playground, _ buddy: Buddy, at position: SIMD3<Float>, frames: Int = 240) {
        buddy.critter.position = Spring3(position)
        var now = 1000.0
        for _ in 0..<frames {
            playground.rubPots(buddy, dt: 1.0 / 60, now: now)
            now += 1.0 / 60
        }
    }

    // MARK: Palettes

    @Test func butterflyAndLadybugHaveTheirOwnColours() {
        let names = { (kind: CritterKind) in Paint.palette(for: kind)!.map { Paint.names[$0] } }
        #expect(names(.butterfly) == ["Blue", "Green", "Purple"])
        #expect(names(.ladybug) == ["Red", "Orange", "Yellow"])
        #expect(Paint.palette(for: .mushroom) == nil)
        #expect(Paint.palette(for: .octopus) == nil)
    }

    @Test func everyColourHasOneOwnerAndOnePot() {
        #expect(Set(Paint.potOrder) == Set(Paint.colors.indices))
        for index in Paint.colors.indices { #expect(Paint.owner(of: index) != nil) }
        let playground = makePlayground()
        #expect(playground.pots.map(\.colorIndex) == Paint.potOrder)
    }

    @Test func gardenBuddiesStartInTheirOwnColours() {
        let playground = makePlayground()
        for buddy in playground.buddies {
            #expect(Paint.palette(for: buddy.critter.kind)!.contains(buddy.colorIndex))
        }
    }

    @Test func butterflyPaintsWithTheTexturedBrushToo() {
        let dabs = PaintTool.wingBrush.dabs(from: .zero, to: SIMD2(0.1, 0), radius: 0.085, speed: 1)
        #expect(!dabs.isEmpty && dabs.allSatisfy { $0.style.nca == 1 })
    }

    @Test func switchingAnimalKeepsAColourItCanUse() {
        let buddy = Buddy(slot: 0, colorIndex: 0, kind: .ladybug, start: .zero, erasesWithStarfish: false)   // red
        _ = buddy.equip(.wingBrush)
        #expect(buddy.critter is Butterfly)
        #expect(buddy.colorIndex == Paint.palette(for: .butterfly)![0])   // red isn't a butterfly colour: first blue
        _ = buddy.equip(.eraser)
        _ = buddy.equip(.wingBrush)
        #expect(buddy.colorIndex == Paint.palette(for: .butterfly)![0])
        buddy.pick(5)   // purple
        _ = buddy.equip(.blender)
        _ = buddy.equip(.wingBrush)
        #expect(buddy.colorIndex == 5)
    }

    @Test func dippingInTheOtherAnimalsColourTurnsIntoThatAnimal() {
        let playground = makePlayground()
        let buddy = playground.buddies[0]
        #expect(buddy.critter is Ladybug)
        buddy.setMode(.swim)
        let blue = playground.pots.first { $0.colorIndex == 1 }!
        rub(playground, buddy, at: blue.root.simdPosition)
        #expect(buddy.colorIndex == 1)
        #expect(buddy.tool == .wingBrush)
        #expect(buddy.critter is Butterfly)

        let orange = playground.pots.first { $0.colorIndex == 3 }!
        rub(playground, buddy, at: orange.root.simdPosition)
        #expect(buddy.colorIndex == 3)
        #expect(buddy.tool == .brush)
        #expect(buddy.critter is Ladybug)
    }

    // MARK: Bug: the mushroom could not turn into anything else

    @Test func mushroomCanStillRubABubbleAndTurnIntoAnotherCharacter() {
        let playground = makePlayground()
        let buddy = playground.buddies[0]
        _ = buddy.equip(.eraser)
        #expect(buddy.critter is Mushroom)
        // A mouse or finger is always a fist, so the mushroom is erasing while it sits in the bubble.
        buddy.setMode(.erase)
        let bubble = playground.critterPots.first { $0.target == .tool(.wingBrush) }!
        rub(playground, buddy, at: bubble.root.simdPosition)
        #expect(buddy.tool == .wingBrush)
        #expect(buddy.critter is Butterfly)
    }

    @Test func legacyStarfishStillCannotPickThingsWhileErasing() {
        let playground = Playground(controlScheme: .legacy)
        playground.layout(size: CGSize(width: 1600, height: 1000))
        let buddy = playground.buddies[0]
        buddy.setMode(.erase)
        let pot = playground.pots.first { $0.colorIndex != buddy.colorIndex }!
        let before = buddy.colorIndex
        rub(playground, buddy, at: pot.root.simdPosition)
        #expect(buddy.colorIndex == before)
    }

    // MARK: Bug: the mushroom wiped the dotted guide

    @Test func mushroomLeavesTheTemplateAlone() {
        let playground = makePlayground()
        playground.begin(TemplateChoice(templateID: TemplateKind.pebble.rawValue, isDailyQuest: false))
        let outline = try! #require(playground.template)
        let marks = outline.markCount
        #expect(marks > 0)

        let buddy = playground.buddies[0]
        _ = buddy.equip(.eraser)
        buddy.setMode(.erase)
        let half = Playground.canvasSize * 0.5
        var now = 1000.0
        for ix in -10...10 {
            for iy in -6...6 {
                let p = SIMD3<Float>(Float(ix) / 10 * half.x, 0.1 + Float(iy) / 6 * half.y, 0.42)
                buddy.critter.position = Spring3(p)
                playground.erase(with: buddy, now: now)
                now += 0.1
            }
        }
        #expect(playground.template === outline)
        #expect(outline.markCount == marks)
    }

    @Test func legacyStarfishStillScrubsTheTemplate() {
        let playground = Playground(controlScheme: .legacy)
        playground.layout(size: CGSize(width: 1600, height: 1000))
        playground.begin(TemplateChoice(templateID: TemplateKind.pebble.rawValue, isDailyQuest: false))
        let marks = playground.template!.markCount
        let buddy = playground.buddies[0]
        #expect(buddy.setMode(.erase))
        let half = Playground.canvasSize * 0.5
        var now = 1000.0
        for ix in -10...10 {
            for iy in -6...6 {
                buddy.starfish.position = Spring3(SIMD3(Float(ix) / 10 * half.x, 0.1 + Float(iy) / 6 * half.y, 0.3))
                playground.erase(with: buddy, now: now)
                now += 0.1
            }
        }
        #expect((playground.template?.markCount ?? 0) < marks)
    }
}

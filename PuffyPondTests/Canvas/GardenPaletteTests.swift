import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct GardenPaletteTests {
    private func makePlayground() -> Playground {
        let playground = Playground()
        playground.layout(size: CGSize(width: 1600, height: 1000))
        return playground
    }

    /// Parks the buddy's character on a waiting character and rubs it there until it takes.
    private func rub(_ playground: Playground, _ buddy: Buddy, at position: SIMD3<Float>, frames: Int = 240) {
        buddy.critter.position = Spring3(position)
        var now = 1000.0
        for _ in 0..<frames {
            playground.rubPerches(buddy, dt: 1.0 / 60, now: now)
            now += 1.0 / 60
        }
    }

    @Test func buddiesStartAsTwoDifferentCharacters() {
        let playground = makePlayground()
        #expect(playground.buddies.map(\.tool) == [.ladybug, .butterfly])
        #expect(playground.buddies[0].critter is Ladybug)
        #expect(playground.buddies[1].critter is Butterfly)
    }

    @Test func rubbingOverAWaitingCharacterTurnsTheBuddyIntoIt() {
        let playground = makePlayground()
        let buddy = playground.buddies[0]
        buddy.setMode(.roam)
        for tool in [PaintTool.frog, .snail, .butterfly, .ladybug] {
            let perch = playground.perches.first { $0.tool == tool }!
            rub(playground, buddy, at: perch.root.simdPosition)
            #expect(buddy.tool == tool)
            #expect(buddy.colorIndex == tool.colorIndex)
            #expect(buddy.critter.kind == tool.critterKind)
        }
    }

    @Test func aBuddyOnItsOwnCharacterDoesNothing() {
        let playground = makePlayground()
        let buddy = playground.buddies[0]
        buddy.setMode(.roam)
        let own = playground.perches.first { $0.tool == buddy.tool }!
        let critter = buddy.critter
        rub(playground, buddy, at: own.root.simdPosition)
        #expect(buddy.critter === critter)
    }

    @Test func idleBuddiesNeverRub() {
        let playground = makePlayground()
        let buddy = playground.buddies[0]
        buddy.setMode(.idle)
        let perch = playground.perches.first { $0.tool == .snail }!
        rub(playground, buddy, at: perch.root.simdPosition)
        #expect(buddy.tool == .ladybug)
    }
}

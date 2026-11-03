import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct GardenCastTests {
    private let hover = SIMD3<Float>(0, 0, Playground.paintHoverZ)

    // MARK: Tool column

    @Test func toolColumnHasFourTools() {
        #expect(PaintTool.allCases == [.liquidOil, .brush, .eraser, .blender])
    }

    @Test func toolsMapToTheCast() {
        #expect(PaintTool.liquidOil.critterKind == .butterfly)
        #expect(PaintTool.brush.critterKind == .ladybug)
        #expect(PaintTool.eraser.critterKind == .mushroom)
        #expect(PaintTool.blender.critterKind == .snail)
    }

    @Test func gardenCastIsTheToolColumn() {
        #expect(CritterKind.gardenCast == PaintTool.allCases.compactMap(\.critterKind))
        #expect(CritterKind.gardenCast.count == 4)
    }

    @Test func gardenCastLooksDistinct() {
        let colors = CritterKind.gardenCast.map(\.signatureColor)
        for i in colors.indices {
            for j in colors.indices where j > i {
                #expect(simd_distance(colors[i], colors[j]) > 0.05)
            }
        }
    }

    @Test func everyGardenCritterBuildsAndAnimates() {
        for kind in CritterKind.gardenCast {
            let critter = kind.make(color: kind.signatureColor, at: .zero)
            #expect(critter.kind == kind)
            LimbBrushTests.settle(critter, frames: 60, target: hover, painting: true)
            LimbBrushTests.settle(critter, frames: 60, target: .zero, painting: false, beatPulse: 0.5)
            let p = critter.bodyNode.simdPosition
            #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
        }
    }

    @Test func legacyBrushesAreUntouched() {
        #expect(CritterKind.legacyBrushes == [.octopus, .snail, .pufferfish, .seahorse, .jellyfish, .frog])
    }

    // MARK: Ladybug (brush)

    @Test func ladybugIsBuiltByKind() {
        let critter = CritterKind.ladybug.make(color: Paint.colors[0], at: .zero)
        #expect(critter is Ladybug)
        #expect(critter.kind == .ladybug)
    }

    @Test func ladybugLaysLegsFlatWhilePressing() {
        let bug = Ladybug(color: Paint.colors[0], at: .zero)
        LimbBrushTests.settle(bug, frames: 180, target: hover, painting: true)
        let dabs = bug.dabs(from: .zero, to: .zero, radius: 0.085, speed: 0)
        #expect(!dabs.isEmpty)
        #expect(dabs.allSatisfy { $0.style.nca == 1 })
    }

    @Test func ladybugSurvivesATeleport() {
        let bug = Ladybug(color: Paint.colors[0], at: .zero)
        LimbBrushTests.settle(bug, frames: 30, target: hover, painting: true)
        LimbBrushTests.settle(bug, frames: 30, target: SIMD3(3, 0, 0.4), painting: true)
        for dab in bug.dabs(from: .zero, to: .zero, radius: 0.085, speed: 0) {
            #expect(dab.from.x.isFinite && dab.from.y.isFinite && dab.to.x.isFinite && dab.to.y.isFinite)
        }
        #expect(bug.bodyNode.simdPosition.x.isFinite)
    }

    @Test func limbBrushesUseTheSizeSlider() {
        #expect(Ladybug(color: Paint.colors[0], at: .zero).usesSizeSlider)
        #expect(Octopus(color: Paint.colors[0], at: .zero).usesSizeSlider)
        #expect(!Snail(color: Paint.colors[0], at: .zero).usesSizeSlider)
    }

    @Test func ladybugWingsFlapWithTheBeat() {
        let bug = Ladybug(color: Paint.colors[0], at: .zero)
        var seen: [Float] = []
        for _ in 0..<3 {
            for pulse in [Float(1), 0] {
                for _ in 0..<10 {
                    bug.update(dt: 1.0 / 60, target: .zero, visible: true, painting: false, beatPulse: pulse)
                    seen.append(bug.wingOpen)
                }
            }
        }
        #expect((seen.max() ?? 0) - (seen.min() ?? 0) > 0.3)
        #expect(seen.allSatisfy { $0 >= 0 && $0 <= 1.2 })
    }

    // MARK: Butterfly (liquid oil)

    @Test func butterflyIsBuiltByKind() {
        let critter = CritterKind.butterfly.make(color: Paint.colors[1], at: .zero)
        #expect(critter is Butterfly)
        #expect(critter.kind == .butterfly)
    }

    @Test func butterflyFlapsFasterWhilePainting() {
        let fly = Butterfly(color: Paint.colors[1], at: .zero)
        LimbBrushTests.settle(fly, frames: 90, target: .zero, painting: false)
        let idle = fly.flapRate
        LimbBrushTests.settle(fly, frames: 90, target: hover, painting: true)
        #expect(fly.flapRate > idle * 1.5)
        var seen: [Float] = []
        for _ in 0..<60 {
            fly.update(dt: 1.0 / 60, target: hover, visible: true, painting: true, beatPulse: 0)
            seen.append(fly.wingOpen)
        }
        #expect((seen.max() ?? 0) - (seen.min() ?? 0) > 0.4)
        #expect(seen.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    // MARK: Mushroom (eraser)

    @Test func scrubbedPuffsSpores() {
        let shroom = Mushroom(color: Paint.colors[3], at: .zero)
        #expect(shroom.puff == 0)
        shroom.scrubbed()
        LimbBrushTests.settle(shroom, frames: 5, target: .zero, painting: true)
        #expect(shroom.puff > 0)
    }

    @Test func mushroomSurvivesATeleport() {
        let shroom = Mushroom(color: Paint.colors[3], at: .zero)
        LimbBrushTests.settle(shroom, frames: 30, target: hover, painting: true)
        LimbBrushTests.settle(shroom, frames: 30, target: SIMD3(3, 0, 0.4), painting: true)
        let p = shroom.bodyNode.simdPosition
        #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
    }

    @Test func mushroomErasesAtLeastAsWideAsTheStarfish() {
        #expect(Mushroom.eraseRadius >= Starfish.eraseRadius)
    }

    // MARK: Eraser plumbing

    @Test func legacyEraserStillSwapsToTheStarfish() {
        let buddy = Buddy(slot: 0, colorIndex: 0, kind: .octopus, start: .zero)
        #expect(buddy.setMode(.erase))
        #expect(buddy.showsStarfish)
        #expect(buddy.eraseRadius == Starfish.eraseRadius)
    }

    @Test func gardenEraserIsTheMushroom() {
        let buddy = Buddy(slot: 0, colorIndex: 0, kind: .ladybug, start: .zero, erasesWithStarfish: false)
        let old = buddy.equip(.eraser)
        #expect(old is Ladybug)
        #expect(buddy.critter is Mushroom)
        #expect(!buddy.showsStarfish)
        #expect(!buddy.setMode(.erase))
        #expect(buddy.eraseRadius == Mushroom.eraseRadius)
    }

    @Test func eraserBubbleHoldsNoStarfishInTheGardenScheme() {
        #expect(CritterPot(tool: .eraser, at: .zero).starfish == nil)
    }

    @Test func pointerEraserEquipsTheMushroom() {
        let playground = Playground(controlScheme: .fist)
        playground.pointerErases = true
        let buddy = playground.buddies[0]
        #expect(buddy.critter is Mushroom)
        #expect(!buddy.showsStarfish)
        playground.pointerErases = false
        #expect(playground.buddies[0].critter is Ladybug)
    }
}

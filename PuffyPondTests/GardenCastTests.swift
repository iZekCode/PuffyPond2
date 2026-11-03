import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct GardenCastTests {
    private let hover = SIMD3<Float>(0, 0, Playground.paintHoverZ)

    // MARK: Tool column

    @Test func toolColumnHasFourTools() {
        #expect(PaintTool.allCases == [.wingBrush, .brush, .eraser, .blender])
    }

    @Test func toolsMapToTheCast() {
        #expect(PaintTool.wingBrush.critterKind == .butterfly)
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

    // MARK: Butterfly (brush)

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

    // MARK: Full-screen canvas

    private static let windows: [CGSize] = [CGSize(width: 1600, height: 1000), CGSize(width: 1024, height: 768),
                                            CGSize(width: 2400, height: 1000), CGSize(width: 900, height: 1200)]

    @Test func wholeCanvasStaysInViewWithRoomBesideIt() {
        for size in Self.windows {
            let playground = Playground(controlScheme: .fist)
            playground.layout(size: size)
            let canvas = Playground.canvasSize * 0.5
            let visible = playground.visibleHalfSize(atZ: Playground.canvasZ)
            // The whole canvas is on screen, not cropped by a window edge ...
            #expect(visible.x >= canvas.x && visible.y >= canvas.y, "\(size)")
            // ... and the pots and bubbles stand beside it, not over it.
            for pot in playground.pots {
                #expect(pot.root.simdPosition.x - PaintPot.radius > canvas.x, "\(size)")
            }
            for pot in playground.critterPots {
                #expect(pot.root.simdPosition.x + PaintPot.radius < -canvas.x, "\(size)")
            }
        }
    }

    @Test func potsAndBubblesFloatInsideTheView() {
        for size in Self.windows {
            let playground = Playground(controlScheme: .fist)
            playground.layout(size: size)
            let visible = playground.visibleHalfSize(atZ: 0.3)
            #expect(!playground.pots.isEmpty && !playground.critterPots.isEmpty)
            for pot in playground.pots {
                #expect(pot.root.simdPosition.x + PaintPot.radius <= visible.x, "\(size)")
                #expect(pot.root.simdPosition.x > 0)
            }
            for pot in playground.critterPots {
                #expect(pot.root.simdPosition.x - PaintPot.radius >= -visible.x, "\(size)")
                #expect(pot.root.simdPosition.x < 0)
            }
        }
    }

    @Test func nothingPaintsUnderAPotOrBubble() {
        let playground = Playground(controlScheme: .fist)
        playground.layout(size: Self.windows[0])
        let pot = playground.pots[0].root.simdPosition
        #expect(playground.isOverShelf(SIMD2(pot.x, pot.y)))
        let bubble = playground.critterPots[0].root.simdPosition
        #expect(playground.isOverShelf(SIMD2(bubble.x, bubble.y)))
        #expect(!playground.isOverShelf(SIMD2(0, 0.1)))
    }

    // MARK: Facing the way it travels

    /// Drives a critter's target steadily to one side for a second, then lets it stop.
    private func drive(_ critter: Critter, vx: Float, frames: Int) {
        var x = critter.position.value.x
        for _ in 0..<frames {
            x += vx / 60
            critter.update(dt: 1.0 / 60, target: SIMD3(x, 0, 0.4), visible: true, painting: false, beatPulse: 0)
        }
    }

    /// Where the head (the model's front) points on screen right now.
    private func facing(_ critter: Critter, front: SIMD3<Float>) -> SIMD3<Float> {
        critter.leanNode.simdOrientation.act(front)
    }

    @Test func gardenCastTurnsSidewaysWhileTravelingAndBackWhenStill() {
        // Ladybug, mushroom and snail turn their heads to the side; the butterfly (wings to the camera) banks.
        let fronts: [CritterKind: SIMD3<Float>] = [.ladybug: SIMD3(0, 0, 1), .mushroom: SIMD3(0, 0, 1),
                                                    .butterfly: SIMD3(0, 1, 0), .snail: SIMD3(1, 0, 0)]
        for (kind, front) in fronts {
            let critter = kind.make(color: kind.signatureColor, at: .zero)
            drive(critter, vx: 0, frames: 90)
            let rest = facing(critter, front: front)
            #expect(abs(rest.x) < 0.2, "\(kind.name) waits facing the camera")

            drive(critter, vx: 2, frames: 90)
            #expect(facing(critter, front: front).x > 0.8, "\(kind.name) heads right")
            drive(critter, vx: -2, frames: 150)
            #expect(facing(critter, front: front).x < -0.8, "\(kind.name) heads left")

            drive(critter, vx: 0, frames: 120)
            #expect(abs(facing(critter, front: front).x) < 0.2, "\(kind.name) faces the camera again")
        }
    }

    @Test func turnedCharactersAreTippedTowardTheCamera() {
        // Seen from above and the side, not edge-on: the top of the body tips toward the viewer.
        for kind in [CritterKind.ladybug, .mushroom, .snail] {
            let critter = kind.make(color: kind.signatureColor, at: .zero)
            drive(critter, vx: 2, frames: 90)
            #expect(critter.leanNode.simdOrientation.act(SIMD3(0, 1, 0)).z > 0.3, "\(kind.name)")
        }
    }

    @Test func otherAnimalsKeepTheirOwnLook() {
        let octopus = Octopus(color: Paint.colors[0], at: .zero)
        drive(octopus, vx: 2, frames: 90)
        #expect(!octopus.facesMotion && octopus.side == 0)
    }

    @Test func ladybugHasTheShapeOfARealOne() {
        // Two covers over a shell, a shield and head in front, six legs (three a side).
        let bug = Ladybug(color: Paint.colors[0], at: .zero)
        var spheres = 0
        bug.squashNode.enumerateHierarchy { node, _ in if node.geometry is SCNSphere { spheres += 1 } }
        #expect(spheres > 12)
        var antennae = 0
        bug.squashNode.enumerateHierarchy { node, _ in if node.geometry is SCNCapsule { antennae += 1 } }
        #expect(antennae >= 2)
        LimbBrushTests.settle(bug, frames: 180, target: hover, painting: true)
        #expect(bug.dabs(from: .zero, to: .zero, radius: 0.085, speed: 0).count > 0)
    }

    // MARK: Ladybug held still

    @Test func ladybugHoldIsNilWhileMovingAndGrowsWhenHeldStill() {
        let bug = Ladybug(color: Paint.colors[0], at: .zero)
        LimbBrushTests.settle(bug, frames: 120, target: hover, painting: true)
        let early = bug.holdProgress
        #expect(early != nil)
        LimbBrushTests.settle(bug, frames: 120, target: hover, painting: true)
        #expect((bug.holdProgress ?? 0) > (early ?? 1))
        LimbBrushTests.settle(bug, frames: 8, target: SIMD3(2, 0, Playground.paintHoverZ), painting: true)
        #expect(bug.holdProgress == nil)
    }
}

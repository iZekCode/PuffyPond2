import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct GardenCastTests {
    private let hover = SIMD3<Float>(0, 0, Playground.paintHoverZ)

    // MARK: Characters

    @Test func fourCharactersOneColourEach() {
        #expect(PaintTool.allCases == [.ladybug, .butterfly, .frog, .snail])
        #expect(PaintTool.ladybug.color == Paint.colors[0])      // red
        #expect(PaintTool.butterfly.color == Paint.colors[1])    // blue
        #expect(PaintTool.frog.color == Paint.colors[4])  // green
        #expect(PaintTool.snail.color == Paint.colors[3])        // orange
        #expect(Set(PaintTool.allCases.map(\.colorIndex)).count == 4)
    }

    @Test func toolsMapToTheCast() {
        #expect(PaintTool.ladybug.critterKind == .ladybug)
        #expect(PaintTool.butterfly.critterKind == .butterfly)
        #expect(PaintTool.frog.critterKind == .frog)
        #expect(PaintTool.snail.critterKind == .snail)
    }

    @Test func gardenCastIsTheCharacterRow() {
        #expect(CritterKind.gardenCast == PaintTool.allCases.map(\.critterKind))
        #expect(CritterKind.gardenCast.count == 4)
        #expect(CritterKind.gardenCast.map(\.signatureColor) == PaintTool.allCases.map(\.color))
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

    /// Saved timelapse recordings store the raw value of the brush's kind.
    @Test func kindRawValuesMatchSavedRecordings() {
        #expect(CritterKind.snail.rawValue == 1)
        #expect(CritterKind.ladybug.rawValue == 7)
        #expect(CritterKind.butterfly.rawValue == 8)
        #expect(CritterKind.frog.rawValue == 10)
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

    // MARK: Frog

    @Test func frogIsBuiltByKind() {
        let critter = CritterKind.frog.make(color: Paint.colors[4], at: .zero)
        #expect(critter is Frog)
        #expect(critter.kind == .frog)
    }

    @Test func everyCharacterPaintsSomething() {
        for tool in PaintTool.allCases {
            let dabs = tool.dabs(from: .zero, to: SIMD2(0.1, 0), radius: 0.085, speed: 1)
            #expect(!dabs.isEmpty && dabs.allSatisfy { $0.style.nca == 1 && $0.style.blend == 0 }, "\(tool)")
        }
    }

    @Test func buddyTurnsIntoTheCharacterAndItsColour() {
        let buddy = Buddy(slot: 0, tool: .ladybug, start: .zero)
        #expect(buddy.color == Paint.colors[0])
        let old = buddy.equip(.frog)
        #expect(old is Ladybug)
        #expect(buddy.critter is Frog)
        #expect(buddy.color == Paint.colors[4])
        #expect(buddy.equip(.frog) == nil)
    }

    // MARK: Full-screen canvas

    private static let windows: [CGSize] = [CGSize(width: 1600, height: 1000), CGSize(width: 1024, height: 768),
                                            CGSize(width: 2400, height: 1000), CGSize(width: 900, height: 1200)]

    @Test func canvasFillsTheWindowAndCharactersFloatInsideIt() {
        for size in Self.windows {
            let playground = Playground()
            playground.layout(size: size)
            let canvas = Playground.canvasSize * 0.5
            let visible = playground.visibleHalfSize(atZ: Playground.canvasZ)
            // Nothing but canvas is on screen, edge to edge ...
            #expect(visible.x <= canvas.x + 1e-3 && visible.y <= canvas.y + 1e-3, "\(size)")
            // ... and the four characters float in one row inside the view, near the bottom.
            let floating = playground.visibleHalfSize(atZ: CanvasLayout.characterZ)
            #expect(playground.perches.count == 4)
            let ys = Set(playground.perches.map { $0.root.simdPosition.y })
            #expect(ys.count == 1, "\(size)")
            for perch in playground.perches {
                let p = perch.root.simdPosition
                #expect(abs(p.x) + CanvasLayout.characterRadius <= floating.x + 1e-3, "\(size)")
                #expect(p.y < CanvasLayout.cameraY, "\(size)")
            }
        }
    }

    @Test func waitingCharactersUseTheCharacterScale() {
        let playground = Playground()
        for perch in playground.perches { #expect(perch.resident.sizeScale == CanvasLayout.characterScale) }
    }

    @Test func waitingCharactersSleepUntilABuddyComesNear() {
        let playground = Playground()
        playground.layout(size: Self.windows[0])
        for perch in playground.perches {
            for _ in 0..<120 { perch.update(dt: 1.0 / 60, beatPulse: 0.5, rubProgress: 0, buddyDistance: 10) }
            #expect(perch.resident.sleepiness > 0.95, "\(perch.tool) sleeps")
            for _ in 0..<120 { perch.update(dt: 1.0 / 60, beatPulse: 0.5, rubProgress: 0, buddyDistance: 0.2) }
            #expect(perch.resident.sleepiness < 0.05, "\(perch.tool) wakes")
            for _ in 0..<180 { perch.update(dt: 1.0 / 60, beatPulse: 0.5, rubProgress: 0, buddyDistance: 10) }
            #expect(perch.resident.sleepiness > 0.95, "\(perch.tool) sleeps again")
        }
    }

    @Test func aSleepingCharacterHoldsStill() {
        for tool in PaintTool.allCases {
            let critter = tool.critterKind.make(color: tool.color, at: .zero)
            critter.sleepiness = 1
            LimbBrushTests.settle(critter, frames: 60, target: .zero, painting: false)
            let before = critter.bodyNode.simdPosition
            for _ in 0..<120 { critter.update(dt: 1.0 / 60, target: .zero, visible: true, painting: false, beatPulse: 1) }
            #expect(simd_distance(critter.bodyNode.simdPosition, before) < 0.01, "\(tool) moved \(simd_distance(critter.bodyNode.simdPosition, before))")
        }
    }

    @Test func nothingPaintsUnderAWaitingCharacter() {
        let playground = Playground()
        playground.layout(size: Self.windows[0])
        let spot = playground.perches[0].root.simdPosition
        #expect(playground.isOverShelf(SIMD2(spot.x, spot.y)))
        #expect(!playground.isOverShelf(SIMD2(0, 0.6)))
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
        // The ladybug turns its head to the side; the butterfly (wings to the camera) banks.
        let fronts: [CritterKind: SIMD3<Float>] = [.ladybug: SIMD3(0, 0, 1), .butterfly: SIMD3(0, 1, 0)]
        for (kind, front) in fronts {
            let critter = kind.make(color: kind.signatureColor, at: .zero)
            drive(critter, vx: 0, frames: 90)
            let rest = facing(critter, front: front)
            #expect(abs(rest.x) < 0.2, "\(kind) waits facing the camera")

            drive(critter, vx: 2, frames: 90)
            #expect(facing(critter, front: front).x > 0.8, "\(kind) heads right")
            drive(critter, vx: -2, frames: 150)
            #expect(facing(critter, front: front).x < -0.8, "\(kind) heads left")

            drive(critter, vx: 0, frames: 120)
            #expect(abs(facing(critter, front: front).x) < 0.2, "\(kind) faces the camera again")
        }
    }

    @Test func snailAlwaysShowsItsSide() {
        let snail = CritterKind.snail.make(color: PaintTool.snail.color, at: .zero)
        let front = SIMD3<Float>(1, 0, 0)    // built in profile, head toward +x
        drive(snail, vx: 0, frames: 90)
        #expect(facing(snail, front: front).x > 0.8, "rests in profile, head to the right")
        drive(snail, vx: -2, frames: 150)
        #expect(facing(snail, front: front).x < -0.8, "heads left")
        drive(snail, vx: 2, frames: 150)
        #expect(facing(snail, front: front).x > 0.8, "heads right")
    }

    @Test func turnedCharactersAreTippedTowardTheCamera() {
        // Seen from above and the side, not edge-on: the top of the body tips toward the viewer.
        for kind in [CritterKind.ladybug, .snail] {
            let critter = kind.make(color: kind.signatureColor, at: .zero)
            drive(critter, vx: 2, frames: 90)
            #expect(critter.leanNode.simdOrientation.act(SIMD3(0, 1, 0)).z > 0.3, "\(kind)")
        }
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

    @Test func ladybugBodyPaintsEvenWhenDraggedTooFastForTheLegs() {
        let bug = Ladybug(color: Paint.colors[0], at: .zero)
        var x: Float = 0
        for _ in 0..<60 {
            x += 6.0 / 60   // 6 units a second
            bug.update(dt: 1.0 / 60, target: SIMD3(x, 0, Playground.paintHoverZ), visible: true, painting: true, beatPulse: 0)
        }
        let dabs = bug.dabs(from: SIMD2(x - 0.1, 0), to: SIMD2(x, 0), radius: 0.085, speed: 6)
        #expect(!dabs.isEmpty)
        let body = dabs[0]
        #expect(body.from == SIMD2(x - 0.1, 0) && body.to == SIMD2(x, 0))
        #expect(body.radius >= 0.085 * Ladybug.bodyBrush * 0.99 && body.style.nca == 1)
    }

    @Test func ladybugBodyBrushFollowsTheSizeSlider() {
        let small = Ladybug(color: Paint.colors[0], at: .zero)
        let big = Ladybug(color: Paint.colors[0], at: .zero)
        big.sizeScale = 2
        let a = small.dabs(from: .zero, to: SIMD2(0.1, 0), radius: 0.085, speed: 1)[0].radius
        let b = big.dabs(from: .zero, to: SIMD2(0.1, 0), radius: 0.085, speed: 1)[0].radius
        #expect(abs(b - 2 * a) < 1e-5)
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

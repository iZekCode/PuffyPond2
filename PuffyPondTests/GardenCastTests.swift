import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct GardenCastTests {
    private let hover = SIMD3<Float>(0, 0, Playground.paintHoverZ)

    @Test func brushToolIsTheSpider() {
        #expect(PaintTool.brush.critterKind == .spider)
    }

    @Test func spiderIsBuiltByKind() {
        let critter = CritterKind.spider.make(color: Paint.colors[0], at: .zero)
        #expect(critter is Spider)
        #expect(critter.kind == .spider)
    }

    @Test func spiderLaysLegsFlatWhilePressing() {
        let spider = Spider(color: Paint.colors[0], at: .zero)
        LimbBrushTests.settle(spider, frames: 180, target: hover, painting: true)
        let dabs = spider.dabs(from: .zero, to: .zero, radius: 0.085, speed: 0)
        #expect(!dabs.isEmpty)
        #expect(dabs.allSatisfy { $0.style.nca == 1 })
    }

    @Test func spiderSurvivesATeleport() {
        let spider = Spider(color: Paint.colors[0], at: .zero)
        LimbBrushTests.settle(spider, frames: 30, target: hover, painting: true)
        LimbBrushTests.settle(spider, frames: 30, target: SIMD3(3, 0, 0.4), painting: true)
        let dabs = spider.dabs(from: .zero, to: .zero, radius: 0.085, speed: 0)
        for dab in dabs {
            #expect(dab.from.x.isFinite && dab.from.y.isFinite && dab.to.x.isFinite && dab.to.y.isFinite)
        }
        #expect(spider.bodyNode.simdPosition.x.isFinite)
    }

    @Test func spiderUsesTheSizeSlider() {
        #expect(Spider(color: Paint.colors[0], at: .zero).usesSizeSlider)
        #expect(Octopus(color: Paint.colors[0], at: .zero).usesSizeSlider)
        #expect(!Snail(color: Paint.colors[0], at: .zero).usesSizeSlider)
    }

    @Test func liquidOilIsTheLadybug() {
        #expect(PaintTool.liquidOil.critterKind == .ladybug)
        #expect(CritterKind.ladybug.make(color: Paint.colors[5], at: .zero) is Ladybug)
    }

    @Test func ladybugWingsFlapWithTheBeat() {
        let bug = Ladybug(color: Paint.colors[5], at: .zero)
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

    @Test func blenderToolIsTheBee() {
        #expect(PaintTool.blender.critterKind == .bee)
        #expect(CritterKind.bee.make(color: Paint.colors[1], at: .zero) is Bee)
    }

    @Test func beeWigglesOnlyWhileBlending() {
        let bee = Bee(color: Paint.colors[1], at: .zero)
        LimbBrushTests.settle(bee, frames: 60, target: .zero, painting: true)
        #expect(bee.wiggle > 0.8)
        LimbBrushTests.settle(bee, frames: 60, target: .zero, painting: false)
        #expect(bee.wiggle < 0.1)
    }
}

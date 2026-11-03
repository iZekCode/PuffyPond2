import Testing
import simd
@testable import PuffyPond

@MainActor
struct ControlSchemeTests {
    private func reading(fingers: Int, pinch: Float = 10, reach: Float = 0) -> PalmReading {
        PalmReading(palm: SIMD2(0.5, 0.5), extendedFingers: fingers, pinchRatio: pinch, indexReach: reach)
    }

    /// A clear pinch: thumb on the index tip with the index reaching out.
    private var pinch: PalmReading { reading(fingers: 1, pinch: 0.2, reach: 1.4) }

    @Test func openHandNeverPaints() {
        for tool in PaintTool.allCases {
            #expect(ControlScheme.fist.mode(for: .open, tool: tool) == .swim)
        }
        #expect(ControlScheme.fist.mode(for: nil, tool: .brush) == .idle)
    }

    @Test func fistPaintsWithCurrentTool() {
        for tool in PaintTool.allCases where tool != .eraser {
            #expect(ControlScheme.fist.mode(for: .fist, tool: tool) == .paint)
        }
        #expect(ControlScheme.fist.mode(for: .fist, tool: .eraser) == .erase)

        // The paint itself comes from the tool.
        let a = SIMD2<Float>(0, 0), b = SIMD2<Float>(0.1, 0)
        let liquid = PaintTool.liquidOil.dabs(from: a, to: b, radius: 0.085, speed: 1)
        #expect(liquid.allSatisfy { $0.style.watery > 0 && $0.style.runs > 0 })
        let blend = PaintTool.blender.dabs(from: a, to: b, radius: 0.085, speed: 1)
        #expect(!blend.isEmpty && blend.allSatisfy { $0.style.blend == 1 && $0.style.amount == 0 })
        #expect(PaintTool.eraser.dabs(from: a, to: b, radius: 0.085, speed: 1).isEmpty)
    }

    @Test func pinchIsTreatedAsOpen() {
        for tool in PaintTool.allCases {
            #expect(ControlScheme.fist.mode(for: .pinch, tool: tool) == .swim)
        }
        var filter = PoseFilter(pose: .open)
        for _ in 0..<5 { filter.feed(pinch, scheme: .fist) }
        #expect(filter.pose == .open)
    }

    @Test func legacySchemeUnchanged() {
        for tool in PaintTool.allCases {
            #expect(ControlScheme.legacy.mode(for: nil, tool: tool) == .idle)
            #expect(ControlScheme.legacy.mode(for: .open, tool: tool) == .swim)
            #expect(ControlScheme.legacy.mode(for: .pinch, tool: tool) == .paint)
            #expect(ControlScheme.legacy.mode(for: .fist, tool: tool) == .erase)
        }
        // Pinch wins after one frame, a fist after three, open after two.
        var filter = PoseFilter(pose: .open)
        filter.feed(pinch, scheme: .legacy)
        #expect(filter.pose == .pinch)
        filter = PoseFilter(pose: .open)
        filter.feed(reading(fingers: 0), scheme: .legacy)
        filter.feed(reading(fingers: 0), scheme: .legacy)
        #expect(filter.pose == .open)
        filter.feed(reading(fingers: 0), scheme: .legacy)
        #expect(filter.pose == .fist)
        filter.feed(reading(fingers: 4), scheme: .legacy)
        #expect(filter.pose == .fist)
        filter.feed(reading(fingers: 4), scheme: .legacy)
        #expect(filter.pose == .open)
    }

    @Test func fistEntersAfterTwoFramesAndLeavesAfterThree() {
        var filter = PoseFilter(pose: .open)
        filter.feed(reading(fingers: 0), scheme: .fist)
        #expect(filter.pose == .open)
        filter.feed(reading(fingers: 0), scheme: .fist)
        #expect(filter.pose == .fist)
        filter.feed(reading(fingers: 3), scheme: .fist)
        filter.feed(reading(fingers: 3), scheme: .fist)
        #expect(filter.pose == .fist)
        filter.feed(reading(fingers: 3), scheme: .fist)
        #expect(filter.pose == .open)
    }

    @Test func looseFistKeepsPainting() {
        var filter = PoseFilter(pose: .fist)
        // One finger creeping out, or a single noisy open frame, must not drop the stroke.
        for fingers in [1, 1, 4, 1, 0, 4, 4, 1, 1] {
            filter.feed(reading(fingers: fingers), scheme: .fist)
            #expect(filter.pose == .fist)
        }
    }
}

import Testing
import simd
@testable import PuffyPond

@MainActor
struct HandControlTests {
    private func reading(fingers: Int) -> PalmReading {
        PalmReading(palm: SIMD2(0.5, 0.5), extendedFingers: fingers)
    }

    @Test func openHandNeverPaints() {
        for tool in PaintTool.allCases {
            #expect(BuddyMode.mode(for: .open, tool: tool) == .roam)
        }
        #expect(BuddyMode.mode(for: nil, tool: .brush) == .idle)
    }

    @Test func fistPaintsWithCurrentTool() {
        for tool in PaintTool.allCases where tool != .eraser {
            #expect(BuddyMode.mode(for: .fist, tool: tool) == .paint)
        }
        #expect(BuddyMode.mode(for: .fist, tool: .eraser) == .erase)

        // The paint itself comes from the tool.
        let a = SIMD2<Float>(0, 0), b = SIMD2<Float>(0.1, 0)
        let wing = PaintTool.wingBrush.dabs(from: a, to: b, radius: 0.085, speed: 1)
        #expect(!wing.isEmpty && wing.allSatisfy { $0.style.nca == 1 && $0.style.runs == 0 })
        let blend = PaintTool.blender.dabs(from: a, to: b, radius: 0.085, speed: 1)
        #expect(!blend.isEmpty && blend.allSatisfy { $0.style.blend == 1 && $0.style.amount == 0 })
        #expect(PaintTool.eraser.dabs(from: a, to: b, radius: 0.085, speed: 1).isEmpty)
    }

    @Test func fistEntersAfterTwoFramesAndLeavesAfterThree() {
        var filter = PoseFilter(pose: .open)
        filter.feed(reading(fingers: 0))
        #expect(filter.pose == .open)
        filter.feed(reading(fingers: 0))
        #expect(filter.pose == .fist)
        filter.feed(reading(fingers: 3))
        filter.feed(reading(fingers: 3))
        #expect(filter.pose == .fist)
        filter.feed(reading(fingers: 3))
        #expect(filter.pose == .open)
    }

    @Test func looseFistKeepsPainting() {
        var filter = PoseFilter(pose: .fist)
        // One finger creeping out, or a single noisy open frame, must not drop the stroke.
        for fingers in [1, 1, 4, 1, 0, 4, 4, 1, 1] {
            filter.feed(reading(fingers: fingers))
            #expect(filter.pose == .fist)
        }
    }
}

import Testing
import simd
@testable import PuffyPond

@MainActor
struct HandControlTests {
    private func reading(fingers: Int) -> PalmReading {
        PalmReading(palm: SIMD2(0.5, 0.5), extendedFingers: fingers)
    }

    @Test func openHandNeverPaints() {
        #expect(BuddyMode.mode(for: .open) == .roam)
        #expect(BuddyMode.mode(for: nil) == .idle)
    }

    @Test func fistPaintsWithTheCharactersBrush() {
        #expect(BuddyMode.mode(for: .fist) == .paint)

        // The paint itself comes from the character.
        let a = SIMD2<Float>(0, 0), b = SIMD2<Float>(0.1, 0)
        for tool in PaintTool.allCases {
            let dabs = tool.dabs(from: a, to: b, radius: 0.085, speed: 1)
            #expect(!dabs.isEmpty && dabs.allSatisfy { $0.style.nca == 1 && $0.style.runs == 0 }, "\(tool)")
        }
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

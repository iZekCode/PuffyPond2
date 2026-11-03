import Testing
import simd
@testable import PuffyPond

@MainActor
struct LimbBrushTests {
    /// Steps a critter for `frames` frames at 60 fps toward `target`.
    static func settle(_ critter: Critter, frames: Int, target: SIMD3<Float>, painting: Bool, beatPulse: Float = 0) {
        for _ in 0..<frames {
            critter.update(dt: 1.0 / 60, target: target, visible: true, painting: painting, beatPulse: beatPulse)
        }
    }

    @Test func octopusLaysItsLimbsFlatWhilePressing() {
        let octopus = Octopus(color: Paint.colors[0], at: .zero)
        Self.settle(octopus, frames: 180, target: SIMD3(0, 0, Playground.paintHoverZ), painting: true)
        let dabs = octopus.dabs(from: .zero, to: .zero, radius: 0.085, speed: 0)
        #expect(!dabs.isEmpty)
        #expect(dabs.allSatisfy { $0.style.nca == 1 })
        #expect(dabs.count == 40)
    }
}

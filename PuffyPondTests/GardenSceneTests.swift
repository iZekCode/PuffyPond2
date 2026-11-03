import SceneKit
import Testing
@testable import PuffyPond

@MainActor
struct GardenSceneTests {
    @Test func petalsHaveAnImage() {
        #expect(Effects.petals().particleImage != nil)
    }

    @Test func firefliesAreAlive() {
        let flies = Effects.fireflies()
        #expect(flies.birthRate > 0)
        #expect(flies.particleLifeSpan > 1)
    }

    @Test func petalBurstEmitsAndCleansUp() {
        let scene = SCNScene()
        Effects.petalBurst(in: scene, at: .zero, color: Paint.colors[0], count: 12)
        #expect(scene.rootNode.childNodes.count == 1)
    }
}

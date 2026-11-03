import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct FocusModeTests {
    private func makePlayground() -> Playground {
        let playground = Playground(controlScheme: .fist)
        playground.layout(size: CGSize(width: 1600, height: 1000))
        return playground
    }

    @Test func focusModeHidesPotsAndBubbles() {
        let playground = makePlayground()
        #expect(playground.pots.allSatisfy { !$0.root.isHidden })
        playground.focusMode = true
        #expect(playground.pots.allSatisfy { $0.root.isHidden })
        #expect(playground.critterPots.allSatisfy { $0.root.isHidden && $0.residentRoot.isHidden })
        playground.focusMode = false
        #expect(playground.pots.allSatisfy { !$0.root.isHidden })
        #expect(playground.critterPots.allSatisfy { !$0.root.isHidden && !$0.residentRoot.isHidden })
    }

    @Test func hiddenBubblesStayHiddenWhileTheyUpdate() {
        let playground = makePlayground()
        playground.focusMode = true
        for pot in playground.critterPots {
            for _ in 0..<30 { pot.update(dt: 1.0 / 60, beatPulse: 0.5, rubProgress: 0, selectedCount: 0, color: nil) }
            #expect(pot.residentRoot.isHidden)
        }
    }

    @Test func nothingBlocksPaintingInFocusMode() {
        let playground = makePlayground()
        let pot = playground.pots[0].root.simdPosition
        #expect(playground.isOverShelf(SIMD2(pot.x, pot.y)))
        playground.focusMode = true
        #expect(!playground.isOverShelf(SIMD2(pot.x, pot.y)))
    }

    @Test func canvasSceneCastsNoShadows() {
        let playground = makePlayground()
        var lights: [SCNLight] = []
        playground.scene.rootNode.enumerateHierarchy { node, _ in
            if let light = node.light { lights.append(light) }
        }
        #expect(!lights.isEmpty)
        #expect(lights.allSatisfy { !$0.castsShadow })
        #expect(playground.cameraNode.camera?.screenSpaceAmbientOcclusionIntensity == 0)
    }
}

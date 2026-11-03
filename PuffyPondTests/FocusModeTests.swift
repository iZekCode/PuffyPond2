import SceneKit
import SwiftUI
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

    @Test func focusModeKeepsThePotsAndBubbles() {
        let playground = makePlayground()
        playground.focusMode = true
        #expect(playground.pots.count == 6 && playground.pots.allSatisfy { !$0.root.isHidden })
        #expect(playground.critterPots.count == 4)
        #expect(playground.critterPots.allSatisfy { !$0.root.isHidden && !$0.residentRoot.isHidden })
        let pot = playground.pots[0].root.simdPosition
        #expect(playground.isOverShelf(SIMD2(pot.x, pot.y)))
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

    #if os(macOS)
    /// Clicks the eye over the real 3D view, like the app does: the second click used to fall through to the
    /// 3D view because the dimmed button had view opacity below 1.
    @Test func eyeButtonTogglesRepeatedlyOverThe3DView() {
        let playground = makePlayground()
        playground.showGuide = false
        let tracker = HandTracker()
        let root = ZStack {
            PlaygroundView(playground: playground).ignoresSafeArea()
            HUDView(playground: playground, previewLayer: tracker.previewLayer, saveImage: {}, goHome: {})
        }
        .environment(\.uiScale, 1)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1600, height: 1000), styleMask: [.titled],
                              backing: .buffered, defer: false)
        let host = NSHostingView(rootView: root)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.frame = NSRect(x: 0, y: 0, width: 1600, height: 1000)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let eye = CGPoint(x: 1600 - 16 - 23, y: 16 + 23)     // bottom right corner
        var states: [Bool] = []
        for _ in 0..<4 {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type, location: eye, modifierFlags: [],
                                               timestamp: ProcessInfo.processInfo.systemUptime,
                                               windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                               clickCount: 1, pressure: 1)!
                window.sendEvent(event)
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            states.append(playground.focusMode)
        }
        #expect(states == [true, false, true, false])
    }
    #endif
}

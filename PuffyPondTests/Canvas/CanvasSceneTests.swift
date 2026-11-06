import SceneKit
import SwiftUI
import Testing
import simd
@testable import PuffyPond

@MainActor
struct CanvasSceneTests {
    private func makePlayground() -> Playground {
        let playground = Playground()
        playground.layout(size: CGSize(width: 1600, height: 1000))
        return playground
    }

    @Test func fourCharactersWaitAlongTheBottom() {
        let playground = makePlayground()
        #expect(playground.perches.count == 4)
        #expect(playground.perches.allSatisfy { !$0.root.isHidden && !$0.residentRoot.isHidden })
        let first = playground.perches[0].root.simdPosition
        #expect(playground.isOverShelf(SIMD2(first.x, first.y)))
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
    /// Clicks the eye over the real 3D view, like the app does: it sits top right and shows or hides the camera view.
    @Test func eyeButtonTogglesTheCameraViewRepeatedlyOverThe3DView() {
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

        let eye = CGPoint(x: 1600 - 16 - 23, y: 1000 - 16 - 23)     // top right corner (AppKit's y points up)
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
            states.append(playground.showCameraPreview)
        }
        #expect(states == [false, true, false, true])
    }
    #endif
}

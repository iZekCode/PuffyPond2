import Foundation
import Testing
import simd
@testable import PuffyPond

@MainActor
struct CanvasLayoutTests {
    private func fitted(_ width: Float, _ height: Float) -> CanvasLayout {
        var layout = CanvasLayout()
        layout.fit(width: width, height: height)
        return layout
    }

    @Test func canvasFillsEveryWindowShape() {
        for (w, h) in [(1600, 1000), (1000, 1000), (2400, 1000), (1000, 1600)] as [(Float, Float)] {
            let layout = fitted(w, h)
            let half = layout.visibleHalfSize(atZ: CanvasLayout.canvasZ)
            // The view never shows more than the canvas, and the canvas touches the window edges on the tighter side.
            #expect(half.x <= CanvasLayout.canvasSize.x * 0.5 + 1e-4)
            #expect(half.y <= CanvasLayout.canvasSize.y * 0.5 + 1e-4)
            #expect(abs(half.x - CanvasLayout.canvasSize.x * 0.5) < 1e-3 || abs(half.y - CanvasLayout.canvasSize.y * 0.5) < 1e-3)
        }
    }

    @Test func charactersStandInARowAlongTheBottom() {
        for (w, h) in [(1600, 1000), (1000, 1000), (2400, 1000), (1000, 1600)] as [(Float, Float)] {
            let layout = fitted(w, h)
            let slots = layout.characterSlots(count: 4)
            let view = layout.visibleHalfSize(atZ: CanvasLayout.characterZ)
            #expect(slots.count == 4)
            #expect(Set(slots.map(\.y)).count == 1)
            #expect(slots.map(\.x) == slots.map(\.x).sorted())
            #expect(abs(slots.map(\.x).reduce(0, +)) < 1e-4)
            for slot in slots {
                #expect(abs(slot.x) + CanvasLayout.characterRadius <= view.x + 1e-4)
                #expect(slot.y < CanvasLayout.cameraY)
                // The centre is on screen, the lower part tucks below the bottom edge.
                #expect(slot.y > CanvasLayout.cameraY - view.y)
                #expect(slot.y - CanvasLayout.characterRadius < CanvasLayout.cameraY - view.y)
            }
        }
    }

    @Test func emptyWindowKeepsTheLastFit() {
        var layout = fitted(1600, 1000)
        let distance = layout.cameraDistance
        layout.fit(width: 0, height: 900)
        #expect(layout.cameraDistance == distance)
    }

    @Test func viewCornersMapToTheVisibleEdges() {
        let layout = fitted(1600, 1000)
        let h = layout.visibleHalfSize(atZ: 0)
        let topLeft = layout.worldPoint(SIMD2(0, 0), z: 0)
        #expect(abs(topLeft.x + h.x) < 1e-4)
        #expect(abs(topLeft.y - (CanvasLayout.cameraY + h.y)) < 1e-4)
        let middle = layout.worldPoint(SIMD2(0.5, 0.5), z: 0)
        #expect(abs(middle.x) < 1e-4 && abs(middle.y - CanvasLayout.cameraY) < 1e-4)
    }

    @Test func panFollowsTheSideAndStaysInRange() {
        let layout = fitted(1600, 1000)
        #expect(layout.pan(forX: 0) == 0)
        #expect(layout.pan(forX: -1) < 0)
        #expect(layout.pan(forX: 100) == 1)
        #expect(layout.pan(forX: -100) == -1)
    }

    @Test func paintingBuddiesHoverLowerAndBigBrushesHigher() {
        let roaming = CanvasLayout.buddyZ(painting: false, brushSize: nil)
        let painting = CanvasLayout.buddyZ(painting: true, brushSize: nil)
        let bigBrush = CanvasLayout.buddyZ(painting: true, brushSize: 2)
        #expect(abs(painting - CanvasLayout.paintHoverZ) < 1e-6)
        #expect(painting < roaming)
        #expect(bigBrush > painting)
        #expect(CanvasLayout.buddyZ(painting: true, brushSize: 0.6) == painting)
    }

    @Test func brushPointClampsNearTheEdgeAndRefusesFarOff() {
        let center = CanvasLayout.canvasCenter
        #expect(CanvasLayout.brushPoint(center) == center)
        let half = CanvasLayout.canvasSize * 0.5 - SIMD2(repeating: CanvasLayout.strokeRadius)
        let justOver = CanvasLayout.brushPoint(center + SIMD2(half.x + 0.03, 0))
        #expect(justOver == center + SIMD2(half.x, 0))
        #expect(CanvasLayout.brushPoint(SIMD2(CanvasLayout.canvasSize.x, center.y)) == nil)
    }

    @Test func canvasUVCoversTheCanvasTopDown() {
        let size = CanvasLayout.canvasSize
        let center = CanvasLayout.canvasCenter
        let topLeft = SIMD3(center.x - size.x / 2, center.y + size.y / 2, 0)
        #expect(CanvasLayout.canvasUV(topLeft) == SIMD2(0, 0))
        let middle = CanvasLayout.canvasUV(SIMD3(center.x, center.y, 0))
        #expect(middle.map { simd_distance($0, SIMD2(0.5, 0.5)) < 1e-5 } == true)
        #expect(CanvasLayout.canvasUV(SIMD3(CanvasLayout.canvasSize.x, center.y, 0)) == nil)
    }

    @Test func touchingACharacterNeedsToBeOnIt() {
        let spot = SIMD3<Float>(0.5, -1.5, CanvasLayout.characterZ)
        #expect(CanvasLayout.touches(SIMD2(spot.x, spot.y), characterAt: spot))
        #expect(!CanvasLayout.touches(SIMD2(spot.x - 1.5, spot.y), characterAt: spot))
    }
}

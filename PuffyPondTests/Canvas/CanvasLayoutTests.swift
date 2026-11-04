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

    @Test func canvasAndColumnsFitEveryWindowShape() {
        for (w, h) in [(1600, 1000), (1000, 1000), (2400, 1000), (1000, 1600)] as [(Float, Float)] {
            let layout = fitted(w, h)
            let canvasHalf = layout.visibleHalfSize(atZ: CanvasLayout.canvasZ)
            #expect(canvasHalf.y >= CanvasLayout.canvasSize.y * 0.5)
            let columnsHalf = layout.visibleHalfSize(atZ: 0.3)
            #expect(columnsHalf.x >= CanvasLayout.shelfX + CanvasLayout.potRadius)
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
        #expect(CanvasLayout.brushPoint(SIMD2(CanvasLayout.shelfX, center.y)) == nil)
    }

    @Test func canvasUVCoversTheCanvasTopDown() {
        let size = CanvasLayout.canvasSize
        let center = CanvasLayout.canvasCenter
        let topLeft = SIMD3(center.x - size.x / 2, center.y + size.y / 2, 0)
        #expect(CanvasLayout.canvasUV(topLeft) == SIMD2(0, 0))
        let middle = CanvasLayout.canvasUV(SIMD3(center.x, center.y, 0))
        #expect(middle.map { simd_distance($0, SIMD2(0.5, 0.5)) < 1e-5 } == true)
        #expect(CanvasLayout.canvasUV(SIMD3(CanvasLayout.shelfX, center.y, 0)) == nil)
    }

    @Test func columnsAreCentredOnTheCanvas() {
        let ys = (0..<4).map { CanvasLayout.columnY($0, of: 4) }
        #expect(abs((ys.first! + ys.last!) / 2 - CanvasLayout.canvasCenter.y) < 1e-5)
        #expect(ys == ys.sorted(by: >))
    }

    @Test func touchingAPotNeedsToBeOnIt() {
        let pot = SIMD3<Float>(CanvasLayout.shelfX, 0.5, 0.3)
        #expect(CanvasLayout.touches(SIMD2(pot.x, pot.y), potAt: pot))
        #expect(!CanvasLayout.touches(SIMD2(pot.x - 1, pot.y), potAt: pot))
    }
}

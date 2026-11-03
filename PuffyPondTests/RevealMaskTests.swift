import CoreGraphics
import Testing
import simd
@testable import PuffyPond

struct RevealMaskTests {
    private func dab(from: SIMD2<Float>, to: SIMD2<Float>, radius: Float = 0.1, t: Double = 0,
                     blend: Float = 0) -> RecordedDab {
        var style = BrushStyle.brush
        style.blend = blend
        return RecordedDab(t: t, from: from, to: to, radius: radius, speed: 1, color: SIMD3(1, 0, 0), seed: 0,
                           strokeSeed: 0, style: style, drag: nil, ncaModel: 0, brush: .butterfly)
    }

    /// Brightness 0…255 of one pixel of the mask picture (x from the left, y from the top).
    private func pixel(_ image: CGImage, x: Int, y: Int) -> UInt8 {
        var byte: UInt8 = 0
        let context = CGContext(data: &byte, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return byte
    }

    @Test func revealsUnderADab() {
        let mask = RevealMask()
        mask.reveal(dab(from: SIMD2(-1, 0.1), to: SIMD2(1, 0.1)))
        #expect(mask.coverage(atWorld: SIMD2(0, 0.1)) > 0.9)
    }

    @Test func leavesOtherPlacesAlone() {
        let mask = RevealMask()
        mask.reveal(dab(from: SIMD2(-1, 0.1), to: SIMD2(1, 0.1)))
        #expect(mask.coverage(atWorld: SIMD2(0, 1.5)) == 0)
    }

    @Test func clearHidesEverything() {
        let mask = RevealMask()
        mask.reveal(dab(from: SIMD2(-1, 0.1), to: SIMD2(1, 0.1)))
        mask.clear()
        #expect(mask.coverage(atWorld: SIMD2(0, 0.1)) == 0)
    }

    @Test func canvasCornersMapToPixels() {
        let mask = RevealMask()
        let center = SIMD2<Float>(0, 0.1)
        let half = Playground.canvasSize / 2 - SIMD2(0.1, 0.1)
        for corner in [SIMD2<Float>(-1, 1), SIMD2(1, 1), SIMD2(-1, -1), SIMD2(1, -1)] {
            let p = center + corner * half
            mask.reveal(dab(from: p, to: p, radius: 0.08))
        }
        let image = mask.image
        #expect(pixel(image, x: 10, y: 10) > 200)
        #expect(pixel(image, x: image.width - 11, y: 10) > 200)
        #expect(pixel(image, x: 10, y: image.height - 11) > 200)
        #expect(pixel(image, x: image.width - 11, y: image.height - 11) > 200)
        #expect(pixel(image, x: image.width / 2, y: image.height / 2) == 0)
    }

    @Test func replayerRevealsOnlyWhatIsDueAndNeverGoesBack() throws {
        let events: [RecordedEvent] = [
            .dab(dab(from: SIMD2(-2, 1), to: SIMD2(-2, 1), t: 0)),
            .dab(dab(from: SIMD2(2, -1), to: SIMD2(2, -1), t: 1)),
            .dab(dab(from: SIMD2(0, 0.1), to: SIMD2(0, 0.1), t: 2, blend: 1)),
        ]
        let recording = StrokeRecording(events: events)
        let timeline = ReplayTimeline(eventTimes: events.map(\.t))
        let paint = try #require(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage())
        let replayer = MaskReplayer(finalPaint: paint, recording: recording, timeline: timeline)

        replayer.advance(to: 0.5)
        #expect(replayer.mask.coverage(atWorld: SIMD2(-2, 1)) > 0.9)
        #expect(replayer.mask.coverage(atWorld: SIMD2(2, -1)) == 0)

        replayer.advance(to: 3)
        #expect(replayer.mask.coverage(atWorld: SIMD2(2, -1)) > 0.9)
        #expect(replayer.mask.coverage(atWorld: SIMD2(0, 0.1)) == 0, "blender dabs reveal nothing")

        replayer.advance(to: 0.1)
        #expect(replayer.mask.coverage(atWorld: SIMD2(2, -1)) > 0.9, "advance never goes back")

        replayer.reset()
        #expect(replayer.mask.coverage(atWorld: SIMD2(-2, 1)) == 0)
    }
}

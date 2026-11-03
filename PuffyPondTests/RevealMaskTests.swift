import CoreGraphics
import Metal
import SceneKit
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

    /// Renders the replayer's node alone against green and reads two pixels: the shader that hides unrevealed paint
    /// is the one thing the other tests cannot see.
    @Test func replayerDrawsPaintOnlyWhereRevealed() throws {
        let red = try #require(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        red.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        red.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let events: [RecordedEvent] = [
            .dab(dab(from: SIMD2(-2, 0.1), to: SIMD2(-2, 0.1), radius: 0.3, t: 0)),
            .dab(dab(from: SIMD2(-2, 0.1), to: SIMD2(-2, 0.1), radius: 0.3, t: 1)),
        ]
        let replayer = MaskReplayer(finalPaint: try #require(red.makeImage()),
                                    recording: StrokeRecording(events: events),
                                    timeline: ReplayTimeline(eventTimes: [0, 1]))
        replayer.advance(to: 0.5)

        let scene = SCNScene()
        scene.background.contents = PlatformColor(red: 0, green: 1, blue: 0, alpha: 1)
        scene.rootNode.addChildNode(replayer.node)
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .ambient
        light.light?.intensity = 1000
        scene.rootNode.addChildNode(light)
        let lens = SCNNode()
        lens.camera = SCNCamera()
        lens.camera?.usesOrthographicProjection = true
        lens.camera?.orthographicScale = 2
        lens.simdPosition = SIMD3(0, 0, 5)
        scene.rootNode.addChildNode(lens)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = lens
        let shot = try #require(renderer.snapshot(atTime: 0, with: CGSize(width: 640, height: 400),
                                                  antialiasingMode: .none).cgImageValue)

        func rgb(x: Int, y: Int) -> (r: Int, g: Int) {
            var bytes = [UInt8](repeating: 0, count: 4)
            let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(shot, in: CGRect(x: -x, y: -(shot.height - 1 - y), width: shot.width, height: shot.height))
            return (Int(bytes[0]), Int(bytes[1]))
        }
        let revealed = rgb(x: 120, y: 200)    // where the dab is
        let hidden = rgb(x: 520, y: 200)      // the far side
        #expect(revealed.r > 150 && revealed.g < 100, "paint shows where revealed: \(revealed)")
        #expect(hidden.g > 150 && hidden.r < 100, "background shows elsewhere: \(hidden)")
    }
}

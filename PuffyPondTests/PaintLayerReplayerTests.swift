import CoreGraphics
import Foundation
import Metal
import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct PaintLayerReplayerTests {
    @Test func longerSessionsGetSmallerLayers() {
        let sizes = [1.0, 2, 3, 5, 6, 14, 15, 40].map { PaintLayerReplayer.resolution(forSpeedUp: $0) }
        #expect(sizes == [768, 768, 512, 512, 384, 384, 256, 256])
        #expect(sizes == sizes.sorted(by: >), "the layer never grows as the replay speeds up")
    }

    // MARK: Helpers (a copy of the photo booth the saved photo is taken in, and the review page's scene)

    private func meanRGB(_ image: CGImage, x: Int, y: Int, w: Int, h: Int) -> SIMD3<Double> {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let ctx = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        var sum = SIMD3<Double>(0, 0, 0)
        for j in y..<(y + h) { for i in x..<(x + w) {
            let o = (j * image.width + i) * 4
            sum += SIMD3(Double(bytes[o]), Double(bytes[o + 1]), Double(bytes[o + 2]))
        } }
        return sum / Double(w * h)
    }

    private func stampPatch(_ layer: PaintLayer, color: SIMD3<Float>) {
        for k in 0..<30 {
            let x = -2 + Float(k) * 0.14
            layer.stamp(from: SIMD2(x, 0.1), to: SIMD2(x + 0.14, 0.1), radius: 0.6, color: color, speed: 0.5, seed: 1, strokeSeed: 1)
            layer.update(dt: 1.0 / 60)
        }
        for _ in 0..<200 { layer.update(dt: 1.0 / 60) }
    }

    private func reference(color: SIMD3<Float>) throws -> CGImage {
        let layer = PaintLayer(center: SIMD2(0, 0.1), size: Playground.canvasSize, z: 0.04, pixelsAcross: 768)
        stampPatch(layer, color: color)
        let booth = SCNScene()
        booth.background.contents = PlatformColor.black
        booth.lightingEnvironment.contents = Studio.environment()
        booth.lightingEnvironment.intensity = Playground.environmentIntensity
        booth.rootNode.addChildNode(layer.node)
        let key = SCNLight(); key.type = .spot; key.intensity = Playground.keyIntensity
        key.spotInnerAngle = Playground.keyInnerAngle; key.spotOuterAngle = Playground.keyOuterAngle
        key.attenuationStartDistance = 4; key.attenuationEndDistance = 40; key.attenuationFalloffExponent = 0
        let keyNode = SCNNode(); keyNode.light = key; keyNode.simdPosition = Playground.keyPosition; keyNode.simdLook(at: Playground.keyTarget)
        booth.rootNode.addChildNode(keyNode)
        let fill = SCNLight(); fill.type = .ambient; fill.intensity = Playground.fillIntensity
        let fillNode = SCNNode(); fillNode.light = fill; booth.rootNode.addChildNode(fillNode)
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(Playground.canvasSize.y * 0.5 * 0.99)
        camera.zNear = 0.1; camera.zFar = 20
        camera.wantsHDR = true; camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.5; camera.minimumExposure = -2; camera.maximumExposure = 2
        let lens = SCNNode(); lens.camera = camera; lens.simdPosition = SIMD3(0, 0.1, 5)
        booth.rootNode.addChildNode(lens)
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = booth; renderer.pointOfView = lens
        return try #require(renderer.snapshot(atTime: 0, with: CGSize(width: 640, height: 400), antialiasingMode: .none).cgImageValue)
    }

    private func replay(color: SIMD3<Float>) throws -> CGImage {
        let events: [RecordedEvent] = (0..<30).map { k in
            let x = -2 + Float(k) * 0.14
            return .dab(RecordedDab(t: Double(k) / 60, from: SIMD2(x, 0.1), to: SIMD2(x + 0.14, 0.1), radius: 0.6, speed: 0.5, color: color, seed: 1, strokeSeed: 1, style: .brush, drag: nil, ncaModel: 0, brush: .butterfly))
        }
        let timeline = ReplayTimeline(eventTimes: events.map(\.t))
        let replayer = try #require(PaintLayerReplayer(recording: StrokeRecording(events: events), timeline: timeline))
        let scene = SCNScene()
        scene.background.contents = PlatformColor.black
        scene.rootNode.addChildNode(replayer.node)
        replayer.prepare(scene: scene)
        replayer.advance(to: timeline.duration)
        let lens = SCNNode(); lens.camera = SCNCamera()
        lens.camera?.usesOrthographicProjection = true
        lens.camera?.orthographicScale = 2
        lens.camera?.zNear = 0.1; lens.camera?.zFar = 30
        lens.simdPosition = SIMD3(0, 0, 10)
        scene.rootNode.addChildNode(lens)
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene; renderer.pointOfView = lens
        return try #require(renderer.snapshot(atTime: 0, with: CGSize(width: 640, height: 400), antialiasingMode: .none).cgImageValue)
    }


    private func stroke(from x0: Float, to x1: Float, at t0: Double, color: SIMD3<Float>, y: Float = 0.1,
                        dabs: Int = 30) -> [RecordedEvent] {
        (0..<dabs).map { k in
            let a = x0 + (x1 - x0) * Float(k) / Float(dabs)
            let b = x0 + (x1 - x0) * Float(k + 1) / Float(dabs)
            return .dab(RecordedDab(t: t0 + Double(k) / 60, from: SIMD2(a, y), to: SIMD2(b, y), radius: 0.6, speed: 0.5,
                                    color: color, seed: 1, strokeSeed: Float(t0), style: .brush, drag: nil,
                                    ncaModel: 0, brush: .butterfly))
        }
    }

    private func snapshot(_ replayer: PaintLayerReplayer, _ scene: SCNScene, _ lens: SCNNode) throws -> CGImage {
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = lens
        return try #require(renderer.snapshot(atTime: 0, with: CGSize(width: 640, height: 400),
                                              antialiasingMode: .none).cgImageValue)
    }

    private func review(_ replayer: PaintLayerReplayer) -> (SCNScene, SCNNode) {
        let scene = SCNScene()
        scene.background.contents = PlatformColor.black
        scene.rootNode.addChildNode(replayer.node)
        replayer.prepare(scene: scene)
        let lens = SCNNode()
        lens.camera = SCNCamera()
        lens.camera?.usesOrthographicProjection = true
        lens.camera?.orthographicScale = 2
        lens.camera?.zNear = 0.1
        lens.camera?.zFar = 30
        lens.simdPosition = SIMD3(0, 0, 10)
        scene.rootNode.addChildNode(lens)
        return (scene, lens)
    }

    @Test func replayMatchesThePhotoBoothsBrightness() throws {
        for color in [SIMD3<Float>(0.9, 0.2, 0.3), SIMD3(0.2, 0.4, 0.9), SIMD3(0.95, 0.85, 0.2)] {
            let events = stroke(from: -2, to: 2, at: 0, color: color)
            let timeline = ReplayTimeline(eventTimes: events.map(\.t))
            let replayer = try #require(PaintLayerReplayer(recording: StrokeRecording(events: events), timeline: timeline))
            let (scene, lens) = review(replayer)
            replayer.advance(to: timeline.duration)
            let replayed = meanRGB(try snapshot(replayer, scene, lens), x: 250, y: 190, w: 140, h: 20)
            let photographed = meanRGB(try reference(color: color), x: 250, y: 190, w: 140, h: 20)
            for channel in 0..<3 {
                #expect(abs(replayed[channel] - photographed[channel]) < 10,
                        "\(color) channel \(channel): replay \(replayed[channel]) vs photo \(photographed[channel])")
            }
        }
    }

    /// The point of the replay: it shows how the painting was at each moment, not the finished picture.
    @Test func replayIsSequentialNotTheFinishedPicture() throws {
        let red = SIMD3<Float>(0.9, 0.1, 0.1)
        let blue = SIMD3<Float>(0.1, 0.1, 0.9)
        // Red across the middle, a pause, then blue painted over the right half.
        let events = stroke(from: -2, to: 2, at: 0, color: red) + stroke(from: 0, to: 2, at: 1, color: blue, dabs: 20)
        let timeline = ReplayTimeline(eventTimes: events.map(\.t))
        let replayer = try #require(PaintLayerReplayer(recording: StrokeRecording(events: events), timeline: timeline))
        let (scene, lens) = review(replayer)

        replayer.advance(to: timeline.replayTime(forRecorded: 0.8))
        let early = meanRGB(try snapshot(replayer, scene, lens), x: 400, y: 190, w: 100, h: 20)
        #expect(early.x > early.z + 60, "before the blue is painted the right half is still red: \(early)")

        replayer.advance(to: timeline.duration)
        let late = meanRGB(try snapshot(replayer, scene, lens), x: 400, y: 190, w: 100, h: 20)
        #expect(late.z > late.x + 60, "after the blue is painted the right half is blue: \(late)")
    }
}

import CoreGraphics
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

    // MARK: Backdrops

    /// Share of green-dominant pixels, and the mean green and blue, of an image shrunk to 100x62.
    private func colors(of image: PlatformImage?) -> (greenShare: Float, meanGreen: Float, meanBlue: Float)? {
        #if os(macOS)
        guard let cg = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = 100, h = 62
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var greens = 0
        var sumG: Float = 0, sumB: Float = 0
        for i in 0..<(w * h) {
            let r = Float(data[i * 4]) / 255, g = Float(data[i * 4 + 1]) / 255, b = Float(data[i * 4 + 2]) / 255
            if g > r + 0.03 && g > b + 0.03 { greens += 1 }
            sumG += g
            sumB += b
        }
        let n = Float(w * h)
        return (Float(greens) / n, sumG / n, sumB / n)
        #else
        return nil
        #endif
    }

    @Test func studioBackdropHasLeafLight() throws {
        let stats = try #require(colors(of: Studio.backdrop()))
        #expect(stats.greenShare >= 0.25)
    }

    @Test func galleryBackdropIsGreenNotMuseumGrey() throws {
        let stats = try #require(colors(of: GalleryHall.backdrop()))
        #expect(stats.greenShare >= 0.15)
        #expect(stats.meanGreen > stats.meanBlue)
    }
}

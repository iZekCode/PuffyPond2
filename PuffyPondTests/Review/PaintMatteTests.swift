import Foundation
import CoreGraphics
import Testing
@testable import PuffyPond

struct PaintMatteTests {
    /// An image of opaque pixels in one row.
    private func image(_ pixels: [(UInt8, UInt8, UInt8)]) -> CGImage {
        let data = Data(pixels.flatMap { [$0.0, $0.1, $0.2, 255] })
        return CGImage(width: pixels.count, height: 1, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: pixels.count * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }

    private func bytes(_ image: CGImage) -> [UInt8] {
        let data = image.dataProvider!.data!
        var out = [UInt8](repeating: 0, count: CFDataGetLength(data))
        CFDataGetBytes(data, CFRange(location: 0, length: out.count), &out)
        return out
    }

    @Test func recoversAlphaAndPremultipliedColor() throws {
        // Clear, solid orange, and half-covered orange (200, 100, 0 · 0.5).
        let black = image([(0, 0, 0), (255, 128, 0), (100, 50, 0)])
        let white = image([(255, 255, 255), (255, 128, 0), (100 + 128, 50 + 128, 128)])
        let matte = try #require(PaintMatte.extract(onBlack: black, onWhite: white))
        let out = bytes(matte)
        #expect(Array(out[0..<4]) == [0, 0, 0, 0])
        #expect(Array(out[4..<8]) == [255, 128, 0, 255])
        #expect(abs(Int(out[11]) - 127) <= 1)
        #expect(Array(out[8..<11]) == [100, 50, 0])
    }

    @Test func dimBackdropIsCalibratedAway() throws {
        // The booth renders "white" as 200 and "black" as 10: a clear pixel, then half-covered orange
        // (200, 100, 0) · 0.5 over each backdrop.
        let black = image([(10, 10, 10), (100 + 5, 50 + 5, 5)])
        let white = image([(200, 200, 200), (100 + 100, 50 + 100, 100)])
        let matte = try #require(PaintMatte.extract(onBlack: black, onWhite: white, blackLevel: 10, whiteLevel: 200))
        let out = bytes(matte)
        #expect(Array(out[0..<4]) == [0, 0, 0, 0])
        #expect(abs(Int(out[7]) - 127) <= 1)
        #expect(abs(Int(out[4]) - 100) <= 1)
    }

    @Test func faintHazeBelowTheFloorIsDropped() throws {
        // Over black 20 and over white 245 is alpha ≈ 0.12 of dark sheen; solid orange is untouched.
        let black = image([(20, 20, 20), (255, 128, 0)])
        let white = image([(245, 245, 245), (255, 128, 0)])
        let matte = try #require(PaintMatte.extract(onBlack: black, onWhite: white, floor: PaintMatte.sheenFloor))
        let out = bytes(matte)
        #expect(Array(out[0..<4]) == [0, 0, 0, 0])
        #expect(Array(out[4..<8]) == [255, 128, 0, 255])
    }

    @Test func levelIsTheMeanBrightness() {
        #expect(PaintMatte.level(of: image([(10, 20, 30), (30, 40, 50)])) == 30)
    }

    @Test func mismatchedShotsGiveNothing() {
        #expect(PaintMatte.extract(onBlack: image([(0, 0, 0)]), onWhite: image([(0, 0, 0), (0, 0, 0)])) == nil)
    }
}

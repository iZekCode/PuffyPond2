import CoreGraphics
import simd

/// A picture of the canvas that fills in white where paint has been laid (premultiplied, so its colour and alpha
/// both run from 0 to 1): the reveal for the timelapse.
/// It is a class because it owns a bitmap that must not be shared by copies.
final class RevealMask {
    static let width = 640
    static let height = 400
    /// The paint stamp spreads past the brush radius; the reveal is drawn this much wider than the brush.
    static let footprint: CGFloat = 1.5

    private let context: CGContext
    private let size = Playground.canvasSize
    /// The canvas is centred here (matches `Playground`'s paint layer).
    private let center = SIMD2<Float>(0, 0.1)

    init() {
        context = CGContext(data: nil, width: Self.width, height: Self.height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 1)
    }

    /// A round-capped line from `dab.from` to `dab.to`, as wide as the brush.
    func reveal(_ dab: RecordedDab) {
        let scale = CGFloat(Self.width) / CGFloat(size.x)
        let from = pixel(dab.from)
        let to = pixel(dab.to)
        context.setLineWidth(CGFloat(dab.radius) * 2 * Self.footprint * scale)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
    }

    /// Shows everything at once, without drawing any stroke.
    func revealAll() {
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
    }

    func clear() {
        context.clear(CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
    }

    /// 0 (hidden) to 1 (fully revealed) at a point of the canvas, in world units.
    func coverage(atWorld p: SIMD2<Float>) -> Float {
        let point = pixel(p)
        let column = Int(point.x)
        let row = Self.height - 1 - Int(point.y)
        guard column >= 0, column < Self.width, row >= 0, row < Self.height, let data = context.data else { return 0 }
        return Float(data.load(fromByteOffset: row * context.bytesPerRow + column * 4 + 3, as: UInt8.self)) / 255
    }

    var image: CGImage { context.makeImage()! }

    /// World → pixels with y up (the context's own space).
    private func pixel(_ p: SIMD2<Float>) -> CGPoint {
        let origin = center - size / 2
        return CGPoint(x: CGFloat((p.x - origin.x) / size.x) * CGFloat(Self.width),
                       y: CGFloat((p.y - origin.y) / size.y) * CGFloat(Self.height))
    }
}

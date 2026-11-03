import SceneKit
import CoreGraphics
import simd

/// A real-looking painter's studio around the canvas: an out-of-focus room lit by a window,
/// primed linen with a woven surface, and a wooden easel with grain. All textures are generated.
enum Studio {
    // MARK: Noise

    private static func hash(_ x: Int, _ y: Int, _ seed: Int = 0) -> Float {
        var h = UInt32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263 &+ seed &* 982_451_653)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Float(h & 0xFFFF) / 65_535
    }

    /// Smooth value noise in 0…1 that tiles every `period` cells.
    private static func noise(_ x: Float, _ y: Float, period: Int = 1 << 20, seed: Int = 0) -> Float {
        let i = Int(x.rounded(.down)), j = Int(y.rounded(.down))
        let fx = x - Float(i), fy = y - Float(j)
        let u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy)
        func h(_ a: Int, _ b: Int) -> Float {
            hash(((a % period) + period) % period, ((b % period) + period) % period, seed)
        }
        let a = h(i, j), b = h(i + 1, j), c = h(i, j + 1), d = h(i + 1, j + 1)
        return (a + (b - a) * u) + ((c + (d - c) * u) - (a + (b - a) * u)) * v
    }

    /// An RGBA bitmap filled pixel by pixel (values 0…1).
    private static func bitmap(width: Int, height: Int, _ pixel: (Int, Int) -> SIMD4<Float>) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let c = simd_clamp(pixel(x, y), SIMD4(repeating: 0), SIMD4(repeating: 1)) * 255
                let k = (y * width + x) * 4
                bytes[k] = UInt8(c.x)
                bytes[k + 1] = UInt8(c.y)
                bytes[k + 2] = UInt8(c.z)
                bytes[k + 3] = UInt8(c.w)
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// A tangent-space normal map from a tiling height function.
    private static func normalMap(size: Int, strength: Float, height: (Int, Int) -> Float) -> CGImage? {
        var h = [Float](repeating: 0, count: size * size)
        for y in 0..<size { for x in 0..<size { h[y * size + x] = height(x, y) } }
        func at(_ x: Int, _ y: Int) -> Float { h[((y + size) % size) * size + (x + size) % size] }
        return bitmap(width: size, height: size) { x, y in
            let n = simd_normalize(SIMD3((at(x - 1, y) - at(x + 1, y)) * strength,
                                         (at(x, y + 1) - at(x, y - 1)) * strength, 1))
            return SIMD4(n * 0.5 + 0.5, 1)
        }
    }

    // MARK: Primed linen

    static let weaveTile = 512
    static let threadsPerTile = 32
    /// World size of one weave tile (the paint shader draws the same weave under thin paint).
    static let weaveTileSize: Float = 0.2

    /// Height of the woven threads (0…1): warp and weft passing over and under each other.
    private static func weave(_ x: Int, _ y: Int) -> Float {
        let p = weaveTile / threadsPerTile
        let i = x / p, j = y / p
        let u = Float(x % p) / Float(p), v = Float(y % p) / Float(p)
        // Threads wobble a little in thickness, like real linen.
        let slub = 0.85 + 0.3 * noise(Float(x) / 9, Float(j) * 3.1, period: weaveTile / 9 + 1, seed: 3)
        let warp = sin(.pi * u) * slub
        let weft = sin(.pi * v) * (0.85 + 0.3 * noise(Float(i) * 3.1, Float(y) / 9, seed: 5))
        let fiber = 0.08 * noise(Float(x) * 0.7, Float(y) * 0.7, period: weaveTile * 7 / 10, seed: 9)
        let warpOnTop = (i + j) % 2 == 0
        let top = warpOnTop ? warp * (0.75 + 0.25 * sin(.pi * v)) : weft * (0.75 + 0.25 * sin(.pi * u))
        let under = (warpOnTop ? weft : warp) * 0.55
        return max(top, under) + fiber
    }

    /// Primed linen: near-white with a fine, soft weave catching the light.
    static func canvasMaterial(repeats: SIMD2<Float>) -> SCNMaterial {
        let size = weaveTile
        let albedo = bitmap(width: size, height: size) { x, y in
            let h = weave(x, y)
            let tone = 0.96 + 0.015 * h + 0.02 * noise(Float(x) / 40, Float(y) / 40, period: size / 40 + 1, seed: 11)
            return SIMD4(SIMD3<Float>(0.95, 0.95, 0.93) * tone, 1)
        }
        let normals = normalMap(size: size, strength: 0.8, height: weave)
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = Toybox.platformImage(albedo)
        m.normal.contents = Toybox.platformImage(normals)
        m.roughness.contents = NSNumber(value: 0.92)
        m.metalness.contents = NSNumber(value: 0.0)
        for p in [m.diffuse, m.normal] {
            p.wrapS = .repeat
            p.wrapT = .repeat
            p.contentsTransform = SCNMatrix4(simd_float4x4(diagonal: SIMD4(repeats.x, repeats.y, 1, 1)))
            p.mipFilter = .linear
        }
        return m
    }

    // MARK: The room

    private static func softBlob(_ ctx: CGContext, at c: CGPoint, radius: CGFloat, color: SIMD4<Float>,
                                 scaleY: CGFloat = 1) {
        let space = CGColorSpaceCreateDeviceRGB()
        let inner = CGColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: CGFloat(color.w))
        guard let g = CGGradient(colorsSpace: space, colors: [inner, inner.copy(alpha: 0) ?? inner] as CFArray,
                                 locations: [0, 1]) else { return }
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.scaleBy(x: 1, y: scaleY)
        ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
        ctx.restoreGState()
    }

    /// The room behind the easel, as if shot with a shallow depth of field: the inside of a treehouse, with
    /// honey-coloured planks, a bright window ringed with leaves, string lights, hanging foliage and a
    /// wooden floor — everything out of focus.
    static func backdrop() -> PlatformImage? {
        let w = 1600, h = 1000
        return Toybox.platformImage(Toybox.image(width: w, height: h) { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            var seed: UInt32 = 11
            func random() -> CGFloat {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                return CGFloat(seed >> 8) / CGFloat(1 << 24)
            }
            func leaf(x: CGFloat, y: CGFloat, radius: ClosedRange<CGFloat>) {
                let r = radius.lowerBound + random() * (radius.upperBound - radius.lowerBound)
                let g = Float(0.5 + 0.28 * random())
                softBlob(ctx, at: CGPoint(x: x, y: y), radius: r, color: SIMD4(0.2 + 0.14 * Float(random()), g, 0.15 + 0.1 * Float(random()), 0.8),
                         scaleY: 1.25)
            }
            // Planked wall: honey wood, brighter near the window.
            let wall = [CGColor(red: 0.82, green: 0.64, blue: 0.43, alpha: 1),
                        CGColor(red: 0.69, green: 0.51, blue: 0.34, alpha: 1),
                        CGColor(red: 0.55, green: 0.4, blue: 0.27, alpha: 1)] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: wall, locations: [0, 0.6, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(h)), end: CGPoint(x: CGFloat(w), y: 0), options: [])
            }
            for k in 0..<10 {   // plank seams and uneven planks
                ctx.setFillColor(CGColor(red: 0.3, green: 0.2, blue: 0.12, alpha: 0.12))
                ctx.fill(CGRect(x: CGFloat(k) * 165 + 20, y: 0, width: 7, height: CGFloat(h)))
                ctx.setFillColor(CGColor(red: 1, green: 0.9, blue: 0.7, alpha: 0.05 * random()))
                ctx.fill(CGRect(x: CGFloat(k) * 165 + 27, y: 0, width: 158, height: CGFloat(h)))
            }
            // The window: a pool of bright green-gold daylight on the left, ringed with leaves.
            softBlob(ctx, at: CGPoint(x: 260, y: 650), radius: 330, color: SIMD4(0.93, 0.98, 0.72, 0.95), scaleY: 1.25)
            softBlob(ctx, at: CGPoint(x: 240, y: 680), radius: 170, color: SIMD4(1, 1, 0.9, 0.95), scaleY: 1.4)
            for _ in 0..<32 {
                let angle = random() * 2 * .pi
                let distance = 230 + random() * 130
                leaf(x: 260 + cos(angle) * distance * 1.15, y: 650 + sin(angle) * distance * 1.1, radius: 40...95)
            }
            // Dappled sunlight on the planks.
            for _ in 0..<12 {
                softBlob(ctx, at: CGPoint(x: 100 + random() * 1300, y: 150 + random() * 650), radius: 40 + random() * 60,
                         color: SIMD4(1, 0.96, 0.7, 0.22), scaleY: 0.9)
            }
            // Wooden floor along the bottom, blurred.
            let floor = [CGColor(red: 0.5, green: 0.36, blue: 0.24, alpha: 0),
                         CGColor(red: 0.5, green: 0.36, blue: 0.24, alpha: 0.9),
                         CGColor(red: 0.4, green: 0.28, blue: 0.18, alpha: 1)] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: floor, locations: [0, 0.35, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 260), end: CGPoint(x: 0, y: 0), options: [])
            }
            // Foliage climbing in from the right, and a fringe hanging from the roof.
            for _ in 0..<52 { leaf(x: 1100 + random() * 450, y: 180 + random() * 700, radius: 45...100) }
            for _ in 0..<26 { leaf(x: random() * 1600, y: 900 + random() * 120, radius: 40...90) }
            // String lights swagged across the top.
            for k in 0..<15 {
                let x = 60 + CGFloat(k) * 105
                let y = 850 - sin(CGFloat(k) / 14 * .pi) * 70 - (k % 2 == 0 ? 0 : 16)
                softBlob(ctx, at: CGPoint(x: x, y: y), radius: 34, color: SIMD4(1, 0.9, 0.5, 0.95))
                softBlob(ctx, at: CGPoint(x: x, y: y), radius: 12, color: SIMD4(1, 1, 0.9, 1))
            }
            // Gentle corner shading (lens vignette in the photo).
            softBlob(ctx, at: CGPoint(x: CGFloat(w) / 2, y: CGFloat(h) / 2), radius: 900,
                     color: SIMD4(1, 1, 1, 0.1), scaleY: 0.7)
        })
    }

    /// Light coming into the room: a bright window on one side, warm walls, a darker wooden floor.
    static func environment() -> PlatformImage? {
        Toybox.platformImage(Toybox.image(width: 512, height: 256) { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [CGColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1),
                          CGColor(red: 0.85, green: 0.81, blue: 0.75, alpha: 1),
                          CGColor(red: 0.42, green: 0.32, blue: 0.24, alpha: 1)] as CFArray
            if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 256), end: CGPoint(x: 0, y: 0), options: [])
            }
            softBlob(ctx, at: CGPoint(x: 150, y: 165), radius: 70, color: SIMD4(1, 1, 0.97, 1), scaleY: 1.3)
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 0.98, alpha: 1))
            ctx.fill(CGRect(x: 120, y: 130, width: 60, height: 70))
        })
    }
}

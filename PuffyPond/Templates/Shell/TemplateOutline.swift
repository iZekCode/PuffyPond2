import SceneKit
import simd

extension OutlineArt {
    /// The outline drawn solid in the art's color, on a transparent square.
    func iconImage(side: Int = 256) -> CGImage? {
        let shape = shape(center: SIMD2(0.5, 0.5), size: SIMD2(0.86, 0.86))
        let c = color
        let ink = CGColor(red: CGFloat(c.x) * 0.8, green: CGFloat(c.y) * 0.8, blue: CGFloat(c.z) * 0.8, alpha: 1)
        let unit = CGFloat(side) / 256
        return Toybox.image(width: side, height: side) { ctx in
            func px(_ p: SIMD2<Float>) -> CGPoint { CGPoint(x: CGFloat(p.x) * CGFloat(side), y: CGFloat(p.y) * CGFloat(side)) }
            ctx.setStrokeColor(ink)
            ctx.setFillColor(ink)
            ctx.setLineWidth(14 * unit)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for line in shape.lines {
                ctx.move(to: px(line[0]))
                for p in line.dropFirst() { ctx.addLine(to: px(p)) }
                ctx.strokePath()
            }
            for eye in shape.eyes {
                let e = px(eye)
                ctx.fillEllipse(in: CGRect(x: e.x - 10 * unit, y: e.y - 10 * unit, width: 20 * unit, height: 20 * unit))
            }
        }
    }
}

/// The dotted outline lying on the canvas, just under the paint.
final class TemplateOutline {
    /// The template it came from (nil for a daily-quest outline).
    let kind: TemplateKind?
    /// The outline's polylines in world units (y up), for the tracing guide.
    let lines: [[SIMD2<Float>]]
    let node = SCNNode()
    private let material = SCNMaterial()
    private let origin: SIMD2<Float>        // bottom-left of the canvas
    private let size: SIMD2<Float>
    private var marks: [[SIMD2<Float>]]     // dashes; a single point is an eye dot
    private var dirty = true
    private var fading = false

    private static let pixelsPerUnit: Float = 200
    private static let lineWidth: Float = 0.06
    private static let eyeRadius: Float = 0.07
    private static let dash: Float = 0.18
    private static let gap: Float = 0.14
    private static let ink = CGColor(red: 0.42, green: 0.36, blue: 0.3, alpha: 0.5)

    convenience init(kind: TemplateKind, canvasCenter: SIMD2<Float>, canvasSize: SIMD2<Float>, z: Float) {
        self.init(art: kind.art, kind: kind, canvasCenter: canvasCenter, canvasSize: canvasSize, z: z)
    }

    init(art: OutlineArt, kind: TemplateKind? = nil, canvasCenter: SIMD2<Float>, canvasSize: SIMD2<Float>, z: Float) {
        self.kind = kind
        origin = canvasCenter - canvasSize * 0.5
        size = canvasSize
        // Big and bold so small kids can follow it; nudged up a little, clear of the bubbles on the tray.
        let shape = art.shape(center: canvasCenter + SIMD2(0, 0.15), size: canvasSize * SIMD2(0.72, 0.68) * art.spread)
        lines = shape.lines
        marks = shape.lines.flatMap { Self.dashes($0) } + shape.eyes.map { [$0] }

        let plane = SCNPlane(width: CGFloat(canvasSize.x), height: CGFloat(canvasSize.y))
        material.lightingModel = .physicallyBased
        material.roughness.contents = NSNumber(value: 1.0)
        material.metalness.contents = NSNumber(value: 0.0)
        material.transparencyMode = .aOne
        material.writesToDepthBuffer = false
        plane.materials = [material]
        node.geometry = plane
        node.castsShadow = false
        node.simdPosition = SIMD3(canvasCenter.x, canvasCenter.y, z)
        node.opacity = 0
        node.runAction(.fadeIn(duration: 0.4))
        render()
    }

    /// How many dashes and eye dots are left to trace.
    var markCount: Int { marks.count }

    func update() {
        if dirty { render() }
    }

    /// Fades out and leaves the scene.
    func fadeAway() {
        fading = true
        node.runAction(.sequence([.fadeOut(duration: 0.35), .removeFromParentNode()]))
    }

    private func render() {
        dirty = false
        let s = Self.pixelsPerUnit
        let image = Toybox.image(width: Int(size.x * s), height: Int(size.y * s)) { ctx in
            func px(_ p: SIMD2<Float>) -> CGPoint {
                CGPoint(x: CGFloat((p.x - origin.x) * s), y: CGFloat((p.y - origin.y) * s))
            }
            ctx.setStrokeColor(Self.ink)
            ctx.setFillColor(Self.ink)
            ctx.setLineWidth(CGFloat(Self.lineWidth * s))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for mark in marks {
                if mark.count == 1 {
                    let c = px(mark[0])
                    let r = CGFloat(Self.eyeRadius * s)
                    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                } else {
                    ctx.move(to: px(mark[0]))
                    for p in mark.dropFirst() { ctx.addLine(to: px(p)) }
                    ctx.strokePath()
                }
            }
        }
        material.diffuse.contents = Toybox.platformImage(image)
    }

    /// Cuts a polyline into dashes of `dash` length separated by `gap`.
    private static func dashes(_ line: [SIMD2<Float>]) -> [[SIMD2<Float>]] {
        guard let first = line.first else { return [] }
        var out: [[SIMD2<Float>]] = []
        var piece = [first]
        var drawing = true
        var left = dash
        for (start, end) in zip(line, line.dropFirst()) {
            var a = start
            var length = simd_distance(a, end)
            while length > 0 && length >= left {
                let q = a + (end - a) * (left / length)
                if drawing {
                    piece.append(q)
                    out.append(piece)
                } else {
                    piece = [q]
                }
                drawing.toggle()
                a = q
                length -= left
                left = drawing ? dash : gap
            }
            left -= length
            if drawing { piece.append(end) }
        }
        if drawing && piece.count > 1 { out.append(piece) }
        return out
    }
}

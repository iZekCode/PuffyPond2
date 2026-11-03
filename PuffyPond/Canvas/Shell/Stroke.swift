import SceneKit
import simd

/// The path of one brush stroke: what the critter drew, in which color, with which brush animal.
/// (What you *see* is the PaintLayer; this tracks what's been drawn so far, for erasing.)
final class Stroke {
    let node = SCNNode()
    let color: SIMD3<Float>
    let radius: Float
    let surfaceZ: Float
    let brush: CritterKind
    private(set) var points: [StrokePoint] = []

    init(color: SIMD3<Float>, radius: Float, surfaceZ: Float, brush: CritterKind) {
        self.color = color
        self.radius = radius
        self.surfaceZ = surfaceZ
        self.brush = brush
    }

    var isEmpty: Bool { points.isEmpty }

    func add(_ p: SIMD2<Float>, now: Double) {
        points.append(StrokePoint(p: p, born: now))
    }

    func replacePoints(_ newPoints: [StrokePoint]) {
        points = newPoints
    }

    func update(now: Double) {}
    func pulse(_ amount: Float) {}
}

import SceneKit
import simd

/// A tentacle tip dragging across the canvas this frame.
struct TipStroke {
    var from: SIMD2<Float>
    var to: SIMD2<Float>
    var speed: Float
}

/// A stretch of a limb lying on the canvas this frame: it paints like a brush.
struct TentacleContact {
    var a: SIMD2<Float>         // the two ends of the stretch (canvas plane)
    var b: SIMD2<Float>
    var drag: SIMD2<Float>      // how far it moved this frame
    var radius: Float           // half the limb's width there
    var speed: Float
}

/// Soft, jiggly limbs: Verlet chains hanging from a body. Each remembers a curled rest shape
/// but lags, swings and wobbles whenever the body moves. Drawn as tapered tubes rebuilt every frame.
final class TentacleBundle {
    struct Limb {
        var points: [SIMD3<Float>]
        var previous: [SIMD3<Float>]
        let rootLocal: SIMD3<Float>    // where it leaves the body (body space)
        let outward: SIMD3<Float>      // which way it curls (body space)
        let phase: Float
        var lastTip: SIMD2<Float>?
        var lastXY: [SIMD2<Float>] = []   // every point's canvas position last frame (for contact drag)
        var spoke = SIMD2<Float>(0, -1)   // which way it points when lying flat on the canvas (unit, canvas plane)
    }

    struct Shape {
        var segments = 11
        var segmentLength: Float = 0.032
        var rootRadius: Float = 0.034
        var tipRadius: Float = 0.008
        var startAngle: Float = 0.45   // 0 = straight down, π/2 = straight out
        var curl: Float = 1.7          // how far the tip curls up and out
        var sway: Float = 0.28
        var stiffness: Float = 0.07    // shape memory near the root (the tip gets ~1/5 of it)
        var drag: Float = 0.975
        var gravity: Float = 1.2
        var ripple: Float = 0.15       // radius wobble along the limb
    }

    let node = SCNNode()                // world-space mesh
    private(set) var limbs: [Limb] = []
    private(set) var tipStrokes: [TipStroke] = []
    private(set) var contacts: [TentacleContact] = []
    private let shape: Shape
    /// The critter's accent material (set once the critter exists).
    var material = SCNMaterial()
    private static let sides = 10

    init(shape: Shape, roots: [(local: SIMD3<Float>, outward: SIMD3<Float>)], start: SIMD3<Float>) {
        self.shape = shape
        node.castsShadow = true
        for (k, r) in roots.enumerated() {
            let points = [SIMD3<Float>](repeating: start, count: shape.segments)
            limbs.append(Limb(points: points, previous: points, rootLocal: r.local, outward: simd_normalize(r.outward),
                              phase: Float(k) * 1.37))
        }
    }

    /// Which way each limb points when it lies flat on the canvas (`simulate(spread:)`), in limb order.
    func setSpokes(_ spokes: [SIMD2<Float>]) {
        for (k, s) in spokes.enumerated() where limbs.indices.contains(k) && simd_length(s) > 1e-4 {
            limbs[k].spoke = simd_normalize(s)
        }
    }

    /// Kick every limb outward (Verlet: shift the previous positions backward).
    func flare(_ amount: Float, body m: simd_float4x4) {
        for k in limbs.indices {
            let out = simd_normalize(simd_make_float3(m * SIMD4(limbs[k].outward, 0)) + SIMD3(0, 0.3, 0))
            for i in 1..<shape.segments {
                let t = Float(i) / Float(shape.segments - 1)
                limbs[k].previous[i] -= out * (0.012 * amount * t)
            }
        }
    }

    /// The curled rest shape of limb `k`, in body space: down and out, then curling at the tip,
    /// swaying gently even when nothing moves.
    private func restShape(_ k: Int, clock: Float) -> [SIMD3<Float>] {
        let limb = limbs[k]
        var p = limb.rootLocal
        var points = [p]
        for i in 1..<shape.segments {
            let t = Float(i) / Float(shape.segments - 1)
            let sway = shape.sway * (sin(clock * 1.7 + limb.phase + t * 3) + 0.43 * sin(clock * 3.1 + limb.phase * 2))
            let angle = shape.startAngle + shape.curl * t * t + sway * t
            p += (limb.outward * sin(angle) + SIMD3(0, -cos(angle), 0)) * shape.segmentLength
            points.append(p)
        }
        return points
    }

    /// - Parameters:
    ///   - body: the body's world transform (without squash).
    ///   - snap: jump straight to the rest shape (after a teleport).
    ///   - press: 0…1, how hard the limbs are pushed down onto the canvas plane `minZ` (the tips most).
    ///   - trail: 0…1, how much the limbs gather into one bundle streaming along `trailDirection` (canvas plane).
    ///   - spread: 0…1, how flat the limbs lie on the canvas, fanned out along their spokes like a star
    ///     (the roots sink down to the canvas too, so the whole length touches it).
    func simulate(dt: Float, body m: simd_float4x4, scale: Float, clock: Float, beatPulse: Float, snap: Bool,
                  press: Float = 0, minZ: Float = 0.1, trail: Float = 0, trailDirection: SIMD2<Float> = .zero,
                  spread: Float = 0) {
        func world(_ local: SIMD3<Float>) -> SIMD3<Float> { simd_make_float3(m * SIMD4(local, 1)) }
        let length = shape.segmentLength * scale
        let steps = max(1, Int((dt * 120).rounded(.up)))
        let h = dt / Float(steps)
        let gravity = SIMD3<Float>(0, -shape.gravity, 0) * h * h
        let n = shape.segments
        let roots = limbs.map { world($0.rootLocal) }
        let center = roots.reduce(.zero, +) / Float(max(roots.count, 1))

        for k in limbs.indices {
            var rest = restShape(k, clock: clock).map(world)
            if spread > 0.01 {
                // Lying flat: each limb fans out along its spoke with a slow side-to-side ripple, root sunk to the canvas.
                let spoke = limbs[k].spoke
                let side = SIMD2(-spoke.y, spoke.x)
                rest[0].z += (minZ + 0.025 - rest[0].z) * spread
                for i in 1..<n {
                    let t = Float(i) / Float(n - 1)
                    let wave = sin(clock * 1.3 + limbs[k].phase + t * 4) * length * 0.35 * t
                    let reach = Float(i) * length * 0.97
                    var p = rest[0]
                    p.x += spoke.x * reach + side.x * wave
                    p.y += spoke.y * reach + side.y * wave
                    p.z = rest[0].z + (minZ - rest[0].z) * min(1, t * 4)
                    rest[i] += (p - rest[i]) * spread
                }
            }
            if trail > 0.01 {
                // Wiping: the limb lies behind the head along the stroke, drawn in toward the middle so all of them
                // end up side by side, with a little wobble along the way.
                let dir = SIMD3(trailDirection.x, trailDirection.y, 0)
                let side = SIMD3(-trailDirection.y, trailDirection.x, 0)
                let lateral = simd_dot(rest[0] - center, side)
                for i in 1..<n {
                    let t = Float(i) / Float(n - 1)
                    var p = rest[0] + dir * (Float(i) * length * 0.95)
                    p += side * (-lateral * 0.6 * t + sin(clock * 7 + limbs[k].phase + t * 5) * length * 0.25 * t)
                    p.z = rest[0].z + (minZ - rest[0].z) * min(1, t * 3)
                    rest[i] += (p - rest[i]) * trail
                }
            }
            if snap {
                limbs[k].points = rest
                limbs[k].previous = rest
                continue
            }
            var points = limbs[k].points
            var previous = limbs[k].previous
            for _ in 0..<steps {
                points[0] = rest[0]
                previous[0] = rest[0]
                for i in 1..<n {
                    let t = Float(i) / Float(n - 1)
                    let velocity = (points[i] - previous[i]) * shape.drag
                    previous[i] = points[i]
                    // Shape memory: stiff near the body, floppy toward the tip.
                    let pull = shape.stiffness * (1 - 0.8 * t) * (1 + beatPulse * 0.5) * (1 + 3 * trail + 2 * spread)
                    points[i] += velocity + (rest[i] - points[i]) * pull + gravity
                }
                for _ in 0..<3 {
                    for i in 1..<n {
                        let delta = points[i] - points[i - 1]
                        let d = max(simd_length(delta), 1e-6)
                        let fix = delta * ((d - length) / d)
                        if i == 1 {
                            points[i] -= fix
                        } else {
                            points[i] -= fix * 0.5
                            points[i - 1] += fix * 0.5
                        }
                    }
                    points[0] = rest[0]
                }
                // Pressed down, a limb lies on the canvas; it never pokes through it.
                if press > 0 {
                    for i in 1..<n where points[i].z > minZ {
                        let t = Float(i) / Float(n - 1)
                        points[i].z += (minZ - points[i].z) * press * (0.04 + 0.2 * t * t)
                    }
                }
                for i in 1..<n where points[i].z < minZ { points[i].z = minZ }
            }
            limbs[k].points = points
            limbs[k].previous = previous
        }
    }

    /// Records where each tip moved this frame (only kept while `painting`).
    func collectTips(dt: Float, painting: Bool) {
        tipStrokes.removeAll(keepingCapacity: true)
        for k in limbs.indices {
            let tip3 = limbs[k].points[shape.segments - 1]
            let tip = SIMD2(tip3.x, tip3.y)
            if painting, let last = limbs[k].lastTip {
                tipStrokes.append(TipStroke(from: last, to: tip, speed: simd_distance(last, tip) / max(dt, 1e-4)))
            }
            limbs[k].lastTip = tip
        }
    }

    /// The stretches of every limb that lie on the canvas this frame (only kept while `painting`).
    /// Each covers two links, so a full limb (root to tip) makes five.
    func collectContacts(dt: Float, painting: Bool, scale: Float, contactZ: Float) {
        contacts.removeAll(keepingCapacity: true)
        let n = shape.segments
        for k in limbs.indices {
            let p = limbs[k].points
            let xy = p.map { SIMD2($0.x, $0.y) }
            defer { limbs[k].lastXY = xy }
            guard painting, limbs[k].lastXY.count == n else { continue }
            // The root end may still hang a little above the canvas under the head; the far end must touch.
            for i in stride(from: 0, to: n - 1, by: 2) where p[i + 2].z <= contactZ && (i == 0 || p[i].z <= contactZ) {
                let t = Float(i + 1) / Float(n - 1)
                let radius = max((shape.rootRadius * (1 - t) + shape.tipRadius) * scale * 1.6, 0.016)
                let drag = xy[i + 1] - limbs[k].lastXY[i + 1]
                contacts.append(TentacleContact(a: xy[i], b: xy[i + 2], drag: drag, radius: radius,
                                                speed: simd_length(drag) / max(dt, 1e-4)))
            }
        }
    }

    /// Tapered tubes along every chain (parallel-transported rings so they never twist), with a round tip.
    func rebuild(scale: Float, clock: Float, hidden: Bool) {
        guard !hidden else {
            node.geometry = nil
            return
        }
        let n = shape.segments, sides = Self.sides
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(limbs.count * (n * sides + 1))
        normals.reserveCapacity(positions.capacity)

        for limb in limbs {
            let p = limb.points
            let base = UInt32(positions.count)
            var tangent = simd_normalize(p[1] - p[0] + SIMD3(0, -1e-5, 0))
            var normal = simd_normalize(simd_cross(tangent, SIMD3(0, 0, 1)) + SIMD3(1e-5, 0, 0))
            for i in 0..<n {
                let next = i < n - 1 ? p[i + 1] : p[i] + (p[i] - p[i - 1])
                let prev = i > 0 ? p[i - 1] : p[i] - (p[i + 1] - p[i])
                let newTangent = simd_normalize(next - prev + SIMD3(0, -1e-6, 0))
                // Parallel transport: keep the previous normal, minus the part along the new tangent.
                normal = simd_normalize(normal - newTangent * simd_dot(normal, newTangent))
                tangent = newTangent
                let binormal = simd_cross(tangent, normal)
                let t = Float(i) / Float(n - 1)
                let radius = (shape.rootRadius * (1 - t) + shape.tipRadius)
                    * (1 + shape.ripple * sin(t * 9 + clock * 3 + limb.phase) * t) * scale
                for s in 0..<sides {
                    let a = Float(s) / Float(sides) * 2 * .pi
                    let dir = normal * cos(a) + binormal * sin(a)
                    positions.append(p[i] + dir * radius)
                    normals.append(dir)
                }
            }
            for i in 0..<(n - 1) {
                for s in 0..<sides {
                    let a = base + UInt32(i * sides + s)
                    let b = base + UInt32(i * sides + (s + 1) % sides)
                    let c = b + UInt32(sides)
                    let d = a + UInt32(sides)
                    indices.append(contentsOf: [a, b, c, a, c, d])
                }
            }
            let tipIndex = UInt32(positions.count)
            positions.append(p[n - 1] + tangent * shape.tipRadius * scale)
            normals.append(tangent)
            let last = base + UInt32((n - 1) * sides)
            for s in 0..<sides {
                indices.append(contentsOf: [last + UInt32(s), last + UInt32((s + 1) % sides), tipIndex])
            }
        }
        let geometry = MeshBuilder.geometry(positions: positions, normals: normals, indices: indices)
        geometry.materials = [material]
        node.geometry = geometry
    }
}

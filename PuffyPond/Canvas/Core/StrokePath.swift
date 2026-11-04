import simd

/// How a stroke's path grows while painting and splits while erasing.
enum StrokePath {
    /// The points to add on the way from the last bead to `p`, evenly spaced and ending at `p`. Empty while the
    /// gap is still shorter than `spacing`; a long jump is filled with at most `maxSteps` points.
    static func beads(from last: SIMD2<Float>, to p: SIMD2<Float>, spacing: Float, maxSteps: Int = 12) -> [SIMD2<Float>] {
        let gap = simd_distance(p, last)
        guard gap >= spacing else { return [] }
        let steps = min(Int(gap / spacing), maxSteps)
        return (1...steps).map { s in last + (p - last) * (Float(s) / Float(steps)) }
    }

    /// The runs of a stroke that survive an eraser of `radius` at `p`, in order. Nil when the eraser misses the
    /// stroke; empty when it wipes the whole stroke.
    static func cut(_ points: [StrokePoint], at p: SIMD2<Float>, radius: Float) -> [[StrokePoint]]? {
        guard points.contains(where: { simd_distance($0.p, p) < radius }) else { return nil }
        var runs: [[StrokePoint]] = [[]]
        for point in points {
            if simd_distance(point.p, p) < radius {
                if !(runs.last?.isEmpty ?? true) { runs.append([]) }
            } else {
                runs[runs.count - 1].append(point)
            }
        }
        return runs.filter { !$0.isEmpty }
    }
}

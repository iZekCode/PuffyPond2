import Foundation
import simd

/// The finished painting as one elastic sheet, for the review page's push and grab play.
///
/// Ported from InterARTive's `DeformationSolver`, changed from one body per stroke to a single grid.
/// Every node is `rest + displacement`. Rest positions are never written. Gestures only add inputs for
/// one frame (pins toward targets, forces); a damped spring always pulls displacement back to zero, so
/// removing an input *is* the release and the painting returns to exactly what was drawn.
///
/// Sheet space: centered on the painting, y up, in the units of `size`.
final class SheetSolver {
    struct Parameters {
        /// Rest spring stiffness (1/s²). (2π · 1 Hz)², so the sheet swings home about once a second.
        var stiffness: Float = 39.5
        /// Below 1 the return overshoots once, softly, like a wet canvas settling.
        var dampingRatio: Float = 0.6
        /// Displacement at which the spring pull starts to saturate, so big stretches flow back
        /// at a steady pace instead of snapping.
        var saturation: Float = 2
        /// Per-substep Laplacian smoothing of displacement over grid neighbours (0...0.25).
        var smoothing: Float = 0.15
        /// Displacement speed cap, so a big stretch pours back instead of whipping.
        var maxSpeed: Float = 10
        var substep: TimeInterval = 1.0 / 240.0
        var maxSubsteps = 8
        /// The sheet sleeps (skips simulation) once every node is this close to rest and this slow.
        var sleepDisplacement: Float = 0.0004
        var sleepSpeed: Float = 0.004
    }

    /// Grid resolution, matching the painting's 6.4 : 4 shape.
    static let columns = 48
    static let rows = 30
    static let size = SIMD2<Float>(6.4, 4)

    var parameters: Parameters
    let rest: [SIMD2<Float>]
    private(set) var displacement: [SIMD2<Float>]
    private(set) var velocity: [SIMD2<Float>]
    private var pinTarget: [SIMD2<Float>]
    private var pinWeight: [Float]
    private var force: [SIMD2<Float>]
    private var hasInput = false
    /// 0 = normal return; 1 = just released from a heavy (fist) grab: softer spring, a bit more
    /// overshoot. Cleared when the sheet settles.
    private(set) var heaviness: Float = 0
    private(set) var isSleeping = true
    private(set) var maxDisplacement: Float = 0
    private var accumulator: TimeInterval = 0

    init(parameters: Parameters = Parameters()) {
        self.parameters = parameters
        var rest: [SIMD2<Float>] = []
        rest.reserveCapacity(Self.columns * Self.rows)
        for row in 0..<Self.rows {
            for column in 0..<Self.columns {
                let u = Float(column) / Float(Self.columns - 1)
                let v = Float(row) / Float(Self.rows - 1)
                rest.append(SIMD2((u - 0.5) * Self.size.x, (0.5 - v) * Self.size.y))
            }
        }
        self.rest = rest
        let zeros = [SIMD2<Float>](repeating: .zero, count: rest.count)
        displacement = zeros
        velocity = zeros
        pinTarget = zeros
        pinWeight = [Float](repeating: 0, count: rest.count)
        force = zeros
    }

    var count: Int { rest.count }

    /// Row 0 is the top edge, column 0 the left edge.
    func index(column: Int, row: Int) -> Int { row * Self.columns + column }

    func position(_ i: Int) -> SIMD2<Float> { rest[i] + displacement[i] }

    /// The node whose current position is closest to `point`.
    func nearestNode(to point: SIMD2<Float>) -> Int {
        var best = 0
        var bestDistance = Float.infinity
        for i in 0..<count {
            let d = simd_distance_squared(position(i), point)
            if d < bestDistance {
                bestDistance = d
                best = i
            }
        }
        return best
    }

    // MARK: - Inputs (valid for the next `step` only)

    func clearInputs() {
        guard hasInput else { return }
        for i in 0..<count {
            pinWeight[i] = 0
            force[i] = .zero
        }
        hasInput = false
    }

    /// Pulls node `i` toward an absolute sheet-space `target`; `weight` (0...1) is the fraction of the
    /// remaining gap closed every substep. The strongest pin on a node wins.
    func pin(_ i: Int, to target: SIMD2<Float>, weight: Float) {
        guard i >= 0, i < count, weight > 0 else { return }
        if weight >= pinWeight[i] {
            pinTarget[i] = target - rest[i]
            pinWeight[i] = min(weight, 1)
        }
        hasInput = true
        isSleeping = false
    }

    /// Adds an acceleration (sheet units / s²) to node `i`.
    func push(_ i: Int, acceleration: SIMD2<Float>) {
        guard i >= 0, i < count else { return }
        force[i] += acceleration
        hasInput = true
        isSleeping = false
    }

    /// Marks the sheet as just released. `heaviness` 1 (fist) gives a slower, rounder return.
    func release(heaviness: Float) {
        self.heaviness = max(self.heaviness, min(max(heaviness, 0), 1))
    }

    // MARK: - Simulation

    func step(_ dt: TimeInterval) {
        accumulator = min(accumulator + max(dt, 0), parameters.substep * Double(parameters.maxSubsteps))
        guard !isSleeping else {
            accumulator = 0
            return
        }
        while accumulator >= parameters.substep {
            accumulator -= parameters.substep
            substep(h: Float(parameters.substep))
        }
        settleIfAtRest()
    }

    private func substep(h: Float) {
        let k = parameters.stiffness * (1 - 0.4 * heaviness)
        let c = 2 * parameters.dampingRatio * (1 - 0.15 * heaviness) * sqrt(k)
        let saturation = parameters.saturation
        let previous = displacement

        // Spring toward rest (saturating for big pulls) + external forces (semi-implicit Euler).
        for i in 0..<count {
            let d = displacement[i]
            let pull = -k * d / (1 + simd_length(d) / saturation)
            let a = pull - c * velocity[i] + force[i]
            velocity[i] += a * h
            displacement[i] += velocity[i] * h
        }

        // Coherence: grid neighbours share displacement, so the sheet bends instead of tearing.
        let s = parameters.smoothing
        if s > 0 {
            let snapshot = displacement
            let columns = Self.columns
            let rows = Self.rows
            for row in 0..<rows {
                for column in 0..<columns {
                    let i = row * columns + column
                    var sum = SIMD2<Float>.zero
                    var n: Float = 0
                    if column > 0 { sum += snapshot[i - 1]; n += 1 }
                    if column < columns - 1 { sum += snapshot[i + 1]; n += 1 }
                    if row > 0 { sum += snapshot[i - columns]; n += 1 }
                    if row < rows - 1 { sum += snapshot[i + columns]; n += 1 }
                    displacement[i] += s * (sum / n - snapshot[i])
                }
            }
        }

        // Grabs.
        if hasInput {
            for i in 0..<count where pinWeight[i] > 0 {
                displacement[i] = simd_mix(displacement[i], pinTarget[i], SIMD2(repeating: pinWeight[i]))
            }
        }

        // Velocity from the actual motion, so a flick carries through on release. Free nodes are
        // speed-capped in position too (held nodes must keep up with the hand).
        var maxDisplacement: Float = 0
        for i in 0..<count {
            var v = (displacement[i] - previous[i]) / h
            let speed = simd_length(v)
            if speed > parameters.maxSpeed {
                v *= parameters.maxSpeed / speed
                if pinWeight[i] == 0 { displacement[i] = previous[i] + v * h }
            }
            velocity[i] = v
            maxDisplacement = max(maxDisplacement, simd_length(displacement[i]))
        }
        self.maxDisplacement = maxDisplacement
    }

    private func settleIfAtRest() {
        guard !hasInput else { return }
        let still = zip(displacement, velocity).allSatisfy {
            simd_length($0) < parameters.sleepDisplacement && simd_length($1) < parameters.sleepSpeed
        }
        guard still else { return }
        for i in 0..<count {
            displacement[i] = .zero
            velocity[i] = .zero
        }
        maxDisplacement = 0
        heaviness = 0
        isSleeping = true
    }
}

import Foundation
import simd

/// Collects one canvas session's movement stats: painting time and canvas heatmap per hand, grip
/// cycles, and the range-of-motion metrics from body pose. Pure: fed every frame, read once at the end.
///
/// Left and right are always the person's own sides. On a mirrored preview a hand on the right of the
/// screen is the person's right hand; on a plain camera image it is their left.
struct SessionRecorder {
    /// One camera hand this frame (touch and mouse never get here).
    struct Hand {
        /// 0 = the hand on the left of the screen, 1 = the right.
        var slot: Int
        var pose: HandPose
        /// The hand is painting (or scrubbing) on the canvas right now.
        var painting: Bool
        /// Where its character is on the canvas (0…1, y down), nil when off the canvas.
        var canvas: SIMD2<Float>?
    }

    /// A joint is used only when Vision is at least this sure of it.
    static let minimumConfidence: Float = 0.5
    /// Each record is the median of this window, so a single bad frame can't make a fake record.
    static let filterWindow: Double = 0.3

    private let mirrored: Bool
    private var duration: Double = 0
    private var sawCameraHands = false
    private var sawBody = false
    private var painting: [Side: Double] = [:]
    private var heat = [Double](repeating: 0, count: SessionStats.heatmapColumns * SessionStats.heatmapRows)
    private var sideHeat: [Side: [Double]] = [:]
    private var lastPose: [Side: HandPose] = [:]
    private var gripCycles: [Side: Int] = [:]

    private var abduction = PeakTracker()
    private var elbow = PeakTracker()
    private var height = PeakTracker()
    private var lean = PeakTracker()
    private var wristX = PeakTracker()
    private var wristY = PeakTracker()
    private var reachPoints: [Side: [SIMD2<Double>]] = [:]

    init(mirrored: Bool = HandTracker.mirrored) {
        self.mirrored = mirrored
    }

    private func side(ofScreenSlot slot: Int) -> Side {
        (slot == 0) == mirrored ? .left : .right
    }

    // MARK: Hands

    mutating func record(hands: [Hand], dt: Double) {
        duration += dt
        if !hands.isEmpty { sawCameraHands = true }
        for hand in hands {
            let side = side(ofScreenSlot: hand.slot)
            let closed = hand.pose == .fist
            if let before = lastPose[side], before == .fist, !closed {
                gripCycles[side, default: 0] += 1
            }
            lastPose[side] = closed ? .fist : .open

            guard hand.painting, let p = hand.canvas else { continue }
            painting[side, default: 0] += dt
            let columns = SessionStats.heatmapColumns, rows = SessionStats.heatmapRows
            let column = min(max(Int(p.x * Float(columns)), 0), columns - 1)
            let row = min(max(Int(p.y * Float(rows)), 0), rows - 1)
            heat[row * columns + column] += dt
            sideHeat[side, default: [Double](repeating: 0, count: columns * rows)][row * columns + column] += dt
        }
    }

    // MARK: Body

    mutating func record(body: BodyFrame, at time: Double) {
        let aspect = body.imageAspect
        func point(_ joint: BodyJoint) -> SIMD2<Double>? {
            guard let p = body[joint], p.confidence >= Self.minimumConfidence else { return nil }
            return SIMD2(Double(p.location.x * aspect), Double(p.location.y))   // square units, y down
        }
        guard let shoulderA = point(.leftShoulder), let shoulderB = point(.rightShoulder) else { return }
        let width = simd_distance(shoulderA, shoulderB)
        guard width > 1e-3 else { return }
        sawBody = true

        let line = shoulderB - shoulderA
        lean.add(Self.degrees(atan2(abs(line.y), abs(line.x))), at: time, key: .left)

        // Vision's labels flip on a mirrored image: name each arm by where its shoulder sits.
        let chains: [(shoulder: SIMD2<Double>, other: SIMD2<Double>, elbow: BodyJoint, wrist: BodyJoint, hip: BodyJoint)] = [
            (shoulderA, shoulderB, .leftElbow, .leftWrist, .leftHip),
            (shoulderB, shoulderA, .rightElbow, .rightWrist, .rightHip),
        ]
        for chain in chains {
            let onImageRight = chain.shoulder.x > chain.other.x
            let side: Side = onImageRight == mirrored ? .right : .left
            let shoulder = chain.shoulder
            guard let elbowPoint = point(chain.elbow) else { continue }

            // Shoulder abduction: upper arm against the trunk (down to the hip, or straight down from the
            // shoulder line when the hips are out of view).
            let trunk: SIMD2<Double>
            if let hip = point(chain.hip) {
                trunk = hip - shoulder
            } else {
                let across = chain.other - shoulder
                let perpendicular = SIMD2(-across.y, across.x)
                trunk = perpendicular.y >= 0 ? perpendicular : -perpendicular
            }
            abduction.add(Self.angle(elbowPoint - shoulder, trunk), at: time, key: side)

            guard let wrist = point(chain.wrist) else { continue }
            elbow.add(Self.angle(shoulder - elbowPoint, wrist - elbowPoint), at: time, key: side)
            height.add((shoulder.y - wrist.y) / width, at: time, key: side)
            // The wrist relative to its shoulder, in shoulder widths, so walking around doesn't count as reach.
            let reach = (wrist - shoulder) / width
            if let x = wristX.add(reach.x, at: time, key: side), let y = wristY.add(reach.y, at: time, key: side) {
                let p = SIMD2(x, y)
                if let last = reachPoints[side]?.last, simd_distance(last, p) < 0.05 { continue }
                reachPoints[side, default: []].append(p)
            }
        }
    }

    // MARK: Result

    /// Nil when no camera hand or body was ever seen (touch or mouse drawing records nothing).
    func finish() -> SessionStats? {
        guard sawCameraHands || sawBody else { return nil }
        var stats = SessionStats()
        stats.duration = duration
        stats.pinchSeconds = painting
        stats.heatmap = heat.map { UInt16(min(($0 * 100).rounded(), Double(UInt16.max))) }
        stats.sideHeatmaps = sideHeat.mapValues { cells in cells.map { UInt16(min(($0 * 100).rounded(), Double(UInt16.max))) } }
        stats.gripCycles = gripCycles
        stats.romDegrees = abduction.peaks
        stats.elbowExtension = elbow.peaks
        stats.reachHeight = height.peaks
        stats.reachArea = reachPoints.compactMapValues { $0.count >= 3 ? Self.hullArea($0) : nil }
        stats.maxTrunkLean = lean.peaks[.left] ?? 0
        return stats
    }

    // MARK: Geometry

    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    private static func angle(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let la = simd_length(a), lb = simd_length(b)
        guard la > 1e-9, lb > 1e-9 else { return 0 }
        return degrees(acos(min(max(simd_dot(a, b) / (la * lb), -1), 1)))
    }

    /// Area of the convex hull (monotone chain + shoelace).
    static func hullArea(_ points: [SIMD2<Double>]) -> Double {
        let sorted = points.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        func cross(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [SIMD2<Double>] = [], upper: [SIMD2<Double>] = []
        for p in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        for p in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        let hull = lower.dropLast() + upper.dropLast()
        guard hull.count >= 3 else { return 0 }
        var area = 0.0
        for i in hull.indices {
            let a = hull[i], b = hull[(i + 1) % hull.count]
            area += a.x * b.y - b.x * a.y
        }
        return abs(area) / 2
    }
}

/// Per-side session maximum of a value, taken over a short running median.
private struct PeakTracker {
    private var windows: [Side: [(time: Double, value: Double)]] = [:]
    private(set) var peaks: [Side: Double] = [:]

    /// Adds a sample; returns the current median once the window holds at least three samples.
    @discardableResult
    mutating func add(_ value: Double, at time: Double, key side: Side) -> Double? {
        var window = windows[side, default: []]
        window.append((time, value))
        window.removeAll { time - $0.time > SessionRecorder.filterWindow }
        windows[side] = window
        guard window.count >= 3 else { return nil }
        let sorted = window.map(\.value).sorted()
        let median = sorted[sorted.count / 2]
        peaks[side] = max(peaks[side] ?? -.infinity, median)
        return median
    }
}

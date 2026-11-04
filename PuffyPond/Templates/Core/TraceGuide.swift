import Foundation

/// Turns a dotted outline into step-by-step directions ("Naik ke atas!", "Turun sedikit lagi!") and follows the
/// brush along it, so the arrow and the voice always talk about the part the child is on.
/// Pure: feed it the outline's polylines (world units, y up) and, each frame it paints, where the brush is.
nonisolated struct TraceGuide {
    /// Eight ways a line can run, counter-clockwise from "right" (y up).
    enum Direction: Int, CaseIterable {
        case east, northEast, north, northWest, west, southWest, south, southEast

        init(angle: Float) {
            let step = Int((angle / (.pi / 4)).rounded())
            self = Self.allCases[((step % 8) + 8) % 8]
        }

        /// "naik" / "turun" for anything that climbs or falls; nil for flat.
        var verb: String? {
            switch self {
            case .north, .northEast, .northWest: return "naik"
            case .south, .southEast, .southWest: return "turun"
            case .east, .west: return nil
            }
        }

        var tail: String {
            switch self {
            case .east, .northEast, .southEast: return "ke kanan"
            case .west, .northWest, .southWest: return "ke kiri"
            case .north: return "ke atas"
            case .south: return "ke bawah"
            }
        }

        /// Climbing, falling, right or left: the next step says "lagi" when it stays in the same group.
        fileprivate enum Group { case up, down, right, left }
        fileprivate var group: Group {
            switch self {
            case .north, .northEast, .northWest: return .up
            case .south, .southEast, .southWest: return .down
            case .east: return .right
            case .west: return .left
            }
        }
    }

    /// One stretch of the outline that runs the same way, with what to say about it.
    struct Leg: Equatable {
        /// Which polyline of the outline it belongs to.
        let path: Int
        /// Sample indices into the resampled outline.
        let start: Int
        let end: Int
        let direction: Direction
        let text: String
    }

    enum Progress: Equatable {
        case none, moved, legChanged, finished
    }

    // MARK: Tuning (world units; the canvas is 6.4 × 4)

    /// Distance between samples along the outline.
    static let spacing: Float = 0.12
    /// How close the brush must be to a sample to cover it.
    static let hitRadius: Float = 0.45
    /// How far ahead of the last covered sample the brush may reach, so cutting across the shape doesn't count.
    static let lookahead = 8
    /// A new direction must hold this many samples before it becomes a new step (no chatter on wobbles).
    static let minRun = 5
    /// Steps shorter than this many samples are folded into their neighbour.
    static let minLeg = 4
    /// A step shorter than this (world units) is spoken as "sedikit".
    static let shortLength: Float = 1.2
    /// The next step is announced this many samples before the brush gets there.
    static let leadIn = 4
    /// The arrow sits this many samples ahead of the brush.
    static let arrowLead = 4

    static let finishText = "Hebat sekali! Garisnya sudah selesai!"

    // MARK: State

    private(set) var samples: [SIMD2<Float>] = []
    private(set) var legs: [Leg] = []
    /// First sample the brush has not covered yet; `samples.count` once the whole outline is done.
    private(set) var cursor = 0
    private var ranges: [Range<Int>] = []

    init?(lines: [[SIMD2<Float>]]) {
        for line in lines {
            let points = Self.resample(line)
            guard points.count >= 2 else { continue }
            ranges.append(samples.count..<(samples.count + points.count))
            samples += points
        }
        guard !samples.isEmpty else { return nil }
        legs = buildLegs()
    }

    var isFinished: Bool { cursor >= samples.count }

    /// Index of the step to talk about now.
    var currentLeg: Int {
        let at = min(cursor, samples.count - 1)
        return legs.lastIndex { $0.start - Self.leadIn <= at } ?? 0
    }

    var text: String { isFinished ? Self.finishText : legs[currentLeg].text }

    /// Where the arrow sits: a little ahead of the brush.
    var target: SIMD2<Float> { samples[min(cursor + Self.arrowLead, samples.count - 1)] }

    /// Which way the arrow points, in radians (0 = right, counter-clockwise).
    var heading: Float { Self.angle(at: min(cursor + Self.arrowLead, samples.count - 1), samples: samples, ranges: ranges) }

    /// Moves the guide on if the brush is near the next stretch of the outline.
    mutating func advance(to point: SIMD2<Float>) -> Progress {
        guard !isFinished else { return .none }
        let before = currentLeg
        let upper = min(cursor + Self.lookahead, samples.count - 1)
        var hit: Int?
        for i in cursor...upper where Self.distance(samples[i], point) <= Self.hitRadius { hit = i }
        guard let hit else { return .none }
        cursor = hit + 1
        if isFinished { return .finished }
        return currentLeg != before ? .legChanged : .moved
    }

    // MARK: Building the steps

    private func buildLegs() -> [Leg] {
        // Raw runs per polyline: (start sample, direction).
        var all: [(path: Int, start: Int, end: Int, direction: Direction)] = []
        for (pathIndex, range) in ranges.enumerated() {
            var runs: [(start: Int, direction: Direction)] = []
            var current = direction(at: range.lowerBound)
            runs.append((range.lowerBound, current))
            var candidate: Direction?
            var candidateStart = range.lowerBound
            var held = 0
            for i in (range.lowerBound + 1)..<range.upperBound {
                let d = direction(at: i)
                if d == current { candidate = nil; held = 0; continue }
                if d == candidate { held += 1 } else { candidate = d; candidateStart = i; held = 1 }
                if held >= Self.minRun {
                    runs.append((candidateStart, d))
                    current = d
                    candidate = nil
                    held = 0
                }
            }
            // Fold tiny steps into a neighbour, then join neighbours that run the same way.
            var changed = true
            while changed, runs.count > 1 {
                changed = false
                for k in runs.indices {
                    let end = k + 1 < runs.count ? runs[k + 1].start : range.upperBound - 1
                    if end - runs[k].start < Self.minLeg {
                        if k == 0 { runs.remove(at: 0); runs[0].start = range.lowerBound } else { runs.remove(at: k) }
                        changed = true
                        break
                    }
                }
            }
            var joined: [(start: Int, direction: Direction)] = []
            for run in runs where joined.last?.direction != run.direction { joined.append(run) }
            for k in joined.indices {
                let end = k + 1 < joined.count ? joined[k + 1].start : range.upperBound - 1
                all.append((pathIndex, joined[k].start, end, joined[k].direction))
            }
        }

        var legs: [Leg] = []
        for (k, item) in all.enumerated() {
            let sameShape = k > 0 && all[k - 1].path == item.path
            let previous = sameShape ? all[k - 1].direction : nil
            let length = Float(item.end - item.start) * Self.spacing
            let text = Self.sentence(direction: item.direction, isShort: length < Self.shortLength,
                                     previous: previous, isFirst: k == 0, startsShape: !sameShape,
                                     isLast: k == all.count - 1)
            legs.append(Leg(path: item.path, start: item.start, end: item.end, direction: item.direction, text: text))
        }
        return legs
    }

    /// "Ayo mulai dari sini! Naik ke atas!", "Sekarang turun ke bawah!", "Turun sedikit lagi!" …
    static func sentence(direction: Direction, isShort: Bool, previous: Direction?, isFirst: Bool,
                         startsShape: Bool, isLast: Bool) -> String {
        let again = previous?.group == direction.group

        var parts: [String] = []
        if let verb = direction.verb {
            parts.append(verb)
            if isShort { parts.append("sedikit") }
            if !(again && isShort) { parts.append(direction.tail) }
        } else {
            if isShort { parts.append("sedikit") }
            parts.append(direction.tail)
        }
        if again { parts.append("lagi") }

        var connective = ""
        if let previous, !again {
            let reversed = (previous.group == .up && direction.group == .down)
                || (previous.group == .down && direction.group == .up)
                || (previous.group == .left && direction.group == .right)
                || (previous.group == .right && direction.group == .left)
            connective = reversed ? "sekarang " : "lalu "
        }

        var intro = ""
        if isFirst { intro = "Ayo mulai dari sini! " }
        else if startsShape { intro = "Bagian berikutnya! " }
        else if isLast { intro = "Sedikit lagi selesai! " }

        let phrase = connective + parts.joined(separator: " ")
        return intro + phrase.prefix(1).uppercased() + phrase.dropFirst() + "!"
    }

    // MARK: Geometry

    private func direction(at index: Int) -> Direction {
        Direction(angle: Self.angle(at: index, samples: samples, ranges: ranges))
    }

    /// Direction of travel around a sample, smoothed over a few neighbours on the same polyline.
    private static func angle(at index: Int, samples: [SIMD2<Float>], ranges: [Range<Int>]) -> Float {
        guard let range = ranges.first(where: { $0.contains(index) }) else { return 0 }
        let a = max(range.lowerBound, index - 3)
        let b = min(range.upperBound - 1, index + 3)
        let v = samples[b] - samples[a]
        return v.x == 0 && v.y == 0 ? 0 : atan2(v.y, v.x)
    }

    private static func distance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let d = a - b
        return (d * d).sum().squareRoot()
    }

    /// Even steps of `spacing` along a polyline, keeping its first point and (about) its last.
    private static func resample(_ line: [SIMD2<Float>]) -> [SIMD2<Float>] {
        guard let first = line.first else { return [] }
        var out = [first]
        var a = first
        var since: Float = 0
        for b in line.dropFirst() {
            var segment = distance(a, b)
            while since + segment >= spacing {
                a += (b - a) * ((spacing - since) / segment)
                out.append(a)
                segment = distance(a, b)
                since = 0
            }
            since += segment
            a = b
        }
        if let last = line.last, let tail = out.last, distance(tail, last) > spacing * 0.3 { out.append(last) }
        return out
    }
}

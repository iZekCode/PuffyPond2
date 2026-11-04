import simd

/// What has been painted so far, stroke by stroke, and each hand's stroke in progress. What you *see* is the
/// PaintLayer; this tracks the paths for erasing, for knowing whether anything is painted, and for when a stroke
/// starts or should blip.
struct StrokeBook {
    /// The path of one brush stroke: what the critter drew, in which color, with which brush animal.
    struct Stroke {
        let id: Int
        let color: SIMD3<Float>
        let brush: CritterKind
        var points: [StrokePoint]
    }

    /// What one frame of painting asks the easel to do.
    enum PaintEvent: Equatable {
        /// A new stroke began: the critter gulps and a blip sounds.
        case started
        /// The stroke has gone far enough since the last blip to blip again.
        case blip
    }

    private(set) var strokes: [Stroke] = []
    private var active: [Int: Int] = [:]                // slot → id of the stroke it is painting
    private var lastBead: [Int: SIMD2<Float>] = [:]
    private var lastStamp: [Int: SIMD2<Float>] = [:]
    private var blipDistance: [Int: Float] = [:]
    private var nextID = 0

    var isEmpty: Bool { strokes.isEmpty }
    var count: Int { strokes.count }
    /// The slots with a stroke in progress.
    var activeSlots: [Int] { Array(active.keys) }

    /// Where this frame's dabs start: the last stamp of the stroke in progress, or `p` for a fresh one.
    func stampStart(slot: Int, at p: SIMD2<Float>) -> SIMD2<Float> { lastStamp[slot] ?? p }

    mutating func stamped(slot: Int, at p: SIMD2<Float>) { lastStamp[slot] = p }

    /// Grows `slot`'s stroke to `p`, or starts one there. Beads are laid `spacing` apart.
    mutating func paint(slot: Int, at p: SIMD2<Float>, now: Double, color: SIMD3<Float>, brush: CritterKind,
                        spacing: Float) -> PaintEvent? {
        if let id = active[slot], let index = strokes.firstIndex(where: { $0.id == id }), let last = lastBead[slot] {
            let beads = StrokePath.beads(from: last, to: p, spacing: spacing)
            guard !beads.isEmpty else { return nil }
            strokes[index].points += beads.map { StrokePoint(p: $0, born: now) }
            lastBead[slot] = p
            blipDistance[slot, default: 0] += simd_distance(p, last)
            guard blipDistance[slot, default: 0] > 0.16 else { return nil }
            blipDistance[slot] = 0
            return .blip
        }
        let stroke = Stroke(id: takeID(), color: color, brush: brush, points: [StrokePoint(p: p, born: now)])
        strokes.append(stroke)
        active[slot] = stroke.id
        lastBead[slot] = p
        return .started
    }

    /// Ends `slot`'s stroke. True when one was in progress (the critter is proud of that line).
    @discardableResult
    mutating func finish(slot: Int) -> Bool {
        let wasPainting = active[slot] != nil
        active[slot] = nil
        lastBead[slot] = nil
        lastStamp[slot] = nil
        return wasPainting
    }

    /// Wipes the paths under an eraser of `radius` at `p`, splitting strokes into the runs that survive. A stroke
    /// wiped away entirely is dropped, and a hand painting it starts a new one next frame. True when anything was hit.
    mutating func erase(at p: SIMD2<Float>, radius: Float) -> Bool {
        var erasedAny = false
        var kept: [Stroke] = []
        for var stroke in strokes {
            guard let runs = StrokePath.cut(stroke.points, at: p, radius: radius) else {
                kept.append(stroke)
                continue
            }
            erasedAny = true
            if let first = runs.first {
                stroke.points = first
                kept.append(stroke)
                for run in runs.dropFirst() {
                    kept.append(Stroke(id: takeID(), color: stroke.color, brush: stroke.brush, points: run))
                }
            } else {
                for (slot, id) in active where id == stroke.id { active[slot] = nil }
            }
        }
        strokes = kept
        return erasedAny
    }

    /// Forgets every stroke and every stroke in progress.
    mutating func clear() {
        strokes.removeAll()
        active = [:]
        lastBead = [:]
        lastStamp = [:]
    }

    private mutating func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }
}

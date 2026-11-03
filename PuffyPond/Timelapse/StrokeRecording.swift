import Foundation
import simd

/// One `PaintLayer.stamp` call, with when it happened and which brush animal made it.
struct RecordedDab: Equatable {
    /// Seconds since the recording began.
    var t: Double
    var from: SIMD2<Float>
    var to: SIMD2<Float>
    var radius: Float
    var speed: Float
    var color: SIMD3<Float>
    var seed: Float
    var strokeSeed: Float
    var style: BrushStyle
    var drag: SIMD2<Float>?
    var ncaModel: Int
    var brush: CritterKind
}

/// One `PaintLayer.erase` call.
struct RecordedErase: Equatable {
    var t: Double
    var center: SIMD2<Float>
    var radius: Float
    var dt: Float
}

enum RecordedEvent: Equatable {
    case dab(RecordedDab)
    case erase(RecordedErase)

    var t: Double {
        switch self {
        case .dab(let dab): dab.t
        case .erase(let erase): erase.t
        }
    }
}

/// Everything painted in one session, in order, so it can be laid down again.
struct StrokeRecording: Equatable {
    static let formatVersion = 1
    /// More events than this are thinned: about a megabyte compressed.
    static let maxEvents = 24_000

    private(set) var events: [RecordedEvent]

    init(events: [RecordedEvent] = []) {
        self.events = events
    }

    var isEmpty: Bool { events.isEmpty }

    /// Appends; when the count passes twice `maxEvents`, thins in place down to `maxEvents`.
    mutating func append(_ event: RecordedEvent) {
        events.append(event)
        if events.count > 2 * Self.maxEvents {
            self = thinned(toAtMost: Self.maxEvents)
        }
    }

    /// Brings the recording down to `limit` events. Erases are capped at a quarter of the limit (evenly dropped),
    /// then dabs go: first those that sit in the middle of a connected run of dabs of one stroke, which are merged
    /// into the next dab so the painted path stays connected; then, if that is not enough, dabs that stand alone
    /// (dropped outright, never joined to a neighbour that is not next to them); and last the first and last dab
    /// of a stroke. A stroke is every dab sharing a `strokeSeed`, which is only a hint: it does not say the dabs
    /// connect.
    func thinned(toAtMost limit: Int) -> StrokeRecording {
        guard events.count > limit else { return self }
        var dropped = Set<Int>()

        let erases = events.indices.filter { if case .erase = events[$0] { true } else { false } }
        if erases.count > limit / 4 {
            dropped.formUnion(Self.evenly(erases, count: erases.count - limit / 4))
        }
        var need = events.count - dropped.count - limit
        guard need > 0 else { return removing(dropped, merged: []) }

        var groups: [Float: [Int]] = [:]
        for (index, event) in events.enumerated() {
            if case .dab(let dab) = event { groups[dab.strokeSeed, default: []].append(index) }
        }
        var joinable: [Int] = []
        var alone: [Int] = []
        var ends: [Int] = []
        for indices in groups.values {
            for (k, index) in indices.enumerated() {
                guard case .dab(let dab) = events[index] else { continue }
                if k == 0 || k == indices.count - 1 {
                    ends.append(index)
                } else if case .dab(let before) = events[indices[k - 1]], case .dab(let after) = events[indices[k + 1]],
                          dab.from == before.to, after.from == dab.to {
                    joinable.append(index)
                } else {
                    alone.append(index)
                }
            }
        }
        var merged = Set<Int>()
        for (pool, isMerge) in [(joinable.sorted(), true), (alone.sorted(), false), (ends.sorted(), false)] where need > 0 {
            let chosen = Self.evenly(pool, count: min(need, pool.count))
            dropped.formUnion(chosen)
            if isMerge { merged.formUnion(chosen) }
            need -= chosen.count
        }
        return removing(dropped, merged: merged)
    }

    /// `count` of `indices`, spread evenly.
    private static func evenly(_ indices: [Int], count: Int) -> [Int] {
        guard count < indices.count else { return indices }
        guard count > 0 else { return [] }
        return indices.enumerated().compactMap { offset, index in
            (offset + 1) * count / indices.count > offset * count / indices.count ? index : nil
        }
    }

    /// The events without `dropped`. A dropped dab in `merged` was joined end to end with its neighbours: its start
    /// is carried into the next dab if that one carries on from where it ended.
    private func removing(_ dropped: Set<Int>, merged: Set<Int>) -> StrokeRecording {
        var carried: [Float: SIMD2<Float>] = [:]
        var endedAt: [Float: SIMD2<Float>] = [:]
        var result: [RecordedEvent] = []
        result.reserveCapacity(events.count - dropped.count)
        for (index, event) in events.enumerated() {
            switch event {
            case .erase:
                if !dropped.contains(index) { result.append(event) }
            case .dab(var dab):
                let seed = dab.strokeSeed
                if dropped.contains(index) {
                    if merged.contains(index) {
                        if carried[seed] == nil || endedAt[seed] != dab.from { carried[seed] = dab.from }
                        endedAt[seed] = dab.to
                    } else {
                        carried.removeValue(forKey: seed)
                        endedAt.removeValue(forKey: seed)
                    }
                } else {
                    if let start = carried.removeValue(forKey: seed), endedAt[seed] == dab.from { dab.from = start }
                    endedAt.removeValue(forKey: seed)
                    result.append(.dab(dab))
                }
            }
        }
        return StrokeRecording(events: result)
    }

    // MARK: File format

    private enum Tag: UInt8 { case dab = 0, erase = 1 }
    private static let styleFields = 12

    /// A version byte, then the zlib-compressed events.
    func encoded() -> Data {
        let source = events.count > Self.maxEvents ? thinned(toAtMost: Self.maxEvents).events : events
        var out = ByteWriter()
        out.u32(UInt32(source.count))
        for event in source {
            switch event {
            case .dab(let d):
                out.u8(Tag.dab.rawValue)
                out.f64(d.t)
                out.vec(d.from)
                out.vec(d.to)
                out.f32(d.radius)
                out.f32(d.speed)
                out.f32(d.color.x); out.f32(d.color.y); out.f32(d.color.z)
                out.f32(d.seed)
                out.f32(d.strokeSeed)
                for value in Self.styleValues(d.style) { out.f32(value) }
                if let drag = d.drag {
                    out.u8(1)
                    out.vec(drag)
                } else {
                    out.u8(0)
                }
                out.u8(UInt8(truncatingIfNeeded: d.ncaModel))
                out.u8(UInt8(truncatingIfNeeded: d.brush.rawValue))
            case .erase(let e):
                out.u8(Tag.erase.rawValue)
                out.f64(e.t)
                out.vec(e.center)
                out.f32(e.radius)
                out.f32(e.dt)
            }
        }
        let packed = (try? (Data(out.bytes) as NSData).compressed(using: .zlib)) as Data?
        return Data([UInt8(Self.formatVersion)]) + (packed ?? Data())
    }

    /// Nil for a wrong version, truncated data or anything that doesn't decode cleanly.
    init?(data: Data) {
        guard let version = data.first, Int(version) == Self.formatVersion,
              let unpacked = try? (Data(data.dropFirst()) as NSData).decompressed(using: .zlib) else { return nil }
        var input = ByteReader(bytes: [UInt8](unpacked as Data))
        let count = Int(input.u32())
        // A record is at least 18 bytes; refuse counts the data cannot hold.
        guard !input.failed, count <= 2 * Self.maxEvents, count * 18 <= input.remaining else { return nil }
        var decoded: [RecordedEvent] = []
        decoded.reserveCapacity(count)
        for _ in 0..<count {
            guard let tag = Tag(rawValue: input.u8()) else { return nil }
            switch tag {
            case .dab:
                let t = input.f64()
                let from = input.vec()
                let to = input.vec()
                let radius = input.f32()
                let speed = input.f32()
                let color = SIMD3(input.f32(), input.f32(), input.f32())
                let seed = input.f32()
                let strokeSeed = input.f32()
                let style = Self.style((0..<Self.styleFields).map { _ in input.f32() })
                let drag: SIMD2<Float>? = input.u8() == 1 ? input.vec() : nil
                let ncaModel = Int(input.u8())
                guard let brush = CritterKind(rawValue: Int(input.u8())) else { return nil }
                decoded.append(.dab(RecordedDab(t: t, from: from, to: to, radius: radius, speed: speed, color: color,
                                                seed: seed, strokeSeed: strokeSeed, style: style, drag: drag,
                                                ncaModel: ncaModel, brush: brush)))
            case .erase:
                decoded.append(.erase(RecordedErase(t: input.f64(), center: input.vec(), radius: input.f32(),
                                                    dt: input.f32())))
            }
            if input.failed { return nil }
        }
        guard !input.failed, input.remaining == 0 else { return nil }
        events = decoded
    }

    /// `amount == nil` travels as NaN.
    private static func styleValues(_ s: BrushStyle) -> [Float] {
        [s.amount ?? .nan, s.push, s.bristles, s.nibAngle, s.nibAspect, s.watery, s.knife, s.impasto, s.runs,
         s.blend, s.nca, s.ncaSeed]
    }

    private static func style(_ v: [Float]) -> BrushStyle {
        BrushStyle(amount: v[0].isNaN ? nil : v[0], push: v[1], bristles: v[2], nibAngle: v[3], nibAspect: v[4],
                   watery: v[5], knife: v[6], impasto: v[7], runs: v[8], blend: v[9], nca: v[10], ncaSeed: v[11])
    }
}

private struct ByteWriter {
    var bytes: [UInt8] = []

    mutating func u8(_ v: UInt8) { bytes.append(v) }

    mutating func u32(_ v: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) { bytes.append(UInt8(truncatingIfNeeded: v >> UInt32(shift))) }
    }

    mutating func f32(_ v: Float) { u32(v.bitPattern) }

    mutating func f64(_ v: Double) {
        let bits = v.bitPattern
        for shift in stride(from: 0, to: 64, by: 8) { bytes.append(UInt8(truncatingIfNeeded: bits >> UInt64(shift))) }
    }

    mutating func vec(_ v: SIMD2<Float>) {
        f32(v.x)
        f32(v.y)
    }
}

/// Reads what `ByteWriter` wrote; any read past the end sets `failed` and returns zero.
private struct ByteReader {
    let bytes: [UInt8]
    var offset = 0
    var failed = false

    init(bytes: [UInt8]) { self.bytes = bytes }

    var remaining: Int { bytes.count - offset }

    private mutating func take(_ n: Int) -> ArraySlice<UInt8>? {
        guard n <= remaining else {
            failed = true
            return nil
        }
        defer { offset += n }
        return bytes[offset..<offset + n]
    }

    mutating func u8() -> UInt8 { take(1)?.first ?? 0 }

    mutating func u32() -> UInt32 {
        guard let slice = take(4) else { return 0 }
        return slice.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << UInt32($1.offset * 8) }
    }

    mutating func f32() -> Float { Float(bitPattern: u32()) }

    mutating func f64() -> Double {
        guard let slice = take(8) else { return 0 }
        return Double(bitPattern: slice.enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << UInt64($1.offset * 8) })
    }

    mutating func vec() -> SIMD2<Float> { SIMD2(f32(), f32()) }
}

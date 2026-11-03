import Foundation
import Testing
import simd
@testable import PuffyPond

struct StrokeRecordingTests {
    private func dab(t: Double = 0, from: SIMD2<Float> = .zero, to: SIMD2<Float> = .zero, strokeSeed: Float = 1,
                     style: BrushStyle = .brush, drag: SIMD2<Float>? = nil) -> RecordedDab {
        RecordedDab(t: t, from: from, to: to, radius: 0.12, speed: 1.5, color: SIMD3(0.9, 0.2, 0.3), seed: 4,
                    strokeSeed: strokeSeed, style: style, drag: drag, ncaModel: 2, brush: .butterfly)
    }

    /// `count` dabs of one stroke, each starting where the last one ended.
    private func chain(_ count: Int, strokeSeed: Float = 1) -> [RecordedEvent] {
        (0..<count).map { i in
            .dab(dab(t: Double(i) / 64, from: SIMD2(Float(i) * 0.01, 0), to: SIMD2(Float(i + 1) * 0.01, 0),
                     strokeSeed: strokeSeed))
        }
    }

    private func dabs(_ events: [RecordedEvent]) -> [RecordedDab] {
        events.compactMap { if case let .dab(d) = $0 { d } else { nil } }
    }

    @Test func roundTripKeepsEveryField() {
        var wet = BrushStyle.octopus
        wet.amount = 0.2
        wet.knife = 0.5
        let recording = StrokeRecording(events: [
            .dab(dab(t: 0, from: SIMD2(-1, 0.5), to: SIMD2(1.5, 0.25))),
            .dab(dab(t: 0.5, style: wet, drag: SIMD2(0.03, -0.02))),
            .erase(RecordedErase(t: 1.25, center: SIMD2(0.4, -0.3), radius: 0.3, dt: 1.0 / 60)),
        ])
        #expect(StrokeRecording(data: recording.encoded()) == recording)
    }

    @Test func badDataIsRejected() {
        let encoded = StrokeRecording(events: chain(20)).encoded()
        var wrongVersion = encoded
        wrongVersion[0] = 99
        #expect(StrokeRecording(data: Data()) == nil)
        #expect(StrokeRecording(data: encoded.dropLast(10)) == nil)
        #expect(StrokeRecording(data: wrongVersion) == nil)
        #expect(StrokeRecording(data: Data(repeating: 0xAB, count: 200)) == nil)
    }

    @Test func thinningKeepsEndsAndStaysConnected() {
        let original = chain(100)
        let thinned = StrokeRecording(events: original).thinned(toAtMost: 40)
        let kept = dabs(thinned.events)
        #expect(kept.count <= 40)
        #expect(kept.first?.from == dabs(original).first?.from)
        #expect(kept.last?.to == dabs(original).last?.to)
        for (a, b) in zip(kept, kept.dropFirst()) {
            #expect(a.to == b.from)
        }
    }

    @Test func thinningKeepsAllErases() {
        var events = chain(100)
        for i in 0..<10 {
            events.insert(.erase(RecordedErase(t: Double(i), center: .zero, radius: 0.3, dt: 0.016)), at: i * 11)
        }
        let thinned = StrokeRecording(events: events).thinned(toAtMost: 40)
        let erases = thinned.events.filter { if case .erase = $0 { true } else { false } }
        #expect(erases.count == 10)
        #expect(thinned.events.count <= 40)
    }

    @Test func appendThinsPastTheCap() {
        var recording = StrokeRecording()
        for event in chain(2 * StrokeRecording.maxEvents + 1) { recording.append(event) }
        #expect(recording.events.count <= StrokeRecording.maxEvents)
    }

    @Test func encodedSizeStaysNearBudget() {
        var events: [RecordedEvent] = []
        var last = SIMD2<Float>(0, 0)
        for i in 0..<StrokeRecording.maxEvents {
            let x = Float(i) * 0.0004
            let next = SIMD2(x, 0.8 * sin(x * 3))
            events.append(.dab(RecordedDab(t: Double(i) / 60, from: last, to: next, radius: 0.12,
                                           speed: 1.5 + cos(x), color: SIMD3(0.9, 0.2, 0.3),
                                           seed: 4 + Float(i % 7) * 5.1, strokeSeed: 4, style: .brush,
                                           drag: nil, ncaModel: 0, brush: .butterfly)))
            last = next
        }
        let size = StrokeRecording(events: events).encoded().count
        #expect(size < 1_000_000, "encoded \(size) bytes")
    }
}

import Testing
@testable import PuffyPond

@MainActor
struct TraceGuideTests {
    /// Up, then down the other side: a mountain, 3 units per side.
    private let mountain: [[SIMD2<Float>]] = [[SIMD2(0, 0), SIMD2(3, 3), SIMD2(6, 0)]]

    private func guide(_ lines: [[SIMD2<Float>]]) -> TraceGuide { TraceGuide(lines: lines)! }

    @Test func nothingToFollowMakesNoGuide() {
        #expect(TraceGuide(lines: []) == nil)
        #expect(TraceGuide(lines: [[SIMD2(1, 1)]]) == nil)
    }

    @Test func directionsFollowTheAngle() {
        #expect(TraceGuide.Direction(angle: 0) == .east)
        #expect(TraceGuide.Direction(angle: .pi / 2) == .north)
        #expect(TraceGuide.Direction(angle: .pi) == .west)
        #expect(TraceGuide.Direction(angle: -.pi / 2) == .south)
        #expect(TraceGuide.Direction(angle: -.pi / 4) == .southEast)
    }

    @Test func aMountainIsUpThenDown() {
        let g = guide(mountain)
        #expect(g.legs.count == 2)
        #expect(g.legs[0].direction == .northEast)
        #expect(g.legs[1].direction == .southEast)
        #expect(g.legs[0].text.hasPrefix("Yuk mulai dari sini!"))
        #expect(g.legs[0].text.contains("naik"))
        #expect(g.legs[1].text.contains("turun"))
    }

    @Test func sentencesSoundLikeAGuide() {
        func say(_ d: TraceGuide.Direction, short: Bool = false, after: TraceGuide.Direction? = nil,
                 first: Bool = false, last: Bool = false) -> String {
            TraceGuide.sentence(direction: d, isShort: short, previous: after, isFirst: first,
                                startsShape: first, isLast: last)
        }
        #expect(say(.north, first: true) == "Yuk mulai dari sini! Naik ke atas ya!")
        #expect(say(.south, after: .north) == "Sekarang turun ke bawah ya!")
        #expect(say(.southEast, after: .south) == "Turun ke kanan lagi!")
        #expect(say(.south, short: true, after: .southEast) == "Turun sedikit lagi!")
        #expect(say(.east, short: true, after: .north) == "Yuk, geser sedikit ke kanan!")
    }

    @Test func theSameStepIsSaidInDifferentWays() {
        let ways = Set((0..<6).map {
            TraceGuide.sentence(direction: .south, isShort: false, previous: .north, isFirst: false,
                                startsShape: false, isLast: false, variant: $0)
        })
        #expect(ways.count > 3)
        #expect(ways.allSatisfy { $0.contains("turun ke bawah") })
    }

    @Test func speechIsCutIntoSentences() {
        #expect(GuideVoice.sentences(in: "Bagus! Nah, turun ke bawah ya!") == ["Bagus!", "Nah, turun ke bawah ya!"])
        #expect(GuideVoice.sentences(in: "Tanpa tanda") == ["Tanpa tanda"])
    }

    @Test func clipNamesAreReadableFileNames() {
        #expect(GuideVoice.clipName(for: "Ayo, geser ke kanan!") == "guide-ayo-geser-ke-kanan")
        #expect(GuideVoice.clipName(for: "Hore, hebat sekali!") == "guide-hore-hebat-sekali")
    }

    /// `tools/voice/units.txt` is what the clip maker records: it must hold every sentence the guide can say.
    @Test func theVoiceScriptCoversEverySentence() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard let text = try? String(contentsOf: root.appendingPathComponent("tools/voice/units.txt"),
                                     encoding: .utf8) else { return }   // not readable where the tests run
        let script = Set(text.split(separator: "\n").map(String.init))
        var needed = Set(GuideVoice.sentences(in: TraceGuide.finishText))
        let flags = [(false, false, false), (true, true, false), (false, true, false), (false, false, true),
                     (false, true, true), (true, true, true)]
        let previousOptions: [TraceGuide.Direction?] = [nil] + TraceGuide.Direction.allCases.map { Optional($0) }
        for direction in TraceGuide.Direction.allCases {
            for short in [false, true] {
                for previous in previousOptions {
                    for (first, starts, last) in flags where previous == nil || !(first || starts) {
                        for variant in 0..<18 {
                            let line = TraceGuide.sentence(direction: direction, isShort: short, previous: previous,
                                                           isFirst: first, startsShape: starts, isLast: last,
                                                           variant: variant)
                            needed.formUnion(GuideVoice.sentences(in: line))
                        }
                    }
                }
            }
        }
        #expect(needed.subtracting(script).isEmpty, "Missing from tools/voice/units.txt: \(needed.subtracting(script).sorted())")
    }

    @Test func theBrushMovesTheGuideAlong() {
        var g = guide([[SIMD2(0, 0), SIMD2(0, 4)]])
        #expect(g.cursor == 0)
        #expect(g.advance(to: SIMD2(0, 0.1)) != .none)
        #expect(g.cursor > 0)
        let moved = g.cursor
        #expect(g.advance(to: SIMD2(3, 3)) == .none)      // far from the line: no progress
        #expect(g.cursor == moved)
    }

    @Test func cuttingAcrossTheShapeDoesNotCount() {
        var g = guide([[SIMD2(0, 0), SIMD2(0, 4)]])
        #expect(g.advance(to: SIMD2(0, 3.9)) == .none)     // too far ahead of the start
        #expect(g.cursor == 0)
    }

    @Test func tracingTheWholeLineFinishes() {
        var g = guide([[SIMD2(0, 0), SIMD2(0, 4)]])
        var y: Float = 0
        var last = TraceGuide.Progress.none
        while y <= 4.2 {
            let progress = g.advance(to: SIMD2(0, y))
            if progress != .none { last = progress }
            y += 0.2
        }
        #expect(g.isFinished)
        #expect(last == .finished)
        #expect(g.text == TraceGuide.finishText)
    }

    @Test func nextStepIsAnnouncedWhenTheBrushGetsClose() {
        var g = guide(mountain)
        #expect(g.currentLeg == 0)
        var sawChange = false
        var t: Float = 0
        while t <= 6, !g.isFinished {
            // Walk along the mountain: up the first side, down the second.
            let point: SIMD2<Float> = t <= 3 ? SIMD2(t, t) : SIMD2(t, 6 - t)
            if g.advance(to: point) == .legChanged { sawChange = true }
            t += 0.15
        }
        #expect(sawChange)
        #expect(g.isFinished)
    }

    @Test func eachShapeOfAnOutlineGetsItsOwnIntro() {
        let g = guide([[SIMD2(0, 0), SIMD2(0, 3)], [SIMD2(2, 0), SIMD2(2, 3)]])
        #expect(g.legs.count == 2)
        #expect(g.legs[0].path == 0)
        #expect(g.legs[1].path == 1)
        #expect(g.legs[1].text.lowercased().contains("bagian berikutnya"))
    }

    @Test func theArrowPointsTheWayOfTheLine() {
        let g = guide([[SIMD2(0, 0), SIMD2(0, 4)]])
        #expect(abs(g.heading - .pi / 2) < 0.1)
    }

    @Test func everyTemplateAndQuestCanBeGuided() {
        for design in TemplateCatalog.all {
            let lines = design.art.shape(center: .zero, size: SIMD2(4.6, 2.7)).lines
            #expect(TraceGuide(lines: lines)?.legs.isEmpty == false, "\(design.id)")
        }
    }
}

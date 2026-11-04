import Testing
import simd
@testable import PuffyPond

@MainActor
struct StrokeBookTests {
    private let red = SIMD3<Float>(1, 0, 0)
    private let spacing: Float = 0.05

    private func paint(_ book: inout StrokeBook, slot: Int = 0, _ x: Float, _ y: Float = 0) -> StrokeBook.PaintEvent? {
        book.paint(slot: slot, at: SIMD2(x, y), now: 0, color: red, brush: .ladybug, spacing: spacing)
    }

    @Test func firstDabStartsAStroke() {
        var book = StrokeBook()
        #expect(book.isEmpty)
        let result1 = paint(&book, 0)
        #expect(result1 == .started)
        #expect(book.count == 1 && book.activeSlots == [0])
    }

    @Test func movingGrowsTheSameStroke() {
        var book = StrokeBook()
        _ = paint(&book, 0)
        _ = paint(&book, 0.02)          // too close for a bead
        #expect(book.strokes[0].points.count == 1)
        _ = paint(&book, 0.1)
        #expect(book.count == 1)
        #expect(book.strokes[0].points.count > 1)
    }

    @Test func blipsEveryLittleWhile() {
        var book = StrokeBook()
        _ = paint(&book, 0)
        let result2 = paint(&book, 0.1)
        #expect(result2 == nil)
        let result3 = paint(&book, 0.2)
        #expect(result3 == .blip)
        let result4 = paint(&book, 0.3)
        #expect(result4 == nil)
    }

    @Test func eachHandHasItsOwnStroke() {
        var book = StrokeBook()
        let result5 = paint(&book, slot: 0, 0)
        #expect(result5 == .started)
        let result6 = paint(&book, slot: 1, 1)
        #expect(result6 == .started)
        #expect(book.count == 2 && Set(book.activeSlots) == [0, 1])
    }

    @Test func finishingEndsTheStrokeOnce() {
        var book = StrokeBook()
        _ = paint(&book, 0)
        let result7 = book.finish(slot: 0)
        #expect(result7)
        let again = book.finish(slot: 0)
        #expect(!again)
        let result8 = paint(&book, 0.5)
        #expect(result8 == .started)
        #expect(book.count == 2)
    }

    @Test func finishingForgetsWhereTheDabsStarted() {
        var book = StrokeBook()
        book.stamped(slot: 0, at: SIMD2(0.3, 0))
        #expect(book.stampStart(slot: 0, at: SIMD2(9, 9)) == SIMD2(0.3, 0))
        book.finish(slot: 0)
        #expect(book.stampStart(slot: 0, at: SIMD2(9, 9)) == SIMD2(9, 9))
    }

    @Test func erasingTheMiddleSplitsAStrokeInTwo() {
        var book = StrokeBook()
        for x: Float in [0, 0.1, 0.2, 0.3, 0.4] { _ = paint(&book, x) }
        let result9 = book.erase(at: SIMD2(0.2, 0), radius: 0.03)
        #expect(result9)
        #expect(book.count == 2)
        // The hand keeps painting the first piece.
        let result10 = paint(&book, 0.5)
        #expect(result10 != .started)
    }

    @Test func missingEverythingErasesNothing() {
        var book = StrokeBook()
        _ = paint(&book, 0)
        let erased = book.erase(at: SIMD2(5, 5), radius: 0.1)
        #expect(!erased)
        #expect(book.count == 1)
    }

    @Test func wipingAStrokeAwayStartsANewOneUnderTheHand() {
        var book = StrokeBook()
        _ = paint(&book, 0)
        let result11 = book.erase(at: .zero, radius: 1)
        #expect(result11)
        #expect(book.isEmpty && book.activeSlots.isEmpty)
        let result12 = paint(&book, 0.5)
        #expect(result12 == .started)
    }

    @Test func clearForgetsEverything() {
        var book = StrokeBook()
        _ = paint(&book, slot: 0, 0)
        _ = paint(&book, slot: 1, 1)
        book.clear()
        #expect(book.isEmpty && book.activeSlots.isEmpty)
    }
}

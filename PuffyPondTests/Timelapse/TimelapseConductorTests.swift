import Testing
@testable import PuffyPond

struct TimelapseConductorTests {
    private let timeline = ReplayTimeline(eventTimes: [0, 1, 2])
    private let notes = [
        ReplayNote(time: 0.2, pitch: 0.1, pan: 0, voice: .note(.bell)),
        ReplayNote(time: 0.9, pitch: 0.5, pan: 0, voice: .poof),
        ReplayNote(time: 1.5, pitch: 0.9, pan: 0, voice: .note(.pluck)),
    ]

    private func conductor() -> TimelapseConductor { TimelapseConductor(timeline: timeline, notes: notes) }

    /// Plays from a start on the beat grid to the end in slices of `dt`, returning every note that came out.
    private func playThrough(_ conductor: TimelapseConductor, dt: Double = 0.3) -> [ReplayNote] {
        conductor.start(beat: 10)
        var heard = conductor.advance(dt: 0.01, beat: 10.25)   // the next 16th note: playing begins
        var guardCount = 0
        while conductor.phase != .finished, guardCount < 1000 {
            heard += conductor.advance(dt: dt, beat: 11)
            guardCount += 1
        }
        return heard
    }

    @Test func notesFireOnceAndInOrder() {
        let conductor = conductor()
        #expect(playThrough(conductor) == notes)
        #expect(conductor.phase == .finished)
    }

    @Test func startWaitsForTheNextSixteenth() {
        let conductor = conductor()
        conductor.start(beat: 10)
        for _ in 0..<5 { _ = conductor.advance(dt: 0.05, beat: 10.0) }
        #expect(conductor.phase == .waitingForBeat)
        _ = conductor.advance(dt: 0.05, beat: 10.25)
        #expect(conductor.phase == .playing)
    }

    @Test func startGivesUpWaitingWhenTheBeatNeverMoves() {
        let conductor = conductor()
        conductor.start(beat: 10)
        for _ in 0..<7 { _ = conductor.advance(dt: 0.05, beat: 10.0) }
        #expect(conductor.phase == .playing)
    }

    @Test func emptyTimelineFinishesImmediately() {
        let conductor = TimelapseConductor(timeline: ReplayTimeline(eventTimes: []), notes: [])
        conductor.start(beat: 3)
        #expect(conductor.phase == .finished)
        #expect(conductor.advance(dt: 1, beat: 4).isEmpty)
    }

    @Test func skipFinishesWithoutNotesAndTwiceIsHarmless() {
        let conductor = conductor()
        conductor.start(beat: 10)
        _ = conductor.advance(dt: 0.01, beat: 10.25)
        conductor.skip()
        conductor.skip()
        #expect(conductor.phase == .finished)
        #expect(conductor.replayTime == timeline.duration)
        #expect(conductor.advance(dt: 5, beat: 12).isEmpty)
    }

    @Test func cancelStopsLaterNotes() {
        let conductor = conductor()
        conductor.start(beat: 10)
        _ = conductor.advance(dt: 0.01, beat: 10.25)
        conductor.cancel()
        #expect(conductor.phase == .finished)
        #expect(conductor.advance(dt: 5, beat: 12).isEmpty)
    }

    @Test func restartPlaysAgain() {
        let conductor = conductor()
        #expect(playThrough(conductor) == notes)
        #expect(playThrough(conductor) == notes)
    }
}

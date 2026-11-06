import Testing
import simd
@testable import PuffyPond

struct NoteComposerTests {
    private let step = NoteComposer.stepSeconds

    private func dab(t: Double, x: Float = 0, y: Float = 0.1, length: Float = 0.1, speed: Float = 1,
                     stroke: Float = 1, brush: CritterKind = .butterfly, blend: Float = 0) -> RecordedEvent {
        var style = BrushStyle.brush
        style.blend = blend
        return .dab(RecordedDab(t: t, from: SIMD2(x - length, y), to: SIMD2(x, y), radius: 0.1, speed: speed,
                                color: SIMD3(1, 0, 0), seed: 0, strokeSeed: stroke, style: style, drag: nil,
                                ncaModel: 0, brush: brush))
    }

    private func compose(_ events: [RecordedEvent]) -> [ReplayNote] {
        let recording = StrokeRecording(events: events)
        return NoteComposer.compose(recording, timeline: ReplayTimeline(eventTimes: events.map(\.t)))
    }

    @Test func oneNotePerStrokePerStep() {
        let notes = compose([dab(t: 0), dab(t: step * 0.3), dab(t: step * 0.6)])
        #expect(notes.count == 1)
    }

    @Test func pitchFollowsHeight() {
        let notes = compose([dab(t: 0, y: 2.1, stroke: 1), dab(t: 0.5, y: -1.9, stroke: 2)])
        #expect(notes.count == 2)
        #expect(abs(notes[0].pitch - 1) < 1e-5)
        #expect(abs(notes[1].pitch - 0) < 1e-5)
    }

    @Test func notesLandOnTheStepGrid() {
        var events: [RecordedEvent] = []
        for i in 0..<40 { events.append(dab(t: Double(i) * 0.037, speed: i % 3 == 0 ? 4 : 1, stroke: Float(i % 4))) }
        for note in compose(events) {
            let position = note.time / step
            let fraction = position - position.rounded(.down)
            #expect(abs(fraction) < 1e-9 || abs(fraction - 0.5) < 1e-9, "note at \(note.time)")
        }
    }

    @Test func globalCapKeepsTheBusiestStrokes() {
        // Six strokes in one step; stroke i is (i + 1) tenths long and ends at x = (i - 3) / 2.
        let events = (0..<6).map { i in
            dab(t: Double(i) * 0.01, x: Float(i - 3) * 0.5, length: Float(i + 1) * 0.1, stroke: Float(i))
        }
        let notes = compose(events + [dab(t: 0.5, stroke: 99)])
        let inFirstStep = notes.filter { $0.time < step }
        #expect(inFirstStep.count == NoteComposer.maxNotesPerStep)
        let wanted = [0.0, 0.5, 1.0].map { Float($0) / (Float(Playground.canvasSize.x) / 2) }
        let pans = inFirstStep.map(\.pan).sorted()
        for (got, want) in zip(pans, wanted) { #expect(abs(got - want) < 1e-5) }
    }

    @Test func fastStrokeAddsAGraceNote() {
        let notes = compose([dab(t: 0, speed: 4), dab(t: step * 0.5, speed: 4)])
        #expect(notes.count == 2)
        #expect(abs(notes[1].time - (notes[0].time + step / 2)) < 1e-9)
        #expect(abs(notes[1].pitch - (notes[0].pitch + 1.0 / 9)) < 1e-5)
    }

    @Test func blenderMakesNoNotes() {
        #expect(compose([dab(t: 0, blend: 1), dab(t: 0.2, blend: 1)]).isEmpty)
    }

    @Test func eraseGivesOnePoofPerStep() {
        let erase = { (t: Double) in
            RecordedEvent.erase(RecordedErase(t: t, center: SIMD2(1.6, 0), radius: 0.3, dt: 0.016))
        }
        let notes = compose([erase(0), erase(step * 0.4), erase(step * 0.8)])
        #expect(notes.count == 1)
        #expect(notes.first?.voice == .poof)
        #expect(notes.first.map { abs($0.pan - 0.5) < 1e-5 } == true)
    }

    @Test func timbreFollowsTheBrush() {
        let brushes: [(CritterKind, NoteTimbre)] = [(.butterfly, .bell), (.ladybug, .pluck), (.snail, .marimba),
                                                    (.frog, .xylophone)]
        for (brush, timbre) in brushes {
            let notes = compose([dab(t: 0, brush: brush), dab(t: 0.05, brush: brush)])
            #expect(notes.first?.voice == .note(timbre), "\(brush)")
        }
    }

    @Test func emptyRecordingGivesNoNotes() {
        #expect(NoteComposer.compose(StrokeRecording(), timeline: ReplayTimeline(eventTimes: [])).isEmpty)
    }
}

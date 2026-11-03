import Foundation

/// The clock of one timelapse: waits for the tune's next 16th note so the replay's note grid lines up with the
/// music, then counts replay time and hands out each note once as its time passes. Pure; the page does the drawing
/// and the sound.
final class TimelapseConductor {
    enum Phase: Equatable { case waitingForBeat, playing, finished }

    /// Seconds to wait for the beat to move before assuming the audio isn't running.
    private static let beatPatience = 0.3

    private let timeline: ReplayTimeline
    private let notes: [ReplayNote]
    /// Starts as `.finished`: nothing plays until `start`.
    private(set) var phase: Phase = .finished
    private(set) var replayTime: Double = 0
    private var nextNote = 0
    private var startStep = 0
    private var waited = 0.0

    init(timeline: ReplayTimeline, notes: [ReplayNote]) {
        self.timeline = timeline
        self.notes = notes
    }

    /// Begins (or restarts) the replay. An empty or zero-length timeline finishes at once.
    func start(beat: Double) {
        replayTime = 0
        nextNote = 0
        waited = 0
        startStep = Self.step(of: beat)
        phase = timeline.duration > 0 ? .waitingForBeat : .finished
    }

    /// Moves time on by `dt`, and returns the notes whose time passed, each exactly once.
    func advance(dt: Double, beat: Double) -> [ReplayNote] {
        switch phase {
        case .finished:
            return []
        case .waitingForBeat:
            waited += dt
            if Self.step(of: beat) > startStep || waited >= Self.beatPatience { phase = .playing }
            return []
        case .playing:
            replayTime = min(replayTime + dt, timeline.duration)
            var due: [ReplayNote] = []
            while nextNote < notes.count, notes[nextNote].time <= replayTime {
                due.append(notes[nextNote])
                nextNote += 1
            }
            if replayTime >= timeline.duration { phase = .finished }
            return due
        }
    }

    /// Jumps to the end without any more notes.
    func skip() {
        replayTime = timeline.duration
        nextNote = notes.count
        phase = .finished
    }

    /// Stops for good (the page is closing): no more notes.
    func cancel() {
        nextNote = notes.count
        phase = .finished
    }

    private static func step(of beat: Double) -> Int { Int((beat * 4).rounded(.down)) }
}

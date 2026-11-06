import Foundation
import simd

/// Which instrument a brush animal plays in the timelapse.
enum NoteTimbre: Int, CaseIterable {
    case bell, pluck, marimba, xylophone

    init(brush: CritterKind) {
        switch brush {
        case .butterfly: self = .bell
        case .ladybug: self = .pluck
        case .snail: self = .marimba
        case .frog: self = .xylophone
        default: self = .xylophone
        }
    }
}

/// One sound of the timelapse, on the tune's 16th-note grid.
struct ReplayNote: Equatable {
    enum Voice: Equatable {
        case note(NoteTimbre)
        case poof
    }

    /// Replay seconds: a step start, or half a step after one for a grace note.
    var time: Double
    /// Place on the scale, 0 (low) to 1 (high): `Sfx.note`'s `a`.
    var pitch: Float
    var pan: Float
    var voice: Voice
}

/// Turns a recording into music: a note for each stroke on each beat-grid step, pitched by how high on the canvas
/// it is, so the painting plays like an instrument.
enum NoteComposer {
    /// One 16th note of the background tune.
    static let stepSeconds: Double = 60 / GrooveDSP.bpm / 4
    /// Notes starting on the same step, over all strokes: busier steps drop their quietest strokes.
    static let maxNotesPerStep = 3
    /// Above this stroke speed (world units per second) a stroke adds a grace note half a step later.
    static let fastSpeed: Float = 2.5

    /// The canvas is centred here; height 0…1 runs bottom to top.
    private static let canvasCenterY: Float = 0.1

    private struct Burst {
        var brush: CritterKind
        var length: Float = 0
        var x: Float = 0
        var y: Float = 0
        var speed: Float = 0
        var count: Float = 0
    }

    /// Sorted by time.
    static func compose(_ recording: StrokeRecording, timeline: ReplayTimeline) -> [ReplayNote] {
        guard timeline.duration > 0 else { return [] }
        let size = Playground.canvasSize
        func pan(_ x: Float) -> Float { min(max(x / (size.x / 2), -1), 1) }

        var bursts: [Int: [Float: Burst]] = [:]
        var poofs: [Int: Float] = [:]
        for event in recording.events {
            let step = Int((timeline.replayTime(forRecorded: event.t) / stepSeconds).rounded(.down))
            switch event {
            case .dab(let dab):
                guard dab.style.blend <= 0.5 else { continue }
                var burst = bursts[step]?[dab.strokeSeed] ?? Burst(brush: dab.brush)
                burst.length += simd_distance(dab.from, dab.to)
                burst.x += dab.to.x
                burst.y += dab.to.y
                burst.speed += dab.speed
                burst.count += 1
                bursts[step, default: [:]][dab.strokeSeed] = burst
            case .erase(let erase):
                if poofs[step] == nil { poofs[step] = erase.center.x }
            }
        }

        var notes: [ReplayNote] = []
        for step in Set(bursts.keys).union(poofs.keys) {
            let start = Double(step) * stepSeconds
            // (weight, seed, notes): a poof outranks every stroke.
            var candidates: [(weight: Float, seed: Float, notes: [ReplayNote])] = []
            if let x = poofs[step] {
                candidates.append((.infinity, -.infinity, [ReplayNote(time: start, pitch: 0, pan: pan(x), voice: .poof)]))
            }
            for (seed, burst) in bursts[step] ?? [:] {
                let pitch = min(max((burst.y / burst.count - canvasCenterY) / size.y + 0.5, 0), 1)
                let voice = ReplayNote.Voice.note(NoteTimbre(brush: burst.brush))
                var played = [ReplayNote(time: start, pitch: pitch, pan: pan(burst.x / burst.count), voice: voice)]
                if burst.speed / burst.count > fastSpeed {
                    played.append(ReplayNote(time: start + stepSeconds / 2, pitch: min(pitch + 1 / 9, 1),
                                             pan: played[0].pan, voice: voice))
                }
                candidates.append((burst.length, seed, played))
            }
            candidates.sort { ($0.weight, $1.seed) > ($1.weight, $0.seed) }
            for candidate in candidates.prefix(maxNotesPerStep) { notes += candidate.notes }
        }
        return notes.sorted { $0.time < $1.time }
    }
}

import AVFoundation
import os

/// Sound effects the game can ask for.
nonisolated enum Sfx: UInt8, Sendable, CaseIterable {
    case blip      // a critter lays a bead of paint (a = height 0…1, b = pan)
    case pop       // something pops (b = pan)
    case fanfare   // creature is born
    case swap      // tried to save an empty canvas (b = pan)
    case fizzle    // transform with nothing to inflate
    case gurgle    // a critter rubbing in a paint pot (a = progress 0…1, b = pan)
    case pick      // a critter soaks up a new color (a = color index, b = pan)
    case splash    // a palm slaps the wet painting (a = strength 0…1, b = pan)
    case sproing   // a fist catches the paint like a rubber band (b = pan)
    case wobble    // the paint lets go and jiggles home like jelly (b = pan)
    case whistleUp // slide whistle swoops up (two fists pull apart)
    case whistleDown // slide whistle swoops down (two fists let go)
    case quack     // a rubber duck (b = pan)
    case splat     // a hard slap of wet paint (a = strength 0…1, b = pan)
    case honk      // clown horn: "ha-HONK"
    case bonk      // a wooden cartoon "bonk" (b = pan)
    case chicken   // a rubber chicken squawk (b = pan)
    case slurp     // a wet smear for the blender (a = speed 0…1, b = pan)
    case poof      // a soft spore puff (b = pan)
    case ooze      // a gloopy rising bubble while a brush is held still (a = hold 0…1, b = pan)
    case note      // a timelapse note (a = place on the pentatonic scale 0…1, b = pan, c = NoteTimbre)
    case pour      // thick paint pouring out of a held brush: a wet rush with bubbles (a = hold 0…1, b = pan)
}

/// Which tune the background music plays.
nonisolated enum Tune: UInt8, Sendable {
    case groove    // the cheerful toy-pop groove
    case silly     // a wobbly circus oom-pah with a kazoo
}

nonisolated struct SfxEvent: Sendable {
    var kind: Sfx
    var a: Float
    var b: Float
    var c: Float = 0
}

nonisolated private enum Wave: UInt8 { case sine, triangle, square, fm, noise }

nonisolated private struct Biquad {
    var b0: Float = 1, b1: Float = 0, b2: Float = 0, a1: Float = 0, a2: Float = 0
    var z1: Float = 0, z2: Float = 0

    static func bandPass(_ f: Float, q: Float, sr: Float) -> Biquad {
        let w0 = 2 * Float.pi * min(f, sr * 0.45) / sr
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        return Biquad(b0: alpha / a0, b1: 0, b2: -alpha / a0, a1: -2 * cos(w0) / a0, a2: (1 - alpha) / a0)
    }

    static func highPass(_ f: Float, q: Float, sr: Float) -> Biquad {
        let w0 = 2 * Float.pi * min(f, sr * 0.45) / sr
        let alpha = sin(w0) / (2 * q)
        let cw = cos(w0)
        let a0 = 1 + alpha
        return Biquad(b0: (1 + cw) / 2 / a0, b1: -(1 + cw) / a0, b2: (1 + cw) / 2 / a0,
                      a1: -2 * cw / a0, a2: (1 - alpha) / a0)
    }

    mutating func process(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}

nonisolated private struct Voice {
    var active = false
    var delay = 0
    var wave: Wave = .sine
    var frequency: Float = 440
    var glideTarget: Float = 440
    var glideRate: Float = 0          // 0 = no glide
    var phase: Float = 0
    var modPhase: Float = 0
    var modRatio: Float = 2
    var modIndex: Float = 0
    var modDecay: Float = 1
    var amplitude: Float = 0
    var peak: Float = 0
    var attackStep: Float = 1
    var attacking = true
    var decay: Float = 0.999
    var vibratoDepth: Float = 0
    var vibratoRate: Float = 0
    var vibratoPhase: Float = 0
    var lowpass: Float = 1            // one-pole coefficient (1 = off)
    var lowState: Float = 0
    var useFilter = false
    var filter = Biquad()
    var left: Float = 0.7
    var right: Float = 0.7
}

/// A bouncy 104 BPM garden tune, synthesized live: a soft thumpy kick, wood blocks, a shaker, a plucky
/// pizzicato bass, ukulele strums and a xylophone melody over G–C–D–Em. Layers swell with how much you're moving.
/// Also renders every sound effect, and publishes a beat clock for animations.
nonisolated final class GrooveDSP: @unchecked Sendable {
    static let bpm: Double = 104
    private static let voiceCount = 64
    private static let tableSize = 4096
    private static let queueCapacity = 64

    private static let roots: [Float] = [43, 48, 50, 40]            // G C D E
    private static let triads: [[Float]] = [[62, 67, 71], [64, 67, 72], [62, 66, 69], [64, 67, 71]]
    private static let bassSteps: [Int: Float] = [0: 0, 3: 0, 6: 12, 8: 0, 10: 7, 14: 12]
    private static let melody: [[Float]] = [
        [74, -1, 79, -1, 74, -1, 71, -1, 74, -1, 79, -1, 83, -1, 79, -1],
        [76, -1, 79, -1, 84, -1, 79, -1, 76, -1, 72, -1, 76, -1, -1, -1],
        [78, -1, 81, -1, 78, -1, 74, -1, 78, -1, 81, -1, 86, -1, 81, -1],
        [79, -1, 76, -1, 71, -1, 76, -1, 79, 76, 71, -1, 76, -1, -1, -1],
        [79, -1, 83, -1, 86, -1, 83, -1, 79, -1, 74, -1, 79, -1, 83, -1],
        [84, -1, -1, 79, -1, -1, 76, -1, 79, -1, 84, -1, 88, -1, 84, -1],
        [81, -1, 78, -1, 74, -1, 78, -1, 81, 78, 74, -1, 78, -1, 81, -1],
        [79, -1, 76, -1, 74, 76, 79, -1, 83, -1, 79, -1, -1, -1, -1, -1],
    ]
    private static let blipScale: [Float] = [79, 81, 84, 86, 88, 91, 93, 96, 98, 100]
    /// C major pentatonic over two octaves: every note fits every other, and the silly tune is in C.
    private static let noteScale: [Float] = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93]

    // The silly tune: C F G C twice, a staccato kazoo over a tuba oom-pah.
    private static let sillyRoots: [Float] = [36, 41, 43, 36]
    private static let sillyTriads: [[Float]] = [[60, 64, 67], [60, 65, 69], [59, 62, 67], [60, 64, 67]]
    private static let sillyMelody: [[Float]] = [
        [72, -1, 76, -1, 79, -1, 76, -1, 72, -1, 76, -1, 79, -1, 84, -1],
        [81, 80, 81, -1, 77, -1, 72, -1, 77, -1, 81, 80, 81, -1, -1, -1],
        [79, -1, 83, -1, 86, -1, 83, -1, 79, 78, 79, -1, 74, -1, -1, -1],
        [84, -1, 79, -1, 76, -1, 79, -1, 72, -1, -1, 67, 72, -1, -1, -1],
        [72, 74, 76, 77, 79, -1, 79, -1, 79, 77, 76, 74, 72, -1, -1, -1],
        [77, -1, 77, -1, 81, -1, 81, -1, 84, -1, 83, -1, 81, -1, 77, -1],
        [79, -1, -1, 79, -1, -1, 79, -1, 83, -1, 81, -1, 79, -1, 74, -1],
        [72, -1, 76, -1, 79, -1, 84, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    ]

    static func hz(_ midi: Float) -> Float { 440 * pow(2, (midi - 69) / 12) }

    private let sampleRate: Float
    private let samplesPerStep: Double

    // Shared with the main thread
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    private let queue = UnsafeMutablePointer<SfxEvent>.allocate(capacity: GrooveDSP.queueCapacity)
    private var queueCount = 0                     // guarded by `lock`
    private let shared = UnsafeMutablePointer<Double>.allocate(capacity: 4)   // [beat, energy, master, tune]

    // Audio thread
    private let table = UnsafeMutablePointer<Float>.allocate(capacity: GrooveDSP.tableSize)
    private let voices = UnsafeMutablePointer<Voice>.allocate(capacity: GrooveDSP.voiceCount)
    private var nextVoice = 0
    private var stepClock: Double = 0
    private var step = 0                 // 16th within the bar
    private var bar = 0
    private var totalSteps: Double = 0
    private var energy: Float = 0
    private var master: Float = 0
    private var noiseSeed: UInt32 = 0x9E37_79B9

    init(sampleRate: Float) {
        self.sampleRate = sampleRate
        samplesPerStep = Double(sampleRate) * 60 / Self.bpm / 4
        lock.initialize(to: os_unfair_lock())
        queue.initialize(repeating: SfxEvent(kind: .blip, a: 0, b: 0), count: Self.queueCapacity)
        shared.initialize(repeating: 0, count: 4)
        shared[2] = 1
        for i in 0..<Self.tableSize {
            table[i] = sin(2 * Float.pi * Float(i) / Float(Self.tableSize))
        }
        voices.initialize(repeating: Voice(), count: Self.voiceCount)
        stepClock = samplesPerStep   // first downbeat right away
    }

    deinit {
        lock.deallocate()
        queue.deallocate()
        shared.deallocate()
        table.deallocate()
        voices.deallocate()
    }

    // MARK: Main-thread API

    func play(_ event: SfxEvent) {
        os_unfair_lock_lock(lock)
        if queueCount < Self.queueCapacity {
            queue[queueCount] = event
            queueCount += 1
        }
        os_unfair_lock_unlock(lock)
    }

    func setEnergy(_ value: Float) { shared[1] = Double(value) }
    /// Mutes only the background music. Sound effects (the critters, paint, pops) keep playing.
    func setMuted(_ muted: Bool) { shared[2] = muted ? 0 : 1 }
    func setTune(_ tune: Tune) { shared[3] = Double(tune.rawValue) }
    /// Musical time in beats (quarter notes) since start.
    var beat: Double { shared[0] }

    func makeRenderBlock() -> AVAudioSourceNodeRenderBlock {
        return { _, _, frameCount, audioBufferList in
            self.render(frameCount: Int(frameCount), bufferList: audioBufferList)
            return noErr
        }
    }

    // MARK: Synthesis helpers (audio thread)

    @inline(__always)
    private func sine(_ phase: Float) -> Float {
        let p = phase - phase.rounded(.down)
        let x = p * Float(Self.tableSize)
        let i = Int(x)
        let f = x - Float(i)
        let a = table[i & (Self.tableSize - 1)]
        let b = table[(i + 1) & (Self.tableSize - 1)]
        return a + (b - a) * f
    }

    @inline(__always)
    private func noise() -> Float {
        noiseSeed ^= noiseSeed << 13
        noiseSeed ^= noiseSeed >> 17
        noiseSeed ^= noiseSeed << 5
        return Float(noiseSeed) / Float(UInt32.max) * 2 - 1
    }

    private static func polyBLEP(_ t: Float, _ dt: Float) -> Float {
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        } else if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    private func coefficient(seconds: Float) -> Float { exp(-1 / (max(seconds, 0.0005) * sampleRate)) }
    private func lowpass(_ cutoff: Float) -> Float { 1 - exp(-2 * Float.pi * cutoff / sampleRate) }

    /// Starts a voice. `decay` is the time to fade by ~60 dB.
    private func start(_ wave: Wave, _ frequency: Float, peak: Float, decay: Float, at delay: Int,
                       pan: Float = 0, attack: Float = 0.002, glideFrom: Float? = nil, glideTime: Float = 0,
                       vibrato: (depth: Float, rate: Float) = (0, 0), cutoff: Float? = nil,
                       filter: Biquad? = nil, fm: (ratio: Float, index: Float, decay: Float)? = nil) {
        var v = Voice()
        v.active = true
        v.delay = max(delay, 0)
        v.wave = wave
        v.glideTarget = frequency
        v.frequency = glideFrom ?? frequency
        v.glideRate = glideFrom == nil ? 0 : 1 - coefficient(seconds: glideTime)
        v.peak = peak
        v.attackStep = peak / max(attack * sampleRate, 1)
        v.decay = exp(-6.9 / (max(decay, 0.01) * sampleRate))
        v.vibratoDepth = vibrato.depth
        v.vibratoRate = vibrato.rate / sampleRate
        v.lowpass = cutoff.map { lowpass($0) } ?? 1
        if let filter {
            v.useFilter = true
            v.filter = filter
        }
        if let fm {
            v.modRatio = fm.ratio
            v.modIndex = fm.index
            v.modDecay = coefficient(seconds: fm.decay)
            v.modPhase = 0.25
        }
        let angle = (max(-1, min(pan, 1)) + 1) * Float.pi / 4
        v.left = cos(angle)
        v.right = sin(angle)
        voices[nextVoice] = v
        nextVoice = (nextVoice + 1) % Self.voiceCount
    }

    // MARK: The groove

    private func playStep(at offset: Int) {
        if shared[3] >= 0.5 {
            playSillyStep(at: offset)
            return
        }
        let chord = bar % 4
        let section = bar % 8
        let root = Self.roots[chord]
        let groove: Float = 0.75 + 0.25 * energy

        // Soft thumpy kick on the beat, wood blocks on 2 and 4.
        if step % 8 == 0 {
            start(.sine, 62, peak: 0.55, decay: 0.2, at: offset, attack: 0.002, glideFrom: 150, glideTime: 0.04)
        }
        if step == 4 || step == 12 || (section == 7 && step >= 12) {
            let peak: Float = step == 12 || step == 4 ? 0.16 : 0.1
            start(.sine, 1100, peak: peak, decay: 0.05, at: offset, pan: 0.2, attack: 0.001, glideFrom: 1300, glideTime: 0.01)
            start(.noise, 0, peak: peak * 0.7, decay: 0.02, at: offset, pan: 0.2,
                  filter: .bandPass(2000, q: 3, sr: sampleRate))
        }
        // Shaker: eighths, with the offbeats accented; sixteenths join in when you move.
        if step % 2 == 0 {
            let accent: Float = step % 4 == 2 ? 0.1 : 0.05
            start(.noise, 0, peak: accent * groove, decay: 0.045, at: offset, pan: -0.3,
                  filter: .highPass(6500, q: 0.8, sr: sampleRate))
        } else if energy > 0.35 {
            start(.noise, 0, peak: 0.03, decay: 0.025, at: offset, pan: 0.3, filter: .highPass(8000, q: 0.8, sr: sampleRate))
        }

        // Pizzicato bass
        if let interval = Self.bassSteps[step] {
            start(.triangle, Self.hz(root + interval), peak: 0.3, decay: 0.16, at: offset, attack: 0.002, cutoff: 700 + 400 * energy)
        }

        // Ukulele strums on the offbeats: four plucks, a hair apart.
        if step == 6 || step == 10 || step == 14 || (step == 2 && energy > 0.6) {
            let level: Float = (0.05 + 0.04 * energy) * (step == 10 ? 0.75 : 1)
            let strum = Self.triads[chord] + [Self.triads[chord][0] + 12]
            for (k, note) in strum.enumerated() {
                start(.triangle, Self.hz(note), peak: level, decay: 0.22, at: offset + Int(Float(k) * 0.011 * sampleRate),
                      pan: Float(k) * 0.3 - 0.45, attack: 0.001, cutoff: 3000)
            }
        }

        // Xylophone melody: always there, louder when you play.
        let note = Self.melody[section][step]
        if note > 0 {
            let lead: Float = 0.1 + 0.08 * energy
            start(.sine, Self.hz(note), peak: lead, decay: 0.3, at: offset, pan: 0.1, attack: 0.001)
            start(.fm, Self.hz(note + 12), peak: lead * 0.45, decay: 0.14, at: offset, pan: -0.1,
                  fm: (3.5, 1.6, 0.05))
        }

        // A little boing to close the phrase.
        if section == 7 && step == 15 {
            start(.sine, Self.hz(91), peak: 0.1, decay: 0.3, at: offset, attack: 0.005, glideFrom: Self.hz(67), glideTime: 0.12,
                  vibrato: (0.02, 9))
        }
    }

    private func playSillyStep(at offset: Int) {
        let chord = bar % 4
        let section = bar % 8

        if step % 8 == 0 {
            start(.sine, 55, peak: 0.45, decay: 0.2, at: offset, attack: 0.001, glideFrom: 140, glideTime: 0.03)
            let oom = Self.sillyRoots[chord] + (step == 0 ? 0 : 7)
            start(.square, Self.hz(oom), peak: 0.3, decay: 0.2, at: offset, attack: 0.004, cutoff: 520)
        }
        if step == 4 || step == 12 {
            for (k, note) in Self.sillyTriads[chord].enumerated() {
                start(.square, Self.hz(note), peak: 0.05, decay: 0.09, at: offset,
                      pan: Float(k - 1) * 0.4, attack: 0.002, cutoff: 2200)
            }
        }
        if step % 4 == 2 {
            let high = step % 8 == 2
            start(.sine, high ? 1250 : 880, peak: 0.1, decay: 0.035, at: offset, pan: high ? 0.35 : -0.35,
                  attack: 0.001, glideFrom: high ? 1500 : 1050, glideTime: 0.01)
        }

        let note = Self.sillyMelody[section][step]
        if note > 0 {
            let lead: Float = 0.1 + 0.05 * energy
            let scoop = step % 4 == 0 && section % 2 == 1
            start(.square, Self.hz(note), peak: lead, decay: 0.2, at: offset, pan: 0.1, attack: 0.006,
                  glideFrom: scoop ? Self.hz(note - 2.5) : nil, glideTime: 0.04, vibrato: (0.014, 6), cutoff: 2400)
            start(.noise, 0, peak: lead * 0.25, decay: 0.12, at: offset, pan: 0.1,
                  filter: .bandPass(Self.hz(note) * 2, q: 4, sr: sampleRate))
        }

        if section == 7 && step == 8 {
            start(.sine, Self.hz(96), peak: 0.1, decay: 0.6, at: offset, attack: 0.02, glideFrom: Self.hz(62),
                  glideTime: 0.25, vibrato: (0.012, 7))
        }
        if section % 4 == 3 && step == 15 {
            start(.sine, 800, peak: 0.1, decay: 0.12, at: offset, pan: -0.3, glideFrom: 300, glideTime: 0.04,
                  vibrato: (0.05, 20))
        }
    }

    private func playEffect(_ e: SfxEvent) {
        let pan = e.b
        switch e.kind {
        case .blip:
            let i = min(max(Int(e.a * Float(Self.blipScale.count)), 0), Self.blipScale.count - 1)
            let f = Self.hz(Self.blipScale[i])
            start(.sine, f, peak: 0.17, decay: 0.16, at: 0, pan: pan, attack: 0.002, glideFrom: f * 0.7, glideTime: 0.025)
            start(.fm, f * 2, peak: 0.04, decay: 0.12, at: 0, pan: pan, fm: (2, 1.2, 0.04))
        case .pop:
            start(.noise, 0, peak: 0.5, decay: 0.07, at: 0, pan: pan, filter: .bandPass(1000, q: 0.7, sr: sampleRate))
            start(.sine, 180, peak: 0.4, decay: 0.12, at: 0, pan: pan, glideFrom: 700, glideTime: 0.02)
            start(.sine, Self.hz(96), peak: 0.08, decay: 0.2, at: Int(0.03 * sampleRate), pan: pan)
        case .fanfare:
            start(.noise, 0, peak: 0.45, decay: 0.08, at: 0, filter: .bandPass(900, q: 0.7, sr: sampleRate))
            start(.sine, 70, peak: 0.6, decay: 0.3, at: 0, glideFrom: 240, glideTime: 0.03)
            let notes: [Float] = [72, 76, 79, 84, 88, 91]
            for (k, n) in notes.enumerated() {
                start(.fm, Self.hz(n), peak: 0.13, decay: 1.1, at: Int(Float(k) * 0.065 * sampleRate),
                      pan: Float(k) / 3 - 0.8, fm: (3.5, 2.0, 0.3))
            }
        case .swap:
            start(.sine, Self.hz(84), peak: 0.1, decay: 0.08, at: 0, glideFrom: Self.hz(79), glideTime: 0.02)
            start(.sine, Self.hz(91), peak: 0.08, decay: 0.1, at: Int(0.06 * sampleRate))
        case .gurgle:
            let f = Self.hz(60 + 12 * max(0, min(e.a, 1)) + Float(Int.random(in: 0...4)))
            start(.sine, f, peak: 0.09, decay: 0.07, at: 0, pan: pan, glideFrom: f * 0.6, glideTime: 0.02)
        case .pick:
            // Slurp up, then a bright two-note "ding" whose pitch matches the color.
            let base = Self.blipScale[min(max(Int(e.a), 0), 5) + 2]
            start(.sine, 900, peak: 0.12, decay: 0.15, at: 0, pan: pan, glideFrom: 250, glideTime: 0.06)
            start(.fm, Self.hz(base), peak: 0.15, decay: 0.7, at: Int(0.07 * sampleRate), pan: pan, fm: (3.5, 2.2, 0.15))
            start(.fm, Self.hz(base + 7), peak: 0.12, decay: 0.8, at: Int(0.15 * sampleRate), pan: pan, fm: (3.5, 2.2, 0.15))
        case .splash:
            let s = 0.5 + 0.5 * min(max(e.a, 0), 1)
            start(.noise, 0, peak: 0.22 * s, decay: 0.18, at: 0, pan: pan, filter: .bandPass(1400, q: 0.9, sr: sampleRate))
            start(.sine, 520, peak: 0.12 * s, decay: 0.14, at: 0, pan: pan, glideFrom: 1100, glideTime: 0.05)
            start(.noise, 0, peak: 0.08 * s, decay: 0.25, at: Int(0.05 * sampleRate), pan: -pan * 0.5,
                  filter: .bandPass(3200, q: 1.4, sr: sampleRate))
        case .sproing:
            start(.sine, 180, peak: 0.28, decay: 0.5, at: 0, pan: pan, glideFrom: 900, glideTime: 0.05,
                  vibrato: (0.18, 14))
            start(.fm, 360, peak: 0.08, decay: 0.4, at: 0, pan: pan, fm: (1.5, 2.5, 0.2))
        case .wobble:
            start(.sine, 220, peak: 0.26, decay: 0.7, at: 0, pan: pan, glideFrom: 520, glideTime: 0.25,
                  vibrato: (0.25, 11))
            start(.triangle, 110, peak: 0.1, decay: 0.6, at: 0, pan: pan, glideFrom: 260, glideTime: 0.25,
                  vibrato: (0.2, 11))
        case .whistleUp:
            start(.sine, Self.hz(96), peak: 0.13, decay: 0.5, at: 0, attack: 0.03, glideFrom: Self.hz(60),
                  glideTime: 0.18, vibrato: (0.012, 7))
            start(.noise, 0, peak: 0.03, decay: 0.4, at: 0, attack: 0.05, filter: .bandPass(2500, q: 1.5, sr: sampleRate))
        case .whistleDown:
            start(.sine, Self.hz(60), peak: 0.13, decay: 0.5, at: 0, attack: 0.01, glideFrom: Self.hz(94),
                  glideTime: 0.2, vibrato: (0.012, 7))
            start(.noise, 0, peak: 0.03, decay: 0.3, at: 0, filter: .bandPass(2000, q: 1.5, sr: sampleRate))
        case .quack:
            let bases: [Float] = [330, 290]
            for (k, base) in bases.enumerated() {
                start(.square, base, peak: 0.2, decay: 0.12, at: Int(Float(k) * 0.15 * sampleRate), pan: pan,
                      attack: 0.004, glideFrom: base * 1.6, glideTime: 0.05, vibrato: (0.04, 40), cutoff: 1400)
                start(.noise, 0, peak: 0.05, decay: 0.1, at: Int(Float(k) * 0.15 * sampleRate), pan: pan,
                      filter: .bandPass(1200, q: 1.5, sr: sampleRate))
            }
        case .splat:
            let s = 0.5 + 0.5 * min(max(e.a, 0), 1)
            start(.noise, 0, peak: 0.3 * s, decay: 0.09, at: 0, pan: pan, filter: .bandPass(500, q: 1.5, sr: sampleRate))
            start(.sine, 140, peak: 0.25 * s, decay: 0.1, at: 0, pan: pan, glideFrom: 400, glideTime: 0.03)
            start(.noise, 0, peak: 0.1 * s, decay: 0.06, at: Int(0.03 * sampleRate), pan: -pan * 0.5,
                  filter: .bandPass(2200, q: 1.2, sr: sampleRate))
        case .honk:
            let bases: [Float] = [262, 330]
            for (k, base) in bases.enumerated() {
                let at = Int(Float(k) * 0.16 * sampleRate)
                start(.square, base, peak: 0.16, decay: 0.25, at: at, attack: 0.01, glideFrom: base * 0.8,
                      glideTime: 0.03, cutoff: 2000)
                start(.square, base * 1.012, peak: 0.12, decay: 0.25, at: at, attack: 0.01, glideFrom: base * 0.8,
                      glideTime: 0.03, cutoff: 2000)
            }
        case .fizzle:
            start(.sine, 220, peak: 0.12, decay: 0.4, at: 0, glideFrom: 500, glideTime: 0.2)
            start(.noise, 0, peak: 0.1, decay: 0.3, at: 0, filter: .bandPass(700, q: 0.8, sr: sampleRate))
        case .bonk:
            start(.sine, 110, peak: 0.35, decay: 0.18, at: 0, pan: pan, attack: 0.001, glideFrom: 320, glideTime: 0.04)
            start(.sine, 900, peak: 0.12, decay: 0.05, at: 0, pan: pan, attack: 0.001)
            start(.noise, 0, peak: 0.2, decay: 0.015, at: 0, pan: pan, filter: .bandPass(1800, q: 4, sr: sampleRate))
        case .chicken:
            for (k, base) in [Float(600), 560].enumerated() {
                let at = Int(Float(k) * 0.17 * sampleRate)
                start(.square, base, peak: 0.13, decay: 0.3, at: at, pan: pan, attack: 0.01, glideFrom: base * 0.65,
                      glideTime: 0.03, vibrato: (0.08, 30), cutoff: 1800)
                start(.square, base * 1.03, peak: 0.1, decay: 0.3, at: at, pan: pan, attack: 0.01,
                      glideFrom: base * 0.65, glideTime: 0.03, vibrato: (0.08, 33), cutoff: 1800)
            }
            start(.noise, 0, peak: 0.05, decay: 0.3, at: 0, pan: pan, filter: .bandPass(1500, q: 1.2, sr: sampleRate))
        case .slurp:
            let f = 260 - 80 * min(max(e.a, 0), 1)
            start(.sine, f * 0.6, peak: 0.16, decay: 0.2, at: 0, pan: pan, attack: 0.01, glideFrom: f * 1.6, glideTime: 0.12,
                  vibrato: (0.12, 22))
            start(.noise, 0, peak: 0.12, decay: 0.18, at: 0, pan: pan, attack: 0.01,
                  filter: .bandPass(900, q: 1.4, sr: sampleRate))
        case .ooze:
            let top = 220 + 260 * min(max(e.a, 0), 1)
            start(.sine, top, peak: 0.2, decay: 0.3, at: 0, pan: pan, attack: 0.01, glideFrom: top * 0.45, glideTime: 0.14,
                  vibrato: (0.1, 16))
            start(.fm, top * 2, peak: 0.06, decay: 0.12, at: Int(0.05 * sampleRate), pan: pan, fm: (2.5, 1.5, 0.05))
            start(.noise, 0, peak: 0.05, decay: 0.1, at: 0, pan: pan, filter: .bandPass(700, q: 1.5, sr: sampleRate))
        case .pour:
            // Played every ~0.1 s while held: overlapping washes of filtered noise make one running stream,
            // and a random glug or droplet now and then makes it sound like real liquid.
            let s = min(max(e.a, 0), 1)
            let wob = noise()
            start(.noise, 0, peak: 0.08 + 0.07 * s, decay: 0.3, at: 0, pan: pan, attack: 0.05,
                  filter: .bandPass(480 + 220 * s + 160 * wob, q: 1.2, sr: sampleRate))
            start(.noise, 0, peak: 0.035, decay: 0.16, at: 0, pan: pan, attack: 0.03,
                  filter: .bandPass(1800 + 500 * wob, q: 2.5, sr: sampleRate))
            if noise() > 0.1 {
                let f = 240 + 200 * (noise() + 1) * 0.5 + 140 * s
                start(.sine, f, peak: 0.11, decay: 0.09, at: Int((noise() + 1) * 0.04 * sampleRate), pan: pan,
                      attack: 0.004, glideFrom: f * 0.5, glideTime: 0.05)
            }
        case .note:
            let i = min(max(Int((e.a * Float(Self.noteScale.count - 1)).rounded()), 0), Self.noteScale.count - 1)
            let f = Self.hz(Self.noteScale[i])
            switch Int(e.c.rounded()) {
            case 1:   // pluck
                start(.triangle, f, peak: 0.13, decay: 0.22, at: 0, pan: pan, attack: 0.001, cutoff: 2600)
                start(.triangle, f * 2, peak: 0.03, decay: 0.1, at: 0, pan: pan, attack: 0.001, cutoff: 3500)
            case 2:   // marimba
                start(.sine, f * 0.5, peak: 0.17, decay: 0.3, at: 0, pan: pan, attack: 0.001)
                start(.noise, 0, peak: 0.04, decay: 0.02, at: 0, pan: pan,
                      filter: .bandPass(1800, q: 2, sr: sampleRate))
            case 3:   // xylophone
                start(.sine, f, peak: 0.12, decay: 0.3, at: 0, pan: pan, attack: 0.001)
                start(.fm, f * 2, peak: 0.05, decay: 0.14, at: 0, pan: pan, fm: (3.5, 1.6, 0.05))
            default:  // bell
                start(.sine, f, peak: 0.11, decay: 0.6, at: 0, pan: pan, attack: 0.001)
                start(.fm, f * 2, peak: 0.05, decay: 0.3, at: 0, pan: pan, fm: (3.5, 1.6, 0.08))
            }
        case .poof:
            start(.noise, 0, peak: 0.22, decay: 0.22, at: 0, pan: pan, attack: 0.01,
                  filter: .bandPass(1200, q: 0.6, sr: sampleRate))
            start(.sine, 220, peak: 0.12, decay: 0.12, at: 0, pan: pan, glideFrom: 420, glideTime: 0.05)
            start(.fm, Self.hz(88), peak: 0.05, decay: 0.3, at: Int(0.04 * sampleRate), pan: pan, fm: (3.5, 1.2, 0.1))
        }
    }

    // MARK: Render

    /// Renders `frames` frames of the whole mix (queued effects, the tune and the beat clock) without a
    /// sound device: for tests and tools.
    func renderOffline(frames: Int) -> (left: [Float], right: [Float]) {
        let left = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer {
            left.deallocate()
            right.deallocate()
        }
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        let bytes = UInt32(frames * MemoryLayout<Float>.size)
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: left)
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: right)
        render(frameCount: frames, bufferList: list.unsafeMutablePointer)
        return (Array(UnsafeBufferPointer(start: left, count: frames)),
                Array(UnsafeBufferPointer(start: right, count: frames)))
    }

    private func render(frameCount: Int, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return }

        if os_unfair_lock_trylock(lock) {
            for i in 0..<queueCount { playEffect(queue[i]) }
            queueCount = 0
            os_unfair_lock_unlock(lock)
        }
        let block = Float(frameCount) / sampleRate
        energy += (Float(shared[1]) - energy) * (1 - exp(-block / 1.2))
        // shared[2] only switches the background music; the effects always play.
        let musicOn = shared[2] > 0.5
        let masterTarget: Float = 1

        // Sequencer: trigger every 16th note sample-accurately.
        for n in 0..<frameCount {
            stepClock += 1
            if stepClock >= samplesPerStep {
                stepClock -= samplesPerStep
                if musicOn { playStep(at: n) }   // the beat clock keeps running while the music is off
                step += 1
                totalSteps += 1
                if step == 16 {
                    step = 0
                    bar += 1
                }
            }
        }
        shared[0] = (totalSteps - 1 + stepClock / samplesPerStep) / 4

        for n in 0..<frameCount {
            left[n] = 0
            right[n] = 0
        }

        let inverseRate = 1 / sampleRate
        for i in 0..<Self.voiceCount where voices[i].active {
            var v = voices[i]
            var first = 0
            if v.delay >= frameCount {
                v.delay -= frameCount
                voices[i] = v
                continue
            } else if v.delay > 0 {
                first = v.delay
                v.delay = 0
            }
            for n in first..<frameCount {
                if v.glideRate > 0 { v.frequency += (v.glideTarget - v.frequency) * v.glideRate }
                var f = v.frequency
                if v.vibratoDepth > 0 {
                    v.vibratoPhase += v.vibratoRate
                    if v.vibratoPhase >= 1 { v.vibratoPhase -= 1 }
                    f *= 1 + v.vibratoDepth * sine(v.vibratoPhase)
                }
                let dt = f * inverseRate
                var s: Float
                switch v.wave {
                case .sine:
                    s = sine(v.phase)
                case .triangle:
                    s = 4 * abs(v.phase - 0.5) - 1
                case .square:
                    var q: Float = v.phase < 0.5 ? 1 : -1
                    q += Self.polyBLEP(v.phase, dt)
                    var shifted = v.phase + 0.5
                    if shifted >= 1 { shifted -= 1 }
                    q -= Self.polyBLEP(shifted, dt)
                    s = q * 0.6
                case .fm:
                    s = sine(v.phase + v.modIndex * 0.159 * sine(v.modPhase))
                    v.modPhase += f * v.modRatio * inverseRate
                    if v.modPhase >= 1 { v.modPhase -= 1 }
                    v.modIndex *= v.modDecay
                case .noise:
                    s = noise()
                }
                v.phase += dt
                if v.phase >= 1 { v.phase -= 1 }
                if v.useFilter { s = v.filter.process(s) }
                if v.lowpass < 1 {
                    v.lowState += (s - v.lowState) * v.lowpass
                    s = v.lowState
                }
                if v.attacking {
                    v.amplitude += v.attackStep
                    if v.amplitude >= v.peak {
                        v.amplitude = v.peak
                        v.attacking = false
                    }
                } else {
                    v.amplitude *= v.decay
                }
                let out = s * v.amplitude
                left[n] += out * v.left
                right[n] += out * v.right
            }
            if !v.attacking && v.amplitude < 0.0003 { v.active = false }
            voices[i] = v
        }

        let masterStep = 1 - exp(-1 / (0.1 * sampleRate))
        for n in 0..<frameCount {
            master += (masterTarget - master) * masterStep
            left[n] = tanh(left[n] * 0.9) * master
            right[n] = tanh(right[n] * 0.9) * master
        }
        if buffers.count > 2 {
            for b in 2..<buffers.count {
                if let data = buffers[b].mData { memset(data, 0, Int(buffers[b].mDataByteSize)) }
            }
        }
    }
}

/// Owns the audio graph: groove synth → small room reverb → speakers.
final class GrooveEngine {
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var dsp: GrooveDSP?
    private var muted = false
    private var tune = Tune.groove
    private var lastRestart: Double = 0

    func start() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        if dsp == nil {
            let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
            let sampleRate = hardwareRate > 0 ? hardwareRate : 48_000
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }
            let dsp = GrooveDSP(sampleRate: Float(sampleRate))
            dsp.setMuted(muted)
            dsp.setTune(tune)
            let source = AVAudioSourceNode(format: format, renderBlock: dsp.makeRenderBlock())
            reverb.loadFactoryPreset(.mediumRoom)
            reverb.wetDryMix = 14
            engine.attach(source)
            engine.attach(reverb)
            engine.connect(source, to: reverb, format: format)
            engine.connect(reverb, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.85
            self.dsp = dsp
        }
        if !engine.isRunning {
            do { try engine.start() } catch { print("Audio engine failed to start: \(error)") }
        }
    }

    func pause() {
        if engine.isRunning { engine.pause() }
    }

    func play(_ kind: Sfx, a: Float = 0, pan: Float = 0) {
        dsp?.play(SfxEvent(kind: kind, a: a, b: pan))
    }

    /// One timelapse note: `pitch` is the place on the pentatonic scale, 0 (low) to 1 (high).
    func playNote(timbre: NoteTimbre, pitch: Float, pan: Float) {
        dsp?.play(SfxEvent(kind: .note, a: pitch, b: pan, c: Float(timbre.rawValue)))
    }

    func setMuted(_ muted: Bool) {
        self.muted = muted
        dsp?.setMuted(muted)
    }

    /// Switches the background tune; sound effects and the beat clock carry on.
    func setTune(_ tune: Tune) {
        self.tune = tune
        dsp?.setTune(tune)
    }

    /// Beats since the music started (fractional). Drives the dance-to-the-beat animations.
    var beat: Double { dsp?.beat ?? 0 }

    func update(energy: Float, now: Double) {
        dsp?.setEnergy(energy)
        if dsp != nil && !engine.isRunning && now - lastRestart > 1 {
            lastRestart = now
            try? engine.start()
        }
    }
}

import Testing
@testable import PuffyPond

struct GardenSoundTests {
    private static let rate: Float = 48_000

    /// Peak of the difference between a render with `kind` queued and one without, over one second.
    private func effectPeak(_ kind: Sfx, repeats: Int = 1) -> (peak: Float, finite: Bool) {
        let plain = GrooveDSP(sampleRate: Self.rate)
        let withEffect = GrooveDSP(sampleRate: Self.rate)
        for _ in 0..<repeats { withEffect.play(SfxEvent(kind: kind, a: 0.5, b: 0)) }
        let a = plain.renderOffline(frames: Int(Self.rate))
        let b = withEffect.renderOffline(frames: Int(Self.rate))
        var peak: Float = 0
        var finite = true
        for i in 0..<a.left.count {
            for (x, y) in [(a.left[i], b.left[i]), (a.right[i], b.right[i])] {
                if !x.isFinite || !y.isFinite { finite = false }
                peak = max(peak, abs(x - y))
            }
        }
        return (peak, finite)
    }

    @Test func everySoundEffectIsAudible() {
        for kind in Sfx.allCases {
            let result = effectPeak(kind)
            #expect(result.finite, "\(kind) is finite")
            #expect(result.peak > 0.002, "\(kind) is audible")
        }
    }

    @Test func repeatedEffectsStayBounded() {
        for kind in [Sfx.bonk, .splorp, .chicken, .slurp, .poof] {
            let result = effectPeak(kind, repeats: 20)
            #expect(result.finite, "\(kind) is finite")
            #expect(result.peak < 1.0, "\(kind) stays under full scale")
        }
    }
}

struct GardenTuneTests {
    private static let rate: Float = 48_000

    private func peak(of audio: (left: [Float], right: [Float])) -> Float {
        var peak: Float = 0
        for i in 0..<audio.left.count {
            let l = audio.left[i], r = audio.right[i]
            guard l.isFinite, r.isFinite else { return .infinity }
            peak = max(peak, abs(l), abs(r))
        }
        return peak
    }

    @Test func gardenTuneUsesTheGardenTempo() {
        #expect(GrooveDSP.bpm == 104)
    }

    @Test func gardenTuneIsAudibleAndBounded() {
        let bars = 8
        let frames = Int(Self.rate * Float(bars * 4) * 60 / Float(GrooveDSP.bpm))
        for energy: Float in [0, 1] {
            let dsp = GrooveDSP(sampleRate: Self.rate)
            dsp.setEnergy(energy)
            let p = peak(of: dsp.renderOffline(frames: frames))
            #expect(p > 0.05 && p < 0.95, "energy \(energy) peak \(p)")
        }
    }

    @Test func beatClockAdvances() {
        let dsp = GrooveDSP(sampleRate: Self.rate)
        _ = dsp.renderOffline(frames: Int(Self.rate * 4))
        #expect(abs(dsp.beat - 4 * GrooveDSP.bpm / 60) < 0.1)
    }

    @Test func sillyTuneStillPlays() {
        let dsp = GrooveDSP(sampleRate: Self.rate)
        dsp.setTune(.silly)
        let p = peak(of: dsp.renderOffline(frames: Int(Self.rate * 6)))
        #expect(p > 0.05 && p < 0.95)
    }
}

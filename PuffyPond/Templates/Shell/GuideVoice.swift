import AVFoundation
import Observation

/// Says the tracing directions aloud in Indonesian.
/// If the app carries a recorded clip for every sentence of a direction (see `tools/voice`), it plays those: a real,
/// natural voice. Otherwise it reads the text with a voice installed on the device (the best Indonesian one unless
/// another was chosen from the menu; pace and tone can be changed). With no Indonesian voice at all it stays quiet:
/// the written direction still shows.
@Observable
final class GuideVoice {
    enum Pace: String, CaseIterable, Identifiable {
        case slow, normal, fast
        var id: String { rawValue }
        var label: String {
            switch self {
            case .slow: return "Pelan"
            case .normal: return "Biasa"
            case .fast: return "Cepat"
            }
        }
        /// Times the system's default speaking rate.
        var rate: Float {
            switch self {
            case .slow: return 0.7
            case .normal: return 0.9
            case .fast: return 1.0
            }
        }
    }

    enum Tone: String, CaseIterable, Identifiable {
        case calm, cheerful
        var id: String { rawValue }
        var label: String { self == .calm ? "Tenang" : "Ceria" }
        var pitch: Float { self == .calm ? 1.0 : 1.2 }
    }

    private static let onKey = "guideVoiceOn"
    private static let voiceKey = "guideVoiceID"
    private static let paceKey = "guideVoicePace"
    private static let toneKey = "guideVoiceTone"

    /// Whether the person left the spoken directions on last time (on the first run).
    static var savedOn: Bool { UserDefaults.standard.object(forKey: onKey) as? Bool ?? true }

    static func save(on: Bool) { UserDefaults.standard.set(on, forKey: onKey) }

    /// Indonesian voices on this device, best quality first.
    static var indonesianVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("id") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }

    // MARK: Recorded clips

    /// File name (without extension) of the clip for one spoken sentence. Must match `tools/voice/make_clips.py`.
    static func clipName(for sentence: String) -> String {
        var slug = ""
        for ch in sentence.lowercased() {
            if ch.isASCII, ch.isLetter || ch.isNumber {
                slug.append(ch)
            } else if slug.last != "-" {
                slug.append("-")
            }
        }
        return "guide-" + slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// The clips found in the app: file name without extension → file.
    private static let clips: [String: URL] = {
        var found: [String: URL] = [:]
        for folder in [nil, "Voice"] as [String?] {
            for ext in ["mp3", "m4a", "wav"] {
                for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: folder) ?? [] {
                    found[url.deletingPathExtension().lastPathComponent] = url
                }
            }
        }
        return found
    }()

    /// True when the app carries recorded guide clips (the voice menu then has nothing to choose).
    static var hasClips: Bool { clips.keys.contains { $0.hasPrefix("guide-") } }

    static func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality.rawValue {
        case 3...: return "Premium"
        case 2: return "Enhanced"
        default: return "Standar"
        }
    }

    /// The voice picked from the menu; nil means "the best one there is".
    var voiceID: String? {
        didSet { UserDefaults.standard.set(voiceID, forKey: Self.voiceKey) }
    }
    var pace: Pace {
        didSet { UserDefaults.standard.set(pace.rawValue, forKey: Self.paceKey) }
    }
    var tone: Tone {
        didSet { UserDefaults.standard.set(tone.rawValue, forKey: Self.toneKey) }
    }
    var isMuted: Bool {
        didSet { if isMuted { stop() } }
    }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var clipPlayer: AVQueuePlayer?

    init(muted: Bool) {
        let defaults = UserDefaults.standard
        isMuted = muted
        voiceID = defaults.string(forKey: Self.voiceKey)
        pace = defaults.string(forKey: Self.paceKey).flatMap { Pace(rawValue: $0) } ?? .normal
        tone = defaults.string(forKey: Self.toneKey).flatMap { Tone(rawValue: $0) } ?? .cheerful
    }

    private var currentVoice: AVSpeechSynthesisVoice? {
        if let voiceID, let chosen = AVSpeechSynthesisVoice(identifier: voiceID) { return chosen }
        return Self.indonesianVoices.first ?? AVSpeechSynthesisVoice(language: "id-ID")
    }

    /// Says `text`, cutting off whatever was still being said. Each sentence gets its own breath, which sounds
    /// less like a robot reading one long line.
    func say(_ text: String) {
        guard !isMuted, !text.isEmpty else { return }
        stop()
        let sentences = Self.sentences(in: text)

        // A recorded voice, when every sentence has its clip.
        let urls = sentences.compactMap { Self.clips[Self.clipName(for: $0)] }
        if urls.count == sentences.count {
            let player = AVQueuePlayer(items: urls.map { AVPlayerItem(url: $0) })
            clipPlayer = player
            player.play()
            return
        }

        guard let voice = currentVoice else { return }
        for (i, sentence) in sentences.enumerated() {
            let utterance = AVSpeechUtterance(string: sentence)
            utterance.voice = voice
            // A little different every time, the way a person never says a line exactly the same way twice:
            // the cheer at the start rises, the end of the line settles down.
            let lift: Float = i == 0 && sentences.count > 1 ? 0.12 : (i == sentences.count - 1 ? -0.03 : 0)
            utterance.pitchMultiplier = max(0.5, min(2, tone.pitch + lift + .random(in: -0.04...0.04)))
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * pace.rate * .random(in: 0.95...1.05)
            utterance.postUtteranceDelay = i < sentences.count - 1 ? 0.14 : 0
            synthesizer.speak(utterance)
        }
    }

    /// A short line to hear what the current choices sound like.
    func sample() { say("Yuk, naik ke atas ya! Hebat, terus ya!") }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        clipPlayer?.pause()
        clipPlayer?.removeAllItems()
        clipPlayer = nil
    }

    static func sentences(in text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if "!?.".contains(ch) {
                out.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { out.append(rest) }
        return out
    }
}

import AVFoundation

/// Reads the tracing directions aloud in Indonesian with the device's own voice (no audio files).
/// If the device has no Indonesian voice it stays quiet: the written hint still shows.
final class GuideVoice {
    private static let defaultsKey = "guideVoiceOn"

    /// Whether the person left the spoken directions on last time (on the first run).
    static var savedOn: Bool { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }

    static func save(on: Bool) { UserDefaults.standard.set(on, forKey: defaultsKey) }

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "id-ID")

    var isMuted: Bool {
        didSet { if isMuted { stop() } }
    }

    init(muted: Bool) { isMuted = muted }

    /// Says `text`, cutting off whatever was still being said.
    func say(_ text: String) {
        guard !isMuted, let voice, !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        // A little slower and brighter than normal: easier for small kids to follow.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.12
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

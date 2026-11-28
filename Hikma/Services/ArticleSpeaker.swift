import AVFoundation
import MediaPlayer
import WebKit

/// Reads an article aloud, one paragraph at a time, highlighting and scrolling to
/// the paragraph being read. Keeps going with the screen locked, with play/pause on the lock screen.
final class ArticleSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum Speed: Int, CaseIterable {
        case slow, normal, fast

        /// AVSpeech rates are not linear; these sound like roughly 0.8×, 1× and 1.25×.
        var rate: Float {
            switch self {
            case .slow: return 0.43
            case .normal: return 0.5
            case .fast: return 0.56
            }
        }

        func label(english: Bool) -> String {
            switch self {
            case .slow: return english ? "Slow" : "بطيء"
            case .normal: return english ? "Normal" : "عادي"
            case .fast: return english ? "Fast" : "سريع"
            }
        }

        var symbol: String {
            switch self {
            case .slow: return "tortoise"
            case .normal: return "figure.walk"
            case .fast: return "hare"
            }
        }

        var next: Speed { Speed(rawValue: (rawValue + 1) % Speed.allCases.count) ?? .normal }
    }

    @Published private(set) var isPlaying = false
    /// True once reading has started (playing or paused) until it stops or reaches the end.
    @Published private(set) var isActive = false
    @Published private(set) var isReady = false
    @Published var speed: Speed {
        didSet {
            UserDefaults.standard.set(speed.rawValue, forKey: "hikma.speechSpeed")
            if isPlaying { speak(from: index) }
        }
    }

    weak var webView: WKWebView?
    private let synthesizer = AVSpeechSynthesizer()
    private let english: Bool
    private let title: String
    private var blocks: [String] = []
    private var index = 0
    private var current: AVSpeechUtterance?

    init(english: Bool, title: String) {
        self.english = english
        self.title = title
        let saved = UserDefaults.standard.object(forKey: "hikma.speechSpeed") as? Int
        speed = saved.flatMap(Speed.init(rawValue:)) ?? .normal
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Setup

    /// Collects the readable paragraphs from the page once it has loaded.
    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.evaluateJavaScript(Self.collectScript) { [weak self] result, _ in
            guard let self, let texts = result as? [String] else { return }
            self.blocks = texts
            self.isReady = !texts.isEmpty
        }
    }

    // MARK: Controls

    func togglePlay() {
        if isPlaying {
            synthesizer.pauseSpeaking(at: .word)
            isPlaying = false
            updateNowPlaying()
        } else if synthesizer.isPaused {
            activateAudio()
            synthesizer.continueSpeaking()
            isPlaying = true
            updateNowPlaying()
        } else {
            startFromScreen()
        }
    }

    func skip(_ step: Int) {
        guard isActive else { return }
        speak(from: min(max(0, index + step), blocks.count - 1))
    }

    func cycleSpeed() { speed = speed.next }

    func stop() {
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isActive = false
        webView?.evaluateJavaScript("hikmaHighlight(-1)")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Starts at the first paragraph visible on screen.
    private func startFromScreen() {
        guard !blocks.isEmpty else { return }
        webView?.evaluateJavaScript("hikmaFirstVisible()") { [weak self] result, _ in
            guard let self else { return }
            let start = (result as? Int) ?? (result as? NSNumber)?.intValue ?? 0
            self.speak(from: min(max(0, start), self.blocks.count - 1))
        }
    }

    private func speak(from i: Int) {
        guard i < blocks.count else { finish(); return }
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
        activateAudio()
        index = i
        let utterance = AVSpeechUtterance(string: blocks[i])
        utterance.voice = Self.bestVoice(english: english)
        utterance.rate = speed.rate
        utterance.postUtteranceDelay = 0.18
        current = utterance
        synthesizer.speak(utterance)
        isPlaying = true
        isActive = true
        webView?.evaluateJavaScript("hikmaHighlight(\(i))")
        updateNowPlaying()
    }

    private func finish() {
        stop()
    }

    // MARK: AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard utterance === self.current else { return }
            self.speak(from: self.index + 1)
        }
    }

    // MARK: Audio session, voice, lock screen

    private func activateAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        configureRemoteCommands()
    }

    private static func bestVoice(english: Bool) -> AVSpeechSynthesisVoice? {
        let prefix = english ? "en" : "ar"
        let preferred = english ? "en-US" : "ar-SA"
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
        let ranked = voices.sorted {
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            return ($0.language == preferred ? 0 : 1) < ($1.language == preferred ? 0 : 1)
        }
        return ranked.first ?? AVSpeechSynthesisVoice(language: preferred)
    }

    private var commandsConfigured = false

    private func configureRemoteCommands() {
        guard !commandsConfigured else { return }
        commandsConfigured = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .commandFailed }
            self.togglePlay(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .commandFailed }
            self.togglePlay(); return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlay(); return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.skip(1); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.skip(-1); return .success }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Hikma",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }

    deinit {
        let center = MPRemoteCommandCenter.shared()
        [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
         center.nextTrackCommand, center.previousTrackCommand].forEach { $0.removeTarget(nil) }
    }

    // MARK: Page scripts

    /// Numbers every readable paragraph (skipping figure drawings and nested duplicates)
    /// and returns their text. Also installs the highlight and first-visible helpers.
    static let collectScript = """
    (function () {
      var sel = '.masthead h1, .masthead .subtitle, article h2, article h3, article h4, article p, article li, article blockquote, article figcaption, article th, article td, .box-title, .analysis-label';
      var all = Array.prototype.slice.call(document.querySelectorAll(sel))
        .filter(function (e) { return !e.closest('svg'); });
      var els = all.filter(function (e) {
        return !all.some(function (o) { return o !== e && e.contains(o); });
      });
      var texts = [];
      var kept = [];
      els.forEach(function (e) {
        var t = (e.innerText || '').replace(/\\s+/g, ' ').trim();
        if (t.length > 1) { e.setAttribute('data-tts', kept.length); kept.push(e); texts.push(t); }
      });
      window.hikmaTTS = kept;
      window.hikmaHighlight = function (i) {
        var old = document.querySelector('.tts-current');
        if (old) old.classList.remove('tts-current');
        if (i < 0 || !window.hikmaTTS[i]) return;
        var el = window.hikmaTTS[i];
        el.classList.add('tts-current');
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      };
      window.hikmaFirstVisible = function () {
        for (var i = 0; i < window.hikmaTTS.length; i++) {
          var r = window.hikmaTTS[i].getBoundingClientRect();
          if (r.bottom > 60) return i;
        }
        return 0;
      };
      return texts;
    })();
    """
}

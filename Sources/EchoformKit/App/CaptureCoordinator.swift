import Foundation
import Observation
import QuartzCore

/// Bridges `AudioCapture` (background queue) and `VisualizerState` (main actor),
/// drives the caption pipeline (transcription and optional translation), and
/// runs the delayed playback loop.
@MainActor
@Observable
public final class CaptureCoordinator {
    public let state: VisualizerState
    /// On-device translator, served by the SwiftUI `translationTask` modifier.
    public let translator = CaptionTranslator()

    private var capture: AudioCapture?
    private var consumeTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private let speech: SpeechCaptioner
    private let pipeline: CaptionPipeline

    public init(state: VisualizerState) {
        self.state = state
        self.speech = SpeechCaptioner(
            locale: Locale(identifier: CaptionLanguage.named(state.sourceLanguage).speechLocale),
            onDeviceOnly: state.onDeviceOnly)
        self.pipeline = CaptionPipeline(state: state, translator: translator)

        speech.onResult = { [weak self] result in
            self?.pipeline.consume(result)
        }
        speech.onStatus = { [weak self] status in
            self?.handleStatus(status)
        }
        translator.onStatus = { [weak self] status in
            self?.state.captionStatus = status
        }
    }

    /// Checks permission and starts capture if it is granted.
    public func begin() async {
        let permission = await ScreenRecordingAccess.check()
        state.permission = permission
        guard permission == .authorized else {
            Log.app.notice("Capture not started: Screen Recording unauthorized")
            return
        }
        await startCapture()
    }

    /// Re-checks permission, used after the user enables it in System Settings.
    public func recheck() async {
        await stop()
        await begin()
    }

    public func openSystemSettings() {
        ScreenRecordingAccess.openSystemSettings()
    }

    /// Toggles the caption layer, starting or stopping recognition.
    public func toggleText() {
        state.toggleText()
        if state.textEnabled {
            pipeline.reset()
            speech.enable()
        } else {
            speech.disable()
        }
    }

    /// Changes the spoken language and rebuilds recognition for it.
    public func setSourceLanguage(_ code: String) {
        guard code != state.sourceLanguage else { return }
        state.sourceLanguage = code
        pipeline.reset()
        reconfigureSpeech()
    }

    /// Switches between on-device-only recognition and allowing Apple's online
    /// recognition for languages without a local model.
    public func setOnDeviceOnly(_ value: Bool) {
        guard value != state.onDeviceOnly else { return }
        state.onDeviceOnly = value
        pipeline.reset()
        reconfigureSpeech()
    }

    private func reconfigureSpeech() {
        speech.reconfigure(
            locale: Locale(identifier: CaptionLanguage.named(state.sourceLanguage).speechLocale),
            onDeviceOnly: state.onDeviceOnly)
    }

    /// Changes the language captions are translated into.
    public func setTargetLanguage(_ code: String) {
        state.targetLanguage = code
    }

    /// Turns translation on or off. Turning it on also shows the caption layer.
    public func setTranslationEnabled(_ on: Bool) {
        state.translationEnabled = on
        pipeline.reset()
        if on, !state.textEnabled {
            toggleText()
        }
    }

    private func handleStatus(_ status: TranscriberStatus) {
        Log.app.info("Transcriber status: \(String(describing: status), privacy: .public)")
        switch status {
        case .idle, .listening:
            state.captionStatus = ""
        case .denied:
            state.captionStatus = "Speech Recognition permission denied"
        case .unavailable:
            let name = CaptionLanguage.named(state.sourceLanguage).name
            state.captionStatus = "On-device \(name) speech is not installed. In the captions panel (L), turn off \"On-device only\" to use Apple's online recognition."
        }
    }

    /// Preview mode: feeds synthetic frames (and, if text is on, synthetic
    /// caption words) so the visuals can be seen without live audio.
    public func beginDemo() {
        consumeTask?.cancel()
        state.permission = .authorized
        state.isCapturing = true
        let demo = DemoSignal()
        let demoWords = ("the lighthouse keeper watched the grey sea fold over itself "
            + "while the gulls turned slow circles in the cold morning air and the "
            + "lamp swung its patient beam across the water").split(separator: " ").map(String.init)
        let start = Date()
        consumeTask = Task { @MainActor [weak self] in
            var wordIndex = 0
            var lastWordAt = -1.0
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(start)
                self.state.apply(demo.frame(at: elapsed))
                if self.state.textEnabled, elapsed - lastWordAt > 0.42 {
                    let word = demoWords[wordIndex % demoWords.count]
                    self.state.addCaptionWords([
                        CaptionSegment(text: word, spokenMediaTime: CACurrentMediaTime())
                    ])
                    wordIndex += 1
                    lastWordAt = elapsed
                }
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        startPlayback()
        Log.app.info("Demo mode running")
    }

    private func startCapture() async {
        guard capture == nil else { return }
        let capture = AudioCapture()
        capture.onStop = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.state.isCapturing = false
                if error != nil { self.state.permission = .denied }
            }
        }
        let speech = self.speech
        capture.onMonoBuffer = { mono, sampleRate in
            speech.append(mono: mono, sampleRate: sampleRate)
        }
        do {
            try await capture.start()
            self.capture = capture
            state.isCapturing = true
            if state.textEnabled { speech.enable() }
            let frames = capture.frames
            consumeTask = Task { @MainActor [weak self] in
                for await frame in frames {
                    self?.state.apply(frame)
                }
            }
            startPlayback()
            Log.app.info("Capture coordinator running")
        } catch {
            Log.app.error("Capture failed to start: \(error.localizedDescription, privacy: .public)")
            state.permission = .denied
        }
    }

    /// Advances the delayed playback head about 60 times a second.
    private func startPlayback() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.state.renderTick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    public func stop() async {
        consumeTask?.cancel()
        consumeTask = nil
        playbackTask?.cancel()
        playbackTask = nil
        speech.disable()
        await capture?.stop()
        capture = nil
        state.isCapturing = false
    }
}

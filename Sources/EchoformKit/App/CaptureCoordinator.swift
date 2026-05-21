import Foundation
import Observation
import QuartzCore

/// Bridges `AudioCapture` (background queue) and `VisualizerState` (main actor),
/// drives the on-device caption layer, and runs the delayed playback loop.
@MainActor
@Observable
public final class CaptureCoordinator {
    public let state: VisualizerState
    private var capture: AudioCapture?
    private var consumeTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private let captioner = SpeechCaptioner()

    public init(state: VisualizerState) {
        self.state = state
        captioner.onSegments = { [weak state] segments in
            state?.addCaptionWords(segments)
        }
        captioner.onStatus = { status in
            Log.app.info("Captioner status: \(String(describing: status), privacy: .public)")
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

    /// Toggles the caption layer, starting or stopping on-device recognition.
    public func toggleText() {
        state.toggleText()
        if state.textEnabled {
            captioner.enable()
        } else {
            captioner.disable()
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
        let captioner = self.captioner
        capture.onMonoBuffer = { mono, sampleRate in
            captioner.append(mono: mono, sampleRate: sampleRate)
        }
        do {
            try await capture.start()
            self.capture = capture
            state.isCapturing = true
            if state.textEnabled { captioner.enable() }
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
        captioner.disable()
        await capture?.stop()
        capture = nil
        state.isCapturing = false
    }
}

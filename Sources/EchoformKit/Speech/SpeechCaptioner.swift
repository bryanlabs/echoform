import Speech
import AVFoundation

/// Apple Speech framework transcriber. Recognition is on-device only, so no
/// audio leaves the machine; if a locale has no on-device model it reports
/// `.unavailable` rather than falling back to a server. Internal state is
/// serialized on a private queue.
public final class SpeechCaptioner: Transcriber, @unchecked Sendable {
    public var onResult: ((TranscriptionResult) -> Void)?
    public var onStatus: ((TranscriberStatus) -> Void)?

    private let queue = DispatchQueue(label: "net.bryanlabs.echoform.speech")
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var running = false

    /// Creates a transcriber for the given speech locale (e.g. `en-US`, `ko-KR`).
    public init(locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    public func enable() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            self.queue.async {
                guard status == .authorized else {
                    self.report(.denied)
                    return
                }
                guard let recognizer = self.recognizer,
                      recognizer.supportsOnDeviceRecognition else {
                    self.report(.unavailable)
                    return
                }
                self.running = true
                self.startTask()
                self.report(.listening)
            }
        }
    }

    public func disable() {
        queue.async {
            self.running = false
            self.task?.cancel()
            self.request?.endAudio()
            self.task = nil
            self.request = nil
            self.report(.idle)
        }
    }

    /// Switches the recognition language, rebuilding the recognizer and
    /// restarting recognition if it is currently running.
    public func updateLocale(_ locale: Locale) {
        queue.async {
            self.recognizer = SFSpeechRecognizer(locale: locale)
            guard self.running else { return }
            guard let recognizer = self.recognizer,
                  recognizer.supportsOnDeviceRecognition else {
                self.report(.unavailable)
                return
            }
            self.report(.listening)
            if self.task != nil {
                // The cancelled task's callback restarts with the new recognizer.
                self.task?.cancel()
            } else {
                self.startTask()
            }
        }
    }

    public func append(mono: [Float], sampleRate: Double) {
        queue.async {
            guard let request = self.request, !mono.isEmpty,
                  let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: sampleRate,
                                             channels: 1, interleaved: false),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                frameCapacity: AVAudioFrameCount(mono.count))
            else { return }
            buffer.frameLength = AVAudioFrameCount(mono.count)
            if let destination = buffer.floatChannelData?[0] {
                mono.withUnsafeBufferPointer { source in
                    if let base = source.baseAddress {
                        destination.update(from: base, count: mono.count)
                    }
                }
            }
            request.append(buffer)
        }
    }

    // MARK: - Private (serialized on `queue`)

    private func startTask() {
        guard running, let recognizer else { return }
        task?.cancel()
        request?.endAudio()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        self.request = request
        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            let text = result?.bestTranscription.formattedString ?? ""
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            self.queue.async {
                let final = isFinal || failed
                if !text.isEmpty || final {
                    self.emit(TranscriptionResult(text: text, isFinal: final))
                }
                if final, self.running {
                    self.task = nil
                    self.request = nil
                    self.startTask()
                }
            }
        }
    }

    private func emit(_ result: TranscriptionResult) {
        DispatchQueue.main.async { [weak self] in self?.onResult?(result) }
    }

    private func report(_ status: TranscriberStatus) {
        DispatchQueue.main.async { [weak self] in self?.onStatus?(status) }
    }
}

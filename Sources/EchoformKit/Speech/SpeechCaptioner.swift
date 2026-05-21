import Speech
import AVFoundation
import QuartzCore

/// On-device speech recognition for the caption layer.
///
/// Audio buffers from the system-audio capture are fed in; recognized words
/// are emitted, stamped with the time they were recognized, so the caption
/// view can apply a configurable delay. Recognition is on-device only, so no
/// audio leaves the machine. Internal state is serialized on a private queue.
public final class SpeechCaptioner: @unchecked Sendable {
    public enum Status: Sendable {
        case idle, denied, unavailable, listening
    }

    /// Called on the main queue with newly stable caption words.
    public var onSegments: (([CaptionSegment]) -> Void)?
    /// Called on the main queue when the captioner's status changes.
    public var onStatus: ((Status) -> Void)?

    private let queue = DispatchQueue(label: "net.bryanlabs.echoform.speech")
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var emitted = 0
    private var running = false

    public init() {}

    /// Requests Speech Recognition authorization and, if granted, starts
    /// on-device recognition.
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

    /// Feeds one mono audio buffer to the recognizer.
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
        self.emitted = 0
        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            let words = result?.bestTranscription.segments.map { $0.substring } ?? []
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            self.queue.async {
                self.consume(words: words, isFinal: isFinal, failed: failed)
            }
        }
    }

    private func consume(words: [String], isFinal: Bool, failed: Bool) {
        let stableCount = isFinal ? words.count : max(0, words.count - 1)
        if stableCount > emitted {
            // The recognizer does not give reliable per-word timestamps for
            // on-device partial results, so words are stamped at the moment
            // they are recognized, spread slightly so a batch surfaces word
            // by word. The caption delay is measured from there.
            var segments: [CaptionSegment] = []
            let stamp = CACurrentMediaTime()
            for i in emitted..<stableCount {
                let text = words[i].trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { continue }
                segments.append(CaptionSegment(
                    text: text,
                    spokenMediaTime: stamp + Double(segments.count) * 0.28))
            }
            emitted = stableCount
            if !segments.isEmpty {
                let payload = segments
                DispatchQueue.main.async { [weak self] in self?.onSegments?(payload) }
            }
        }
        if (failed || isFinal), running {
            task = nil
            request = nil
            startTask()
        }
    }

    private func report(_ status: Status) {
        DispatchQueue.main.async { [weak self] in self?.onStatus?(status) }
    }
}

import ScreenCaptureKit
import CoreMedia
import QuartzCore

public enum CaptureError: Error {
    case noDisplayAvailable
}

/// Captures system audio via ScreenCaptureKit and emits `AnalysisFrame`s.
///
/// A tiny, slow video stream is configured alongside audio so the `SCStream`
/// is well-formed on every macOS version; the video frames are discarded.
public final class AudioCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {

    /// Analysis frames, produced on the capture queue.
    public let frames: AsyncStream<AnalysisFrame>
    private let continuation: AsyncStream<AnalysisFrame>.Continuation

    /// Invoked if the stream stops on its own (e.g. permission revoked).
    public var onStop: ((Error?) -> Void)?

    /// Invoked on the capture queue with each mono buffer, for transcription.
    public var onMonoBuffer: (([Float], Double) -> Void)?

    private let analysisQueue = DispatchQueue(label: "net.bryanlabs.echoform.audio", qos: .userInitiated)
    private let screenQueue = DispatchQueue(label: "net.bryanlabs.echoform.screen", qos: .utility)
    private let analyzer = AudioAnalyzer()
    private var stream: SCStream?
    private var startTime: CFTimeInterval = 0
    private var logCounter = 0

    public override init() {
        var continuation: AsyncStream<AnalysisFrame>.Continuation!
        self.frames = AsyncStream<AnalysisFrame>(bufferingPolicy: .bufferingNewest(4)) {
            continuation = $0
        }
        self.continuation = continuation
        super.init()
    }

    public func start() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayAvailable
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        // Audio is the goal; the video stream is kept tiny and slow.
        config.width = 320
        config.height = 180
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)
        config.queueDepth = 5
        config.showsCursor = false

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: analysisQueue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: screenQueue)

        startTime = CACurrentMediaTime()
        try await stream.startCapture()
        self.stream = stream
        Log.capture.info("Capture started: 48kHz stereo, own audio excluded")
    }

    public func stop() async {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        continuation.finish()
        Log.capture.info("Capture stopped")
    }

    // MARK: SCStreamOutput

    public func stream(_ stream: SCStream,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of type: SCStreamOutputType) {
        guard type == .audio else { return }  // discard the tiny video stream
        guard let mono = SampleBufferConverter.monoSamples(from: sampleBuffer) else { return }

        let timestamp = CACurrentMediaTime() - startTime
        let frame = analyzer.process(mono: mono, timestamp: timestamp)
        continuation.yield(frame)
        onMonoBuffer?(mono, 48_000)

        logCounter += 1
        if logCounter % 12 == 0 {
            Log.capture.info("rms=\(frame.rms) peak=\(frame.peak) frames=\(mono.count)")
        }
    }

    // MARK: SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        Log.capture.error("Stream stopped with error: \(error.localizedDescription, privacy: .public)")
        self.stream = nil
        continuation.finish()
        onStop?(error)
    }
}

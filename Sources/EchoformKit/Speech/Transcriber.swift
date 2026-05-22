import Foundation

/// One transcription update for the current utterance. `text` is the full
/// hypothesis so far; `isFinal` marks the utterance as complete.
public struct TranscriptionResult: Sendable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

/// Lifecycle state of a transcriber.
public enum TranscriberStatus: Sendable {
    case idle
    case listening
    case denied
    case unavailable
}

/// A pluggable speech-to-text engine. Apple's on-device Speech framework is the
/// built-in implementation; other engines (Whisper, Parakeet, cloud services)
/// can conform to this and be selected without touching the caption pipeline.
public protocol Transcriber: AnyObject {
    /// Called on the main queue with each transcription update.
    var onResult: ((TranscriptionResult) -> Void)? { get set }
    /// Called on the main queue when the engine's status changes.
    var onStatus: ((TranscriberStatus) -> Void)? { get set }

    /// Requests permission and begins recognition.
    func enable()
    /// Stops recognition.
    func disable()
    /// Feeds one mono audio buffer to the engine.
    func append(mono: [Float], sampleRate: Double)
}

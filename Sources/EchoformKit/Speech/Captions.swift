import Foundation

/// A recognized word, stamped with when it was spoken on the
/// `CACurrentMediaTime` clock. Produced by `SpeechCaptioner`.
public struct CaptionSegment: Sendable {
    public let text: String
    public let spokenMediaTime: Double

    public init(text: String, spokenMediaTime: Double) {
        self.text = text
        self.spokenMediaTime = spokenMediaTime
    }
}

/// A caption word held in observable state, with a stable identity.
public struct CaptionWord: Identifiable, Sendable {
    public let id: Int
    public let text: String
    public let spokenMediaTime: Double
}

/// The current low-latency caption hypothesis. Unlike `CaptionWord`, this is
/// replaceable because partial speech results can revise their latest words.
public struct LiveCaptionLine: Sendable {
    public let sourceText: String
    public let translatedText: String?
    public let updatedAt: Double
}

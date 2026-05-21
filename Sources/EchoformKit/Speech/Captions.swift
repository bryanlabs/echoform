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

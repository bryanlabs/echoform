import Foundation
import Translation

/// On-device translation of caption text via Apple's Translation framework.
/// A `TranslationSession` is supplied by the SwiftUI `translationTask` modifier
/// and lives as long as the chosen language pair is unchanged.
@MainActor
public final class CaptionTranslator {
    /// Called with the translated text for each submitted phrase.
    public var onTranslated: ((String) -> Void)?
    /// Called with the latest translated low-latency caption hypothesis.
    public var onLiveTranslated: ((String) -> Void)?
    /// Called with a short human-readable status (e.g. while a language pack
    /// downloads, or if the pair is unavailable).
    public var onStatus: ((String) -> Void)?

    private enum RequestKind {
        case append
        case live(Int)
    }

    private struct Request {
        let text: String
        let kind: RequestKind
    }

    private var continuation: AsyncStream<Void>.Continuation?
    private var requests: [Request] = []
    private var liveSequence = 0

    public init() {}

    /// Queues a phrase for translation.
    public func submit(_ text: String) {
        enqueue(Request(text: text, kind: .append), replacingPendingLive: false)
    }

    /// Queues a replaceable low-latency phrase for translation. Pending live
    /// phrases are coalesced so translation does not fall farther behind.
    public func submitLive(_ text: String) {
        liveSequence += 1
        enqueue(Request(text: text, kind: .live(liveSequence)), replacingPendingLive: true)
    }

    /// Drives translation for the lifetime of one language configuration.
    /// Called by the view's `translationTask`, and cancelled when the language
    /// pair changes or translation is turned off.
    public func serve(using session: TranslationSession) async {
        do {
            try await session.prepareTranslation()
            onStatus?("")
        } catch {
            onStatus?("Translation unavailable for this language pair")
            Log.app.error("prepareTranslation failed: \(error.localizedDescription, privacy: .public)")
        }

        let stream = AsyncStream<Void> { continuation in
            self.continuation = continuation
        }
        if !requests.isEmpty { self.continuation?.yield(()) }

        for await _ in stream {
            if Task.isCancelled { break }
            while !requests.isEmpty {
                let request = requests.removeFirst()
                do {
                    let response = try await session.translate(request.text)
                    publish(response.targetText, for: request)
                } catch {
                    // Fall back to the original text so transcription stays visible.
                    publish(request.text, for: request)
                    Log.app.error("Translation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func enqueue(_ request: Request, replacingPendingLive: Bool) {
        if replacingPendingLive {
            requests.removeAll { existing in
                if case .live = existing.kind { return true }
                return false
            }
        }
        requests.append(request)
        if requests.count > 12 { requests.removeFirst(requests.count - 12) }
        continuation?.yield(())
    }

    private func publish(_ text: String, for request: Request) {
        switch request.kind {
        case .append:
            onTranslated?(text)
        case .live(let sequence):
            if sequence == liveSequence {
                onLiveTranslated?(text)
            }
        }
    }
}

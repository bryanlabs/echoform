import Foundation
import Translation

/// On-device translation of caption text via Apple's Translation framework.
/// A `TranslationSession` is supplied by the SwiftUI `translationTask` modifier
/// and lives as long as the chosen language pair is unchanged.
@MainActor
public final class CaptionTranslator {
    /// Called with the translated text for each submitted phrase.
    public var onTranslated: ((String) -> Void)?
    /// Called with a short human-readable status (e.g. while a language pack
    /// downloads, or if the pair is unavailable).
    public var onStatus: ((String) -> Void)?

    private var continuation: AsyncStream<String>.Continuation?
    private var backlog: [String] = []

    public init() {}

    /// Queues a phrase for translation.
    public func submit(_ text: String) {
        if let continuation {
            continuation.yield(text)
        } else {
            backlog.append(text)
            if backlog.count > 8 { backlog.removeFirst() }
        }
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

        let stream = AsyncStream<String> { continuation in
            self.continuation = continuation
        }
        for phrase in backlog { self.continuation?.yield(phrase) }
        backlog.removeAll()

        for await phrase in stream {
            if Task.isCancelled { break }
            do {
                let response = try await session.translate(phrase)
                onTranslated?(response.targetText)
            } catch {
                // Fall back to the original text so transcription stays visible.
                onTranslated?(phrase)
                Log.app.error("Translation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

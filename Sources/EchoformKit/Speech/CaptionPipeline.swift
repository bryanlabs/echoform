import Foundation
import QuartzCore

/// Turns transcription results into caption words on `VisualizerState`. With
/// translation off, stable words are shown incrementally as they are
/// recognized. With translation on, each finished utterance is translated as a
/// whole and the translated words are shown.
@MainActor
public final class CaptionPipeline {
    private let state: VisualizerState
    private let translator: CaptionTranslator

    /// Words of the current utterance already shown (no-translation path).
    private var emittedWords = 0
    private let wordSpread = 0.28

    public init(state: VisualizerState, translator: CaptionTranslator) {
        self.state = state
        self.translator = translator
        translator.onTranslated = { [weak self] english in
            self?.show(english.split(separator: " ").map(String.init))
        }
    }

    /// Handles one transcription update.
    public func consume(_ result: TranscriptionResult) {
        if state.translationEnabled {
            if result.isFinal {
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { translator.submit(text) }
            }
            return
        }

        // No translation: show stable words as they settle.
        let words = result.text.split(separator: " ").map(String.init)
        let stable = result.isFinal ? words.count : max(0, words.count - 1)
        if stable > emittedWords {
            show(Array(words[emittedWords..<stable]))
            emittedWords = stable
        }
        if result.isFinal { emittedWords = 0 }
    }

    /// Resets per-utterance state, e.g. when the engine or language changes.
    public func reset() {
        emittedWords = 0
    }

    private func show(_ words: [String]) {
        let stamp = CACurrentMediaTime()
        var segments: [CaptionSegment] = []
        for word in words {
            let trimmed = word.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            segments.append(CaptionSegment(
                text: trimmed,
                spokenMediaTime: stamp + Double(segments.count) * wordSpread))
        }
        if !segments.isEmpty { state.addCaptionWords(segments) }
    }
}

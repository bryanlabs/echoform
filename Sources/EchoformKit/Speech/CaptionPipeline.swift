import Foundation
import QuartzCore

/// Turns transcription results into caption words on `VisualizerState`. With
/// translation off, stable words are shown incrementally as they are
/// recognized. With translation on, stable text is translated on-device in
/// sentence-sized chunks (continuous speech rarely produces a final result, so
/// the pipeline cannot wait for one).
@MainActor
public final class CaptionPipeline {
    private let state: VisualizerState
    private let translator: CaptionTranslator

    /// Words of the current utterance already shown (no-translation path).
    private var shownWords = 0
    /// Words of the current utterance already sent to translate.
    private var translatedWords = 0
    private let wordSpread = 0.28
    /// Translate after this many stable words even without sentence punctuation.
    private let chunkWords = 9

    public init(state: VisualizerState, translator: CaptionTranslator) {
        self.state = state
        self.translator = translator
        translator.onTranslated = { [weak self] text in
            self?.show(text.split(separator: " ").map(String.init))
        }
    }

    /// Handles one transcription update.
    public func consume(_ result: TranscriptionResult) {
        let words = result.text.split(separator: " ").map(String.init)
        let stable = result.isFinal ? words.count : max(0, words.count - 1)

        if state.translationEnabled {
            translateStable(words, stable: stable, isFinal: result.isFinal)
        } else {
            if stable < shownWords { shownWords = 0 }
            if stable > shownWords {
                show(Array(words[shownWords..<stable]))
                shownWords = stable
            }
            if result.isFinal { shownWords = 0 }
        }
    }

    /// Resets per-utterance state, e.g. when the engine or language changes.
    public func reset() {
        shownWords = 0
        translatedWords = 0
    }

    /// Translation path: submit completed sentences, or long-enough chunks, of
    /// the stable text as it grows, without waiting for the recognizer to
    /// finalize the utterance.
    private func translateStable(_ words: [String], stable: Int, isFinal: Bool) {
        if stable < translatedWords { translatedWords = 0 }
        guard stable > translatedWords else {
            if isFinal { translatedWords = 0 }
            return
        }
        let pending = Array(words[translatedWords..<stable])
        if isFinal {
            submitForTranslation(pending)
            translatedWords = 0
        } else if let cut = lastSentenceEnd(in: pending) {
            submitForTranslation(Array(pending[0...cut]))
            translatedWords += cut + 1
        } else if pending.count >= chunkWords {
            submitForTranslation(pending)
            translatedWords = stable
        }
    }

    private func submitForTranslation(_ words: [String]) {
        let phrase = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }
        translator.submit(phrase)
    }

    private func lastSentenceEnd(in words: [String]) -> Int? {
        for index in stride(from: words.count - 1, through: 0, by: -1) {
            if let last = words[index].last, ".?!…。！？".contains(last) {
                return index
            }
        }
        return nil
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

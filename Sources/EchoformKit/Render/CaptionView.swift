import SwiftUI
import QuartzCore

/// The delayed caption layer. A word becomes visible once the playback head
/// reaches the audio it belongs to, so at a high enough `captionDelay` the
/// words line up with the (also delayed) bars. A calm, low-contrast block in
/// the lower area of the window.
public struct CaptionView: View {
    @Environment(VisualizerState.self) private var state
    let date: Date

    public init(date: Date) { self.date = date }

    private let visibleDuration = 13.0
    private let recentWindow = 22
    private let liveVisibleDuration = 4.0

    public var body: some View {
        let now = CACurrentMediaTime()
        if state.lowLatencyCaptions,
           let live = state.liveCaption,
           now - live.updatedAt < liveVisibleDuration {
            return AnyView(liveCaption(live))
        }

        let due = state.captionWords.filter { word in
            let shown = shownFor(word, now: now)
            return shown >= 0 && shown < visibleDuration
        }
        let recent = Array(due.suffix(recentWindow))

        return AnyView(VStack {
            Spacer(minLength: 0)
            if !recent.isEmpty {
                captionText(for: recent, now: now)
                    .font(.system(size: 19, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 15))
                    .padding(.bottom, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false))
    }

    private func liveCaption(_ live: LiveCaptionLine) -> some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                if state.translationEnabled,
                   let translated = live.translatedText,
                   !translated.isEmpty {
                    Text(trimmedLiveText(translated, maxWords: 22))
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }

                Text(trimmedLiveText(live.sourceText, maxWords: state.translationEnabled ? 18 : 24))
                    .font(.system(size: state.translationEnabled ? 14 : 20,
                                  weight: .regular,
                                  design: .rounded))
                    .foregroundStyle(.white.opacity(state.translationEnabled ? 0.5 : 0.92))
            }
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 660)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 15))
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// Seconds the word has been visible. This can make recognized words feel
    /// earlier or later relative to the delayed visual playback, but it cannot
    /// display a word before the recognizer emits it.
    private func shownFor(_ word: CaptionWord, now: Double) -> Double {
        let dueTime = word.spokenMediaTime
            - VisualizerState.recognitionLatency
            + state.captionDelay
        return now - dueTime
    }

    private func captionText(for words: [CaptionWord], now: Double) -> Text {
        var text = Text("")
        for (index, word) in words.enumerated() {
            let opacity = wordOpacity(shownFor: shownFor(word, now: now),
                                      indexFromEnd: words.count - 1 - index)
            text = text + Text(word.text + " ").foregroundStyle(.white.opacity(opacity))
        }
        return text
    }

    private func wordOpacity(shownFor: Double, indexFromEnd: Int) -> Double {
        let fadeIn = min(1, shownFor / 0.4)
        let fadeOut = min(1, max(0, (visibleDuration - shownFor) / 3.5))
        let recency = max(0.55, 1.0 - Double(indexFromEnd) * 0.035)
        return max(0, min(0.95, fadeIn * fadeOut * recency))
    }

    private func trimmedLiveText(_ text: String, maxWords: Int) -> String {
        let words = text.split(separator: " ")
        guard words.count > maxWords else { return text }
        return words.suffix(maxWords).joined(separator: " ")
    }
}

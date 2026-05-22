import Foundation
import SwiftUI

/// A small, low-contrast status bar that appears on mouse movement and fades.
public struct ControlOverlay: View {
    @Environment(VisualizerState.self) private var state

    public init() {}

    public var body: some View {
        HStack(spacing: 13) {
            label(state.mode.title, emphasis: true)
            divider
            label(state.isPaused ? "paused" : "playing")
            divider
            label("right-click controls")

            if state.textEnabled {
                divider
                label(captionSummary, emphasis: true)
                if abs(state.captionDelay) > 0.001 {
                    label("sync \(offsetLabel(state.captionDelay))")
                }
            } else {
                label("captions off")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }

    private func label(_ text: String, emphasis: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11, weight: emphasis ? .semibold : .medium,
                          design: .rounded))
            .foregroundStyle(.white.opacity(emphasis ? 0.78 : 0.5))
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 11)
    }

    private var captionSummary: String {
        let source = CaptionLanguage.named(state.sourceLanguage).name
        guard state.translationEnabled else { return "\(source) captions" }
        let target = CaptionLanguage.named(state.targetLanguage).name
        return "\(source) to \(target)"
    }

    private func offsetLabel(_ seconds: Double) -> String {
        let sign = seconds > 0 ? "+" : ""
        if abs(seconds.rounded() - seconds) < 0.001 {
            return "\(sign)\(Int(seconds))s"
        }
        return "\(sign)\(String(format: "%.2f", seconds))s"
    }
}

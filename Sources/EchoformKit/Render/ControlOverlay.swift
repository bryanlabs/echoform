import SwiftUI

/// A small, low-contrast hint bar that appears on mouse movement and fades.
public struct ControlOverlay: View {
    @Environment(VisualizerState.self) private var state

    public init() {}

    public var body: some View {
        HStack(spacing: 13) {
            label(state.mode.title, emphasis: true)
            divider
            label(state.isPaused ? "paused" : "playing")
            divider
            label("1-6 modes")
            label("space pause")
            label("F full screen")
            label("[ ] intensity")
            label("B brightness")
            label("\u{2190}\u{2192} theme")
            label("C colors")
            divider
            if state.textEnabled {
                label("delay \(Int(state.captionDelay))s", emphasis: true)
                label(", . adjust")
            } else {
                label("T captions")
            }
            label("L language")
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
}

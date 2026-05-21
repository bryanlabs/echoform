import SwiftUI

/// Hosts the active visual mode in a 60 fps `TimelineView`, the caption layer,
/// the theme panel, and the fade-in control hints.
public struct VisualizerView: View {
    @Environment(VisualizerState.self) private var state
    @State private var controlsVisible = false
    @State private var hideTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        ZStack {
            TimelineView(.animation(paused: state.isPaused)) { timeline in
                ZStack {
                    state.palette.backgroundColor.ignoresSafeArea()
                    modeView(date: timeline.date)
                    if state.textEnabled {
                        CaptionView(date: timeline.date)
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active = phase { revealControls() }
            }

            if controlsVisible {
                VStack {
                    Spacer()
                    ControlOverlay().padding(.bottom, 26)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if state.showThemePanel {
                ThemePanel()
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: controlsVisible)
        .animation(.easeInOut(duration: 0.22), value: state.showThemePanel)
    }

    @ViewBuilder
    private func modeView(date: Date) -> some View {
        switch state.mode {
        case .bars: BarsView(date: date)
        case .wave: WaveRibbonView(date: date)
        case .heat: HeatFieldView(date: date)
        case .pulse: PulseFieldView(date: date)
        case .flow: FlowFieldView(date: date)
        case .combined: CombinedView(date: date)
        }
    }

    private func revealControls() {
        controlsVisible = true
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { controlsVisible = false }
        }
    }
}

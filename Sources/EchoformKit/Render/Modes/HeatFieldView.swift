import SwiftUI

/// A slow-scrolling spectrogram: frequency on the vertical axis, time on the
/// horizontal axis, energy as color.
public struct HeatFieldView: View {
    @Environment(VisualizerState.self) private var state
    let date: Date

    public init(date: Date) { self.date = date }

    public var body: some View {
        Group {
            if let image = HeatFieldRenderer.image(columns: state.heatColumns,
                                                   palette: state.palette,
                                                   intensity: state.intensity) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                state.palette.backgroundColor
            }
        }
    }
}

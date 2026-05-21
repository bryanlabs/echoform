import SwiftUI
import Foundation

/// Loudness / frequency bars, mirrored around the vertical center for a calm,
/// symmetric look. Driven by `VisualizerState.bars`.
public struct BarsView: View {
    @Environment(VisualizerState.self) private var state
    let date: Date

    public init(date: Date) { self.date = date }

    public var body: some View {
        Canvas { context, size in
            let bars = state.bars
            guard !bars.isEmpty else { return }
            let palette = state.palette
            let intensity = state.intensity
            let count = bars.count
            let gap: CGFloat = 3
            let barWidth = max(1, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            let maxHeight = size.height * 0.74
            let center = size.height * 0.5

            for i in 0..<count {
                let raw = Double(bars[i])
                let energy = min(1, pow(raw, 0.55) * 2.4 * intensity)
                let height = max(2, CGFloat(energy) * maxHeight)
                let x = CGFloat(i) * (barWidth + gap)
                let rect = CGRect(x: x, y: center - height / 2,
                                  width: barWidth, height: height)
                let color = palette.energyColor(energy, opacity: 0.35 + 0.6 * energy)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(barWidth, height) * 0.4),
                    with: .color(color)
                )
            }
        }
    }
}

import SwiftUI

/// A smooth horizontal waveform ribbon, drawn with a soft glow.
public struct WaveRibbonView: View {
    @Environment(VisualizerState.self) private var state
    let date: Date

    public init(date: Date) { self.date = date }

    public var body: some View {
        Canvas { context, size in
            let waveform = state.latestFrame.waveform
            guard waveform.count > 1 else { return }
            let intensity = state.intensity
            let amplitude = size.height * 0.30 * intensity
            let center = size.height * 0.5
            let step = size.width / CGFloat(waveform.count - 1)

            var path = Path()
            for (i, sample) in waveform.enumerated() {
                let clamped = max(-1.5, min(1.5, CGFloat(sample)))
                let point = CGPoint(x: CGFloat(i) * step, y: center - clamped * amplitude)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }

            let energy = min(1, Double(state.level) * 6)
            let color = state.palette.energyColor(max(0.12, energy))
            context.stroke(path, with: .color(color.opacity(0.16)), lineWidth: 11)
            context.stroke(path, with: .color(color.opacity(0.5)), lineWidth: 4)
            context.stroke(path, with: .color(color.opacity(0.95)), lineWidth: 1.6)
        }
    }
}

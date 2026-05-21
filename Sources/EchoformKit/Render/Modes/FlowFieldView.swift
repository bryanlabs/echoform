import SwiftUI
import Foundation

/// A slowly flowing vector field, drawn as oriented strokes. The flow direction
/// is a smooth function of position and time, modulated by mids and treble, so
/// it is fully deterministic from the audio stream.
public struct FlowFieldView: View {
    @Environment(VisualizerState.self) private var state
    let date: Date

    public init(date: Date) { self.date = date }

    public var body: some View {
        Canvas { context, size in
            let palette = state.palette
            let time = date.timeIntervalSinceReferenceDate
            let columns = 30
            let rows = 18
            let cellWidth = Double(size.width) / Double(columns)
            let cellHeight = Double(size.height) / Double(rows)
            let mid = Double(state.mid)
            let treble = Double(state.treble)
            let level = Double(state.level)
            let intensity = state.intensity
            let reach = min(cellWidth, cellHeight) * (0.60 + 1.0 * level * intensity)

            for row in 0..<rows {
                for column in 0..<columns {
                    let nx = Double(column) / Double(columns)
                    let ny = Double(row) / Double(rows)
                    let angle = sin(nx * 3.1 + time * 0.34) * 1.4
                              + cos(ny * 2.7 - time * 0.27) * 1.2
                              + mid * 2.2
                    let cx = (Double(column) + 0.5) * cellWidth
                    let cy = (Double(row) + 0.5) * cellHeight
                    let half = reach * (0.4 + 0.6 * treble) * 0.5
                    let dx = cos(angle) * half
                    let dy = sin(angle) * half

                    var path = Path()
                    path.move(to: CGPoint(x: CGFloat(cx - dx), y: CGFloat(cy - dy)))
                    path.addLine(to: CGPoint(x: CGFloat(cx + dx), y: CGFloat(cy + dy)))

                    let energy = min(1, 0.40 + level * 2.0 + treble * 0.5)
                    let color = palette.energyColor(energy * (0.55 + 0.45 * ny),
                                                    opacity: 0.40 + 0.45 * level)
                    context.stroke(path, with: .color(color), lineWidth: 2.4)
                }
            }
        }
    }
}

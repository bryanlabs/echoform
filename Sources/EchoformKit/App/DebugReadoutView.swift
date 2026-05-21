import SwiftUI

/// Phase 1 placeholder: a live numeric readout proving capture works.
/// Phase 2 replaces this with the real visualizer.
public struct DebugReadoutView: View {
    @Environment(VisualizerState.self) private var state

    public init() {}

    public var body: some View {
        let frame = state.latestFrame
        return VStack(spacing: 24) {
            Text("Echoform — capturing")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.white.opacity(0.6))

            meter(label: "RMS", value: frame.rms, scale: 4)
            meter(label: "PEAK", value: frame.peak, scale: 1)

            Text(state.isCapturing ? "system audio live" : "waiting for audio")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(40)
    }

    private func meter(label: String, value: Float, scale: Float) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(String(format: "%.4f", Double(value)))
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundStyle(.white.opacity(0.5))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.08))
                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, value * scale))))
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(width: 360)
    }
}

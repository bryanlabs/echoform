import SwiftUI
import AppKit

/// The theme customization panel, toggled with the `C` key. Offers preset
/// themes and a custom theme built from three color wells (each opens the
/// macOS color picker with its RGB sliders).
public struct ThemePanel: View {
    @Environment(VisualizerState.self) private var state

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Theme")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 10) {
                ForEach(Theme.presets) { preset in
                    swatch(for: preset)
                }
            }

            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)

            VStack(alignment: .leading, spacing: 9) {
                Text("Custom colors")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                colorRow("Quiet", index: 0)
                colorRow("Mid", index: 1)
                colorRow("Loud", index: 2)
            }

            Text("C to close")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(20)
        .frame(width: 280)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
    }

    private func swatch(for preset: Theme) -> some View {
        let active = state.theme.id == preset.id
        return Button {
            state.selectTheme(preset)
        } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(colors: preset.stops.map(color(_:)),
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 52, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(.white.opacity(active ? 0.9 : 0.12),
                                          lineWidth: active ? 2 : 1)
                    )
                Text(preset.name)
                    .font(.system(size: 9, weight: active ? .semibold : .regular,
                                  design: .rounded))
                    .foregroundStyle(.white.opacity(active ? 0.85 : 0.45))
            }
        }
        .buttonStyle(.plain)
    }

    private func colorRow(_ label: String, index: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            ColorPicker("", selection: stopBinding(index), supportsOpacity: false)
                .labelsHidden()
        }
    }

    private func color(_ component: ThemeColor) -> Color {
        Color(.sRGB, red: component.red, green: component.green, blue: component.blue)
    }

    private func stopBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard state.customStops.indices.contains(index) else { return .white }
                return color(state.customStops[index])
            },
            set: { newColor in
                guard state.customStops.indices.contains(index) else { return }
                let resolved = NSColor(newColor).usingColorSpace(.sRGB)
                state.customStops[index] = ThemeColor(
                    Double(resolved?.redComponent ?? 1),
                    Double(resolved?.greenComponent ?? 1),
                    Double(resolved?.blueComponent ?? 1))
                state.applyCustomTheme()
            }
        )
    }
}

import Foundation
import SwiftUI

/// Right-click control surface for the visualizer. Keyboard shortcuts still
/// work, but normal adjustments should be reachable from this menu.
public struct VisualizerContextMenu: View {
    @Environment(VisualizerState.self) private var state
    @Environment(CaptureCoordinator.self) private var coordinator

    public init() {}

    public var body: some View {
        Button(state.isPaused ? "Resume" : "Pause") {
            state.togglePause()
        }

        Button("Toggle Full Screen") {
            WindowControl.shared.toggleFullScreen()
        }

        Divider()

        Menu("Visual Mode") {
            ForEach(VisualMode.allCases, id: \.self) { mode in
                Button {
                    state.select(mode)
                } label: {
                    selectedLabel(mode.title, selected: state.mode == mode)
                }
            }
        }

        Menu("Theme") {
            ForEach(Theme.presets) { theme in
                Button {
                    state.selectTheme(theme)
                } label: {
                    selectedLabel(theme.name, selected: state.theme.id == theme.id)
                }
            }
            Divider()
            Button("Custom Colors...") {
                if !state.showThemePanel {
                    state.toggleThemePanel()
                }
            }
        }

        Menu("Brightness") {
            brightnessButton("Dim", level: 0)
            brightnessButton("Normal", level: 1)
            brightnessButton("Bright", level: 2)
        }

        Menu("Intensity") {
            intensityButton("30%", value: 0.3)
            intensityButton("50%", value: 0.5)
            intensityButton("75%", value: 0.75)
            intensityButton("100%", value: 1.0)
            intensityButton("125%", value: 1.25)
            intensityButton("150%", value: 1.5)
            intensityButton("180%", value: 1.8)
        }

        Divider()

        Toggle("Captions", isOn: captionsBinding)

        Toggle("Low Latency Captions", isOn: lowLatencyBinding)

        Menu("Spoken Language") {
            languageButtons(selection: state.sourceLanguage) { code in
                coordinator.setSourceLanguage(code)
            }
        }

        Toggle("Translate", isOn: translationBinding)

        if state.translationEnabled {
            Menu("Translate To") {
                languageButtons(selection: state.targetLanguage) { code in
                    coordinator.setTargetLanguage(code)
                }
            }
        }

        Toggle("On-device Only", isOn: onDeviceBinding)

        Menu("Caption Sync Offset") {
            ForEach(captionOffsets, id: \.self) { seconds in
                Button {
                    state.setCaptionDelay(seconds)
                } label: {
                    selectedLabel(offsetLabel(seconds),
                                  selected: abs(state.captionDelay - seconds) < 0.001)
                }
            }
        }
    }

    private var captionsBinding: Binding<Bool> {
        Binding(
            get: { state.textEnabled },
            set: { enabled in
                if enabled != state.textEnabled {
                    coordinator.toggleText()
                }
            }
        )
    }

    private var translationBinding: Binding<Bool> {
        Binding(
            get: { state.translationEnabled },
            set: { coordinator.setTranslationEnabled($0) }
        )
    }

    private var onDeviceBinding: Binding<Bool> {
        Binding(
            get: { state.onDeviceOnly },
            set: { coordinator.setOnDeviceOnly($0) }
        )
    }

    private var lowLatencyBinding: Binding<Bool> {
        Binding(
            get: { state.lowLatencyCaptions },
            set: { coordinator.setLowLatencyCaptions($0) }
        )
    }

    @ViewBuilder
    private func languageButtons(selection: String,
                                 onSelect: @escaping (String) -> Void) -> some View {
        ForEach(CaptionLanguage.all) { language in
            Button {
                onSelect(language.id)
            } label: {
                selectedLabel(language.name, selected: language.id == selection)
            }
        }
    }

    private func brightnessButton(_ title: String, level: Int) -> some View {
        Button {
            state.setBrightnessLevel(level)
        } label: {
            selectedLabel(title, selected: state.brightnessLevel == level)
        }
    }

    private func intensityButton(_ title: String, value: Double) -> some View {
        Button {
            state.setIntensity(value)
        } label: {
            selectedLabel(title, selected: abs(state.intensity - value) < 0.01)
        }
    }

    @ViewBuilder
    private func selectedLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private var captionOffsets: [Double] {
        [-2, -1.5, -1, -0.75, -0.5, -0.33, -0.25, 0, 0.25, 0.33,
         0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 6, 8, 10]
    }

    private func offsetLabel(_ seconds: Double) -> String {
        if abs(seconds) < 0.001 { return "0s" }
        let sign = seconds > 0 ? "+" : ""
        if abs(seconds.rounded() - seconds) < 0.001 {
            return "\(sign)\(Int(seconds))s"
        }
        return "\(sign)\(String(format: "%.2f", seconds))s"
    }
}

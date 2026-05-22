import SwiftUI

/// The captions and translation panel. Chooses the spoken language for
/// transcription and an optional on-device translation target.
public struct CaptionPanel: View {
    @Environment(VisualizerState.self) private var state
    @Environment(CaptureCoordinator.self) private var coordinator

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Captions")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            row("Spoken language") {
                languageMenu(selection: state.sourceLanguage) { code in
                    coordinator.setSourceLanguage(code)
                }
            }

            Toggle(isOn: onDeviceBinding) {
                Text("On-device Only")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .toggleStyle(.switch)
            .tint(.white.opacity(0.45))

            Toggle(isOn: translationBinding) {
                Text("Translate")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .toggleStyle(.switch)
            .tint(.white.opacity(0.45))

            if state.translationEnabled {
                row("Into") {
                    languageMenu(selection: state.targetLanguage) { code in
                        coordinator.setTargetLanguage(code)
                    }
                }
            }

            if !state.captionStatus.isEmpty {
                Text(state.captionStatus)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Right-click for all controls")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(20)
        .frame(width: 264)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
    }

    private var onDeviceBinding: Binding<Bool> {
        Binding(
            get: { state.onDeviceOnly },
            set: { coordinator.setOnDeviceOnly($0) }
        )
    }

    private var translationBinding: Binding<Bool> {
        Binding(
            get: { state.translationEnabled },
            set: { coordinator.setTranslationEnabled($0) }
        )
    }

    private func row<Content: View>(_ label: String,
                                    @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            content()
        }
    }

    private func languageMenu(selection: String,
                              onSelect: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(CaptionLanguage.all) { language in
                Button {
                    onSelect(language.id)
                } label: {
                    if language.id == selection {
                        Label(language.name, systemImage: "checkmark")
                    } else {
                        Text(language.name)
                    }
                }
            }
        } label: {
            Text(CaptionLanguage.named(selection).name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

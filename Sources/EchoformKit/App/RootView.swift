import SwiftUI

/// Root view of the Echoform window. Routes between the permission screen and
/// the live visualizer. Keyboard handling lives in `KeyboardControl`.
public struct RootView: View {
    @Environment(VisualizerState.self) private var state

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    @ViewBuilder
    private var content: some View {
        switch state.permission {
        case .authorized:
            VisualizerView()
        case .denied:
            PermissionView()
        case .unknown:
            ProgressView()
                .controlSize(.large)
                .tint(.white.opacity(0.4))
        }
    }
}

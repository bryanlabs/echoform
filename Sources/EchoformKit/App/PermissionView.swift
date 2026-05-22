import SwiftUI

/// Shown when system audio recording permission has not been granted.
public struct PermissionView: View {
    @Environment(CaptureCoordinator.self) private var coordinator

    public init() {}

    public var body: some View {
        VStack(spacing: 18) {
            Text("Echoform needs System Audio access")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(0.85))

            Text("Echoform uses macOS system audio recording to hear what is "
               + "already playing. It never records your screen, microphone, "
               + "or files, and nothing is saved.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button("Open System Settings") { coordinator.openSystemSettings() }
                Button("Re-check") { Task { await coordinator.recheck() } }
            }
            .controlSize(.large)

            Text("After enabling Echoform under System Audio Recording Only, quit and reopen the app.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(40)
    }
}

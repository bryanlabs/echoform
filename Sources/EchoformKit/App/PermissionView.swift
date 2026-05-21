import SwiftUI

/// Shown when Screen Recording permission has not been granted.
public struct PermissionView: View {
    @Environment(CaptureCoordinator.self) private var coordinator

    public init() {}

    public var body: some View {
        VStack(spacing: 18) {
            Text("Echoform needs Screen Recording access")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(0.85))

            Text("macOS routes system audio through the Screen Recording "
               + "permission. Echoform captures audio only, never video, and "
               + "nothing is recorded or saved.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button("Open System Settings") { coordinator.openSystemSettings() }
                Button("Re-check") { Task { await coordinator.recheck() } }
            }
            .controlSize(.large)

            Text("After enabling Echoform in the list, quit and reopen the app.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(40)
    }
}

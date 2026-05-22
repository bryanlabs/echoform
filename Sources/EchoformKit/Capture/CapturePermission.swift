import AppKit

/// Whether the app currently has macOS system audio recording authorization.
public enum CapturePermission: Sendable, Equatable {
    case unknown
    case authorized
    case denied
}

/// Helpers for recovering system audio recording authorization.
public enum SystemAudioAccess {
    /// Opens the Screen & System Audio Recording pane of System Settings.
    @MainActor
    public static func openSystemSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}

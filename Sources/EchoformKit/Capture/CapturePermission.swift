import ScreenCaptureKit
import AppKit

/// Whether the app currently has macOS Screen Recording authorization.
/// ScreenCaptureKit requires this permission even for audio-only capture.
public enum CapturePermission: Sendable, Equatable {
    case unknown
    case authorized
    case denied
}

/// Helpers for checking and recovering Screen Recording authorization.
public enum ScreenRecordingAccess {
    /// Probes authorization by attempting to enumerate shareable content.
    ///
    /// The first call also triggers the system prompt and registers Echoform
    /// in the Screen Recording list in System Settings.
    public static func check() async -> CapturePermission {
        do {
            _ = try await SCShareableContent.current
            return .authorized
        } catch {
            Log.capture.notice("Screen Recording not authorized: \(error.localizedDescription, privacy: .public)")
            return .denied
        }
    }

    /// Opens the Screen Recording pane of System Settings.
    @MainActor
    public static func openSystemSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}

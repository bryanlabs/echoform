import AppKit

/// Window-level actions plus reliable full-screen tracking.
///
/// `NSWindow.styleMask` is not a dependable full-screen signal, so the state
/// is tracked from the enter / exit notifications instead.
@MainActor
final class WindowControl {
    static let shared = WindowControl()

    private var isFullScreen = false

    private init() {
        let center = NotificationCenter.default
        center.addObserver(forName: NSWindow.didEnterFullScreenNotification,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isFullScreen = true }
        }
        center.addObserver(forName: NSWindow.didExitFullScreenNotification,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isFullScreen = false }
        }
    }

    private var primaryWindow: NSWindow? {
        NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first { $0.isVisible && !$0.isSheet }
    }

    func toggleFullScreen() {
        primaryWindow?.toggleFullScreen(nil)
    }

    func leaveFullScreen() {
        guard isFullScreen else { return }
        primaryWindow?.toggleFullScreen(nil)
    }
}

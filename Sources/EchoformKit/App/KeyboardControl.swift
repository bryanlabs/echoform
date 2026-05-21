import AppKit

/// App-level keyboard handling via a local `NSEvent` monitor.
///
/// This is more robust than view-level `onKeyPress`, which depends on focus
/// and stops working across the full-screen transition.
@MainActor
public final class KeyboardControl {
    private let state: VisualizerState
    private let coordinator: CaptureCoordinator
    private var monitor: Any?

    public init(state: VisualizerState, coordinator: CaptureCoordinator) {
        self.state = state
        self.coordinator = coordinator
    }

    public func start() {
        guard monitor == nil else { return }
        _ = WindowControl.shared  // register full-screen observers early
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Returning nil swallows the event; returning it passes it on.
            return self.handle(event) ? nil : event
        }
    }

    public func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        // Leave Cmd combinations (Cmd+Q and friends) to the system.
        if event.modifierFlags.contains(.command) { return false }

        switch event.keyCode {
        case 53: // Escape
            WindowControl.shared.leaveFullScreen()
            return true
        case 49: // Space
            state.togglePause()
            return true
        case 123: // Left arrow
            state.cycleTheme(forward: false)
            return true
        case 124: // Right arrow
            state.cycleTheme(forward: true)
            return true
        default:
            break
        }

        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }
        switch characters {
        case "1": state.select(.bars)
        case "2": state.select(.wave)
        case "3": state.select(.heat)
        case "4": state.select(.pulse)
        case "5": state.select(.flow)
        case "6": state.select(.combined)
        case "f": WindowControl.shared.toggleFullScreen()
        case "b": state.cycleBrightness()
        case "t": coordinator.toggleText()
        case "c": state.toggleThemePanel()
        case "[": state.adjustIntensity(-0.12)
        case "]": state.adjustIntensity(0.12)
        case ",": state.adjustCaptionDelay(-1)
        case ".": state.adjustCaptionDelay(1)
        default: return false
        }
        return true
    }
}

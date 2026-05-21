import Foundation

/// Owns the long-lived objects for one app session.
@MainActor
public final class AppModel {
    public let state: VisualizerState
    public let coordinator: CaptureCoordinator
    public let keyboard: KeyboardControl

    public init() {
        let state = VisualizerState()
        self.state = state
        let coordinator = CaptureCoordinator(state: state)
        self.coordinator = coordinator
        self.keyboard = KeyboardControl(state: state, coordinator: coordinator)
    }
}

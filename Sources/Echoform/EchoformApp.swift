import SwiftUI
import EchoformKit

@main
struct EchoformApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        Window("Echoform", id: "main") {
            RootView()
                .environment(app.state)
                .environment(app.coordinator)
                .task {
                    app.keyboard.start()
                    if Self.isDemoMode {
                        app.coordinator.beginDemo()
                    } else {
                        await app.coordinator.begin()
                    }
                    if ProcessInfo.processInfo.arguments.contains("--text") {
                        app.coordinator.toggleText()
                    }
                }
        }
        .defaultSize(width: 1000, height: 640)
        .windowStyle(.hiddenTitleBar)
    }

    /// Demo mode previews the visuals without live audio. Enabled with the
    /// `--demo` launch argument or the `ECHOFORM_DEMO` environment variable.
    private static var isDemoMode: Bool {
        let info = ProcessInfo.processInfo
        return info.arguments.contains("--demo") || info.environment["ECHOFORM_DEMO"] == "1"
    }
}

import OSLog

/// Centralized `os.Logger` categories for Echoform.
///
/// The subsystem is the bundle identifier, so live logs can be streamed with:
///
///     log stream --predicate 'subsystem == "net.bryanlabs.echoform"'
///
/// This is how capture is verified without needing the UI on screen.
public enum Log {
    private static let subsystem = "net.bryanlabs.echoform"

    public static let capture = Logger(subsystem: subsystem, category: "capture")
    public static let analysis = Logger(subsystem: subsystem, category: "analysis")
    public static let render = Logger(subsystem: subsystem, category: "render")
    public static let app = Logger(subsystem: subsystem, category: "app")
}

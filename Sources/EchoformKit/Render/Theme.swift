import Foundation

/// An RGB color with 0...1 components. The building block of a theme.
public struct ThemeColor: Sendable, Equatable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// A color theme: the energy ramp the visuals interpolate across, from quiet
/// (the first stop) through mid to loud (the last stop).
public struct Theme: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var stops: [ThemeColor]

    public init(id: String, name: String, stops: [ThemeColor]) {
        self.id = id
        self.name = name
        self.stops = stops
    }
}

extension Theme {
    /// The default calm theme: deep indigo, teal, soft gold.
    public static let classic = Theme(
        id: "classic", name: "Classic",
        stops: [ThemeColor(0.20, 0.18, 0.42),
                ThemeColor(0.16, 0.52, 0.55),
                ThemeColor(0.92, 0.62, 0.32)])

    /// Pink and purple in place of the orange: deep purple, violet, neon pink.
    public static let cyberpunk = Theme(
        id: "cyberpunk", name: "Cyberpunk",
        stops: [ThemeColor(0.20, 0.09, 0.45),
                ThemeColor(0.58, 0.16, 0.78),
                ThemeColor(0.98, 0.26, 0.66)])

    /// Cool greens: deep blue, teal, mint.
    public static let aurora = Theme(
        id: "aurora", name: "Aurora",
        stops: [ThemeColor(0.10, 0.20, 0.40),
                ThemeColor(0.14, 0.56, 0.52),
                ThemeColor(0.52, 0.93, 0.66)])

    /// Warm reds: deep maroon, ember red, amber.
    public static let ember = Theme(
        id: "ember", name: "Ember",
        stops: [ThemeColor(0.24, 0.10, 0.16),
                ThemeColor(0.74, 0.22, 0.16),
                ThemeColor(0.98, 0.78, 0.34)])

    /// The preset themes, in cycle order.
    public static let presets: [Theme] = [.classic, .cyberpunk, .aurora, .ember]

    /// Identifier used for the user's custom theme.
    public static let customID = "custom"
}

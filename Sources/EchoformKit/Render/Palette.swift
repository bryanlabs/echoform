import SwiftUI

/// Resolves a `Theme` plus a brightness level into the colors the visuals
/// draw with. The energy ramp is the theme's stops; brightness scales overall
/// luminance, cycled with the `B` key.
public struct Palette: Sendable {
    public var theme: Theme = .classic
    public var brightnessLevel: Int = 1

    private static let luminanceLevels: [Double] = [0.5, 0.74, 1.0]

    public init() {}

    public var luminance: Double {
        let index = min(max(brightnessLevel, 0), Palette.luminanceLevels.count - 1)
        return Palette.luminanceLevels[index]
    }

    public var backgroundColor: Color { .black }

    /// Raw color components for an energy value (0...1) along the theme ramp.
    public func energyRGB(_ energy: Double) -> (r: Double, g: Double, b: Double) {
        let e = min(max(energy, 0), 1)
        let stops = theme.stops.count >= 2 ? theme.stops : Theme.classic.stops
        let scaled = e * Double(stops.count - 1)
        let lower = min(Int(scaled), stops.count - 1)
        let upper = min(lower + 1, stops.count - 1)
        let t = scaled - Double(lower)
        let a = stops[lower]
        let b = stops[upper]
        let lum = luminance
        return ((a.red + (b.red - a.red) * t) * lum,
                (a.green + (b.green - a.green) * t) * lum,
                (a.blue + (b.blue - a.blue) * t) * lum)
    }

    /// SwiftUI color for an energy value (0...1).
    public func energyColor(_ energy: Double, opacity: Double = 1) -> Color {
        let c = energyRGB(energy)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: opacity)
    }
}

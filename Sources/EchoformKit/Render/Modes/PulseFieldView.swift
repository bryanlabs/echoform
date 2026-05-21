import SwiftUI
import Foundation

/// Large breathing shapes: a soft central glow and concentric rings driven by
/// loudness and bass.
public struct PulseFieldView: View {
    @Environment(VisualizerState.self) private var state
    let date: Date

    public init(date: Date) { self.date = date }

    public var body: some View {
        Canvas { context, size in
            let palette = state.palette
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let time = date.timeIntervalSinceReferenceDate
            let level = Double(state.level)
            let bass = Double(state.bass)
            let pulse = Double(state.pulse)
            let intensity = state.intensity
            let maxRadius = Double(min(size.width, size.height)) * 0.46

            let breath = 0.5 + 0.5 * sin(time * 0.7)
            let coreEnergy = min(1, (0.34 + level * 3 + bass * 0.6) * intensity)
            let coreRadius = maxRadius * (0.16 + 0.30 * breath + 0.42 * coreEnergy)
            let coreColor = palette.energyColor(coreEnergy)

            let glow = Gradient(colors: [coreColor.opacity(0.92), coreColor.opacity(0)])
            let coreRect = CGRect(x: center.x - CGFloat(coreRadius),
                                  y: center.y - CGFloat(coreRadius),
                                  width: CGFloat(coreRadius) * 2,
                                  height: CGFloat(coreRadius) * 2)
            context.fill(
                Path(ellipseIn: coreRect),
                with: .radialGradient(glow, center: center,
                                      startRadius: 0, endRadius: CGFloat(coreRadius))
            )

            for ring in 0..<4 {
                let phase = Double(ring) * 0.9
                let ringBreath = 0.5 + 0.5 * sin(time * 0.6 + phase)
                let radius = maxRadius * (0.30 + 0.16 * Double(ring)
                                          + 0.16 * ringBreath + 0.36 * coreEnergy)
                let energy = min(1, coreEnergy * (1 - 0.15 * Double(ring)))
                let color = palette.energyColor(energy, opacity: 0.18 + 0.24 * ringBreath)
                let rect = CGRect(x: center.x - CGFloat(radius),
                                  y: center.y - CGFloat(radius),
                                  width: CGFloat(radius) * 2,
                                  height: CGFloat(radius) * 2)
                context.stroke(Path(ellipseIn: rect),
                               with: .color(color),
                               lineWidth: CGFloat(2 + 3 * pulse))
            }
        }
    }
}

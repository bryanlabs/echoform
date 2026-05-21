import SwiftUI

/// The ambient combined view: a dim spectral heat background, a soft pulse
/// glow, and the bars in front.
public struct CombinedView: View {
    let date: Date

    public init(date: Date) { self.date = date }

    public var body: some View {
        ZStack {
            HeatFieldView(date: date).opacity(0.38)
            PulseFieldView(date: date).opacity(0.55)
            BarsView(date: date)
        }
    }
}

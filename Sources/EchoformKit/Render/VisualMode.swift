/// The visual modes Echoform can display. Raw values map to the 1-6 keys.
public enum VisualMode: Int, CaseIterable, Sendable {
    case bars = 1
    case wave = 2
    case heat = 3
    case pulse = 4
    case flow = 5
    case combined = 6

    public var title: String {
        switch self {
        case .bars: return "Bars"
        case .wave: return "Wave Ribbon"
        case .heat: return "Spectral Heat"
        case .pulse: return "Pulse Field"
        case .flow: return "Flow Field"
        case .combined: return "Combined"
        }
    }
}

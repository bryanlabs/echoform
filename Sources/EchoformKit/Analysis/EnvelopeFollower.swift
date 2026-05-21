/// A one-pole attack/release smoother.
///
/// Rises quickly toward louder input and falls slowly, which gives the
/// visuals an organic feel instead of a jittery one.
public struct EnvelopeFollower {
    public private(set) var value: Float = 0
    public var attack: Float
    public var release: Float

    /// - Parameters:
    ///   - attack: rise coefficient per update (0...1, higher is faster).
    ///   - release: fall coefficient per update (0...1, lower is slower).
    public init(attack: Float = 0.3, release: Float = 0.08) {
        self.attack = attack
        self.release = release
    }

    @discardableResult
    public mutating func update(_ target: Float) -> Float {
        let coefficient = target > value ? attack : release
        value += (target - value) * coefficient
        return value
    }

    public mutating func reset() { value = 0 }
}

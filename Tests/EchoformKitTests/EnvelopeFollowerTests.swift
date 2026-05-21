import Testing
@testable import EchoformKit

@Suite("EnvelopeFollower")
struct EnvelopeFollowerTests {
    @Test("rises toward the target and stays within bounds")
    func rises() {
        var env = EnvelopeFollower(attack: 0.5, release: 0.1)
        var value: Float = 0
        for _ in 0..<60 { value = env.update(1.0) }
        #expect(value > 0.9)
        #expect(value <= 1.0)
    }

    @Test("attack moves faster than release")
    func attackFasterThanRelease() {
        var attacking = EnvelopeFollower(attack: 0.5, release: 0.05)
        let attackStep = attacking.update(1.0)

        var releasing = EnvelopeFollower(attack: 0.5, release: 0.05)
        for _ in 0..<80 { releasing.update(1.0) }
        let before = releasing.value
        let after = releasing.update(0.0)
        let releaseStep = before - after

        #expect(attackStep > releaseStep)
    }

    @Test("settles at the target value")
    func settles() {
        var env = EnvelopeFollower(attack: 0.4, release: 0.4)
        var value: Float = 0
        for _ in 0..<300 { value = env.update(0.5) }
        #expect(abs(value - 0.5) < 0.001)
    }
}

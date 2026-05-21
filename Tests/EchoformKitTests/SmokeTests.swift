import Testing
@testable import EchoformKit

@Suite("Smoke")
struct SmokeTests {
    @Test("EchoformKit builds and is importable")
    func builds() {
        #expect(1 + 1 == 2)
    }
}

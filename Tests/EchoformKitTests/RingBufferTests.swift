import Testing
@testable import EchoformKit

@Suite("RingBuffer")
struct RingBufferTests {
    @Test("latest returns the most recent samples in order")
    func latestOrder() {
        var ring = RingBuffer(capacity: 8)
        ring.append([1, 2, 3, 4])
        #expect(ring.latest(4) == [1, 2, 3, 4])
        #expect(ring.count == 4)
    }

    @Test("wraps around capacity, keeping the newest samples")
    func wraps() {
        var ring = RingBuffer(capacity: 4)
        ring.append([1, 2, 3, 4, 5, 6])
        #expect(ring.latest(4) == [3, 4, 5, 6])
        #expect(ring.count == 4)
    }

    @Test("latest clamps the request to capacity")
    func clamps() {
        var ring = RingBuffer(capacity: 4)
        ring.append([7, 8])
        #expect(ring.latest(100).count == 4)
        #expect(ring.count == 2)
    }
}

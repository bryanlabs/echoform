/// A fixed-capacity ring buffer of `Float` samples.
///
/// Incoming audio buffers vary in size; the ring lets the analyzer pull
/// fixed-length windows for FFT and waveform regardless of buffer size.
public struct RingBuffer {
    public let capacity: Int
    private var storage: [Float]
    private var writeIndex = 0
    /// How many samples have been written, capped at `capacity`.
    public private(set) var count = 0

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = [Float](repeating: 0, count: self.capacity)
    }

    public mutating func append(_ samples: [Float]) {
        for sample in samples {
            storage[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
        }
        count = min(count + samples.count, capacity)
    }

    /// The most recent `n` samples in chronological order (oldest first).
    /// Clamped to `capacity`; unfilled slots read as zero.
    public func latest(_ n: Int) -> [Float] {
        let wanted = min(max(0, n), capacity)
        guard wanted > 0 else { return [] }
        var output = [Float](repeating: 0, count: wanted)
        var index = (writeIndex - wanted + capacity) % capacity
        for i in 0..<wanted {
            output[i] = storage[index]
            index = (index + 1) % capacity
        }
        return output
    }
}

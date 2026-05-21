import Testing
import Foundation
@testable import EchoformKit

@Suite("FFTProcessor")
struct FFTProcessorTests {
    @Test("a pure tone peaks in the expected frequency bin")
    func tonePeak() {
        let size = 1_024
        let sampleRate = 48_000.0
        let frequency = 3_000.0
        let fft = FFTProcessor(size: size)

        let samples = (0..<size).map { i in
            Float(sin(2 * Double.pi * frequency * Double(i) / sampleRate))
        }
        let magnitudes = fft.magnitudes(samples)
        #expect(magnitudes.count == size / 2)

        var peakBin = 0
        var peakValue: Float = 0
        for (bin, value) in magnitudes.enumerated() where value > peakValue {
            peakValue = value
            peakBin = bin
        }
        let expectedBin = Int(frequency / sampleRate * Double(size))
        #expect(abs(peakBin - expectedBin) <= 2)
    }

    @Test("silence produces a near-zero spectrum")
    func silentSpectrum() {
        let fft = FFTProcessor(size: 1_024)
        let magnitudes = fft.magnitudes([Float](repeating: 0, count: 1_024))
        #expect(magnitudes.reduce(0, +) < 0.001)
    }
}

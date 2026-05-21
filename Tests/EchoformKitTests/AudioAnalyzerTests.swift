import Testing
import Foundation
@testable import EchoformKit

@Suite("AudioAnalyzer")
struct AudioAnalyzerTests {

    private func sine(frequency: Double, amplitude: Float, count: Int,
                      sampleRate: Double = 48_000) -> [Float] {
        (0..<count).map { i in
            amplitude * Float(sin(2 * Double.pi * frequency * Double(i) / sampleRate))
        }
    }

    @Test("RMS of a sine wave is amplitude / sqrt(2)")
    func rmsOfSine() {
        let analyzer = AudioAnalyzer()
        let buffer = sine(frequency: 440, amplitude: 0.5, count: 4_800)
        let frame = analyzer.process(mono: buffer, timestamp: 0)
        let expected = Float(0.5 / 2.0.squareRoot())
        #expect(abs(frame.rms - expected) < 0.01)
    }

    @Test("peak tracks the largest magnitude")
    func peakOfSine() {
        let analyzer = AudioAnalyzer()
        let buffer = sine(frequency: 200, amplitude: 0.8, count: 4_800)
        let frame = analyzer.process(mono: buffer, timestamp: 0)
        #expect(abs(frame.peak - 0.8) < 0.02)
    }

    @Test("silence reads as silent, a loud signal does not")
    func silenceDetection() {
        let silent = AudioAnalyzer().process(
            mono: [Float](repeating: 0, count: 2_048), timestamp: 0)
        #expect(silent.silence == 1)
        #expect(silent.rms < 0.0001)

        let loud = AudioAnalyzer().process(
            mono: sine(frequency: 300, amplitude: 0.9, count: 2_048), timestamp: 0)
        #expect(loud.silence == 0)
    }

    @Test("an empty buffer produces a zeroed frame")
    func emptyBuffer() {
        let frame = AudioAnalyzer().process(mono: [], timestamp: 1.5)
        #expect(frame.rms == 0)
        #expect(frame.timestamp == 1.5)
    }
}

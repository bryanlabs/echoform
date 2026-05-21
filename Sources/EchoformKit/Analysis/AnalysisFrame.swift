import Foundation

/// One frame of audio analysis.
///
/// A `Sendable` value type so it can be produced on the capture queue and
/// consumed on the main actor without sharing mutable state.
public struct AnalysisFrame: Sendable {
    /// Overall loudness, root-mean-square of the buffer (0...~1).
    public var rms: Float = 0
    /// Largest sample magnitude in the buffer (0...~1).
    public var peak: Float = 0
    /// Log-spaced magnitude bands for the bar visualizer.
    public var bands: [Float] = []
    /// Low-frequency energy (0...1).
    public var bass: Float = 0
    /// Mid / voice-band energy (0...1).
    public var mid: Float = 0
    /// High-frequency / sibilance energy (0...1).
    public var treble: Float = 0
    /// Spectral centroid, a brightness measure (0...1).
    public var centroid: Float = 0
    /// Zero-crossing rate of the buffer (0...1).
    public var zeroCrossingRate: Float = 0
    /// 1 when near-silent, 0 when loud.
    public var silence: Float = 1
    /// Recent mono samples, oldest first, for the waveform ribbon.
    public var waveform: [Float] = []
    /// Sample rate the analysis ran at.
    public var sampleRate: Double = 48_000
    /// Seconds since capture started.
    public var timestamp: Double = 0

    public init() {}
}

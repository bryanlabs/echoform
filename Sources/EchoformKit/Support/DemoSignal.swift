import Foundation

/// Generates synthetic `AnalysisFrame`s for previewing the visuals without
/// live audio. Enabled with the `ECHOFORM_DEMO` environment variable.
///
/// The signal is deterministic from its time argument, in keeping with
/// Echoform's "deterministic from the stream" design principle.
public struct DemoSignal {
    private let bandCount: Int

    public init(bandCount: Int = 56) {
        self.bandCount = bandCount
    }

    /// A synthetic analysis frame for time `t`, in seconds.
    public func frame(at t: Double) -> AnalysisFrame {
        var frame = AnalysisFrame()
        frame.timestamp = t

        // Slow breathing loudness with occasional swells.
        let breath = 0.5 + 0.5 * sin(t * 0.9)
        let swell = pow(max(0, sin(t * 0.37)), 3)
        let loud = Float(0.12 + 0.16 * breath + 0.22 * swell)
        frame.rms = loud
        frame.peak = min(1, loud * Float(1.7 + 0.6 * sin(t * 5.1)))
        frame.silence = loud < 0.05 ? 1 : 0

        // Bands: travelling humps plus gentle texture, tilted toward the lows.
        var bands = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            let x = Double(i) / Double(max(1, bandCount - 1))
            let hump1 = exp(-pow((x - (0.5 + 0.35 * sin(t * 0.7))) / 0.16, 2))
            let hump2 = exp(-pow((x - (0.3 + 0.25 * sin(t * 1.3 + 1))) / 0.1, 2))
            let texture = 0.12 * (0.5 + 0.5 * sin(t * 3 + x * 22))
            let lowTilt = 1.0 - 0.4 * x
            let value = (0.7 * hump1 + 0.5 * hump2 + texture) * lowTilt
            bands[i] = Float(max(0, value)) * loud * 2.4
        }
        frame.bands = bands

        frame.bass = Float(min(1, 0.6 * breath + 0.4 * swell))
        frame.mid = Float(0.5 + 0.4 * sin(t * 1.1))
        frame.treble = Float(0.35 + 0.3 * abs(sin(t * 2.3)))
        frame.centroid = Float(0.45 + 0.25 * sin(t * 0.6))
        frame.zeroCrossingRate = frame.treble

        // Waveform: a mixed tone so the wave ribbon has shape.
        let count = 1_024
        var wave = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let p = Double(i) / Double(count)
            let sample = sin(p * 38 + t * 7) * 0.6 + sin(p * 9 + t * 2) * 0.4
            wave[i] = Float(sample) * loud * 1.6
        }
        frame.waveform = wave

        return frame
    }
}

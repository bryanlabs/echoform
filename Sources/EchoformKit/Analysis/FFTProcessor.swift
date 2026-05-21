import Accelerate

/// A real-to-complex FFT using Accelerate's vDSP.
///
/// Applies a Hann window and returns the magnitude spectrum. Used only on the
/// audio analysis queue, so it holds reusable buffers without locking.
final class FFTProcessor {
    let size: Int
    private let halfSize: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private var window: [Float]
    private var windowed: [Float]
    private var realParts: [Float]
    private var imagParts: [Float]

    init(size: Int = 1_024) {
        self.size = size
        self.halfSize = size / 2
        self.log2n = vDSP_Length(log2(Double(size)).rounded())
        self.setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: size)
        self.windowed = [Float](repeating: 0, count: size)
        self.realParts = [Float](repeating: 0, count: size / 2)
        self.imagParts = [Float](repeating: 0, count: size / 2)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }

    /// Magnitude spectrum (`size / 2` bins) of the given samples.
    func magnitudes(_ samples: [Float]) -> [Float] {
        guard samples.count >= size else { return [] }

        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(size))

        var magnitudes = [Float](repeating: 0, count: halfSize)
        realParts.withUnsafeMutableBufferPointer { realBuffer in
            imagParts.withUnsafeMutableBufferPointer { imagBuffer in
                var split = DSPSplitComplex(realp: realBuffer.baseAddress!,
                                            imagp: imagBuffer.baseAddress!)
                windowed.withUnsafeBufferPointer { input in
                    input.baseAddress!.withMemoryRebound(to: DSPComplex.self,
                                                         capacity: halfSize) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        var scale = Float(1.0 / Float(size))
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfSize))
        return magnitudes
    }
}

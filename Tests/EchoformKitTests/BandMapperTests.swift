import Testing
@testable import EchoformKit

@Suite("BandMapper")
struct BandMapperTests {
    @Test("produces the requested number of bands")
    func bandCountMatches() {
        let mapper = BandMapper(bandCount: 48, fftSize: 1_024, sampleRate: 48_000)
        let magnitudes = [Float](repeating: 0.1, count: 512)
        #expect(mapper.bands(from: magnitudes).count == 48)
    }

    @Test("a treble-heavy spectrum reads brighter than bass")
    func trebleVersusBass() {
        let mapper = BandMapper(bandCount: 56, fftSize: 1_024, sampleRate: 48_000)
        var magnitudes = [Float](repeating: 0, count: 512)
        for bin in 300..<340 { magnitudes[bin] = 1.0 }
        let summary = mapper.summary(from: magnitudes)
        #expect(summary.treble > summary.bass)
        #expect(mapper.centroid(from: magnitudes) > 0.5)
    }

    @Test("a bass-heavy spectrum has a low centroid")
    func bassCentroid() {
        let mapper = BandMapper(bandCount: 56, fftSize: 1_024, sampleRate: 48_000)
        var magnitudes = [Float](repeating: 0, count: 512)
        for bin in 2..<12 { magnitudes[bin] = 1.0 }
        #expect(mapper.centroid(from: magnitudes) < 0.2)
    }
}

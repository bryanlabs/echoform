import CoreMedia
import AVFoundation

/// Converts a ScreenCaptureKit audio `CMSampleBuffer` into a mono `[Float]`.
///
/// ScreenCaptureKit delivers 32-bit float linear PCM. This handles both
/// interleaved and non-interleaved layouts and downmixes to mono.
enum SampleBufferConverter {

    static func monoSamples(from sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard sampleBuffer.isValid,
              let asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription,
              asbd.mFormatID == kAudioFormatLinearPCM,
              (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0,
              asbd.mBitsPerChannel == 32
        else {
            return nil
        }

        let channels = Int(asbd.mChannelsPerFrame)
        guard channels > 0 else { return nil }
        let nonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

        var result: [Float]?
        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, _ in
                if nonInterleaved {
                    result = downmixNonInterleaved(audioBufferList)
                } else {
                    result = downmixInterleaved(audioBufferList, channels: channels)
                }
            }
        } catch {
            return nil
        }
        return result
    }

    /// Each `AudioBuffer` holds one channel; sum them and average.
    private static func downmixNonInterleaved(
        _ list: UnsafeMutableAudioBufferListPointer
    ) -> [Float]? {
        guard let first = list.first, first.mData != nil else { return nil }
        let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size
        guard frames > 0 else { return nil }

        var mono = [Float](repeating: 0, count: frames)
        var used = 0
        for buffer in list {
            guard let data = buffer.mData else { continue }
            let pointer = data.assumingMemoryBound(to: Float.self)
            let count = min(frames, Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
            for i in 0..<count { mono[i] += pointer[i] }
            used += 1
        }
        if used > 1 {
            let scale = 1.0 / Float(used)
            for i in 0..<mono.count { mono[i] *= scale }
        }
        return mono
    }

    /// A single `AudioBuffer` holds interleaved channels; average per frame.
    private static func downmixInterleaved(
        _ list: UnsafeMutableAudioBufferListPointer,
        channels: Int
    ) -> [Float]? {
        guard let buffer = list.first, let data = buffer.mData else { return nil }
        let totalFloats = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let frames = totalFloats / channels
        guard frames > 0 else { return nil }

        let pointer = data.assumingMemoryBound(to: Float.self)
        var mono = [Float](repeating: 0, count: frames)
        if channels == 1 {
            for i in 0..<frames { mono[i] = pointer[i] }
        } else {
            let scale = 1.0 / Float(channels)
            for i in 0..<frames {
                var sum: Float = 0
                for c in 0..<channels { sum += pointer[i * channels + c] }
                mono[i] = sum * scale
            }
        }
        return mono
    }
}

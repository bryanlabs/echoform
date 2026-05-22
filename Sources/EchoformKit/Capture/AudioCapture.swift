import CoreAudio
import QuartzCore

public enum CaptureError: Error {
    case coreAudioFailure(String, OSStatus)
    case invalidTapFormat
}

extension CaptureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .coreAudioFailure(operation, status):
            return "\(operation) failed with OSStatus \(status)"
        case .invalidTapFormat:
            return "Core Audio tap did not provide 32-bit linear PCM"
        }
    }
}

/// Captures system audio via a Core Audio process tap and emits `AnalysisFrame`s.
public final class AudioCapture: @unchecked Sendable {

    /// Analysis frames, produced by the Core Audio IO callback.
    public let frames: AsyncStream<AnalysisFrame>
    private let continuation: AsyncStream<AnalysisFrame>.Continuation

    /// Invoked if the stream stops on its own (e.g. permission revoked).
    public var onStop: ((Error?) -> Void)?

    /// Invoked on the capture queue with each mono buffer, for transcription.
    public var onMonoBuffer: (([Float], Double) -> Void)?

    private let analyzer = AudioAnalyzer()
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var sampleRate: Double = 48_000
    private var startTime: CFTimeInterval = 0
    private var logCounter = 0

    public init() {
        var continuation: AsyncStream<AnalysisFrame>.Continuation!
        self.frames = AsyncStream<AnalysisFrame>(bufferingPolicy: .bufferingNewest(4)) {
            continuation = $0
        }
        self.continuation = continuation
    }

    public func start() async throws {
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.name = "Echoform System Audio"
        description.uuid = UUID()
        description.isPrivate = true
        description.isMixdown = true
        description.isMono = true
        description.isExclusive = true
        description.muteBehavior = .unmuted

        do {
            try check(AudioHardwareCreateProcessTap(description, &tapID),
                      "AudioHardwareCreateProcessTap")
            sampleRate = try tapFormat().mSampleRate

            let tapUID = try stringProperty(kAudioTapPropertyUID, objectID: tapID)
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Echoform System Audio",
                kAudioAggregateDeviceUIDKey: "net.bryanlabs.echoform.tap.\(UUID().uuidString)",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapUIDKey: tapUID,
                    kAudioSubTapDriftCompensationKey: true
                ]]
            ]
            try check(AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary,
                                                         &aggregateDeviceID),
                      "AudioHardwareCreateAggregateDevice")
            try setAggregateTapList([tapUID])

            try createIOProc()
            startTime = CACurrentMediaTime()
            try check(AudioDeviceStart(aggregateDeviceID, ioProcID), "AudioDeviceStart")
            Log.capture.notice("Core Audio process tap started at \(self.sampleRate) Hz")
        } catch {
            cleanup()
            throw error
        }
    }

    public func stop() async {
        cleanup()
        continuation.finish()
        Log.capture.info("Capture stopped")
    }

    private func cleanup() {
        if aggregateDeviceID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        ioProcID = nil
        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    private func handle(inputData: UnsafePointer<AudioBufferList>) {
        guard let mono = monoSamples(from: inputData), !mono.isEmpty else { return }
        let timestamp = CACurrentMediaTime() - startTime
        let frame = analyzer.process(mono: mono, timestamp: timestamp)
        continuation.yield(frame)
        onMonoBuffer?(mono, sampleRate)

        logCounter += 1
        if logCounter % 12 == 0 {
            Log.capture.info("rms=\(frame.rms) peak=\(frame.peak) frames=\(mono.count)")
        }
    }

    private func createIOProc() throws {
        var nextIOProcID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&nextIOProcID,
                                                        aggregateDeviceID,
                                                        nil) { [weak self] _, inputData, _, _, _ in
            self?.handle(inputData: inputData)
        }
        try check(status, "AudioDeviceCreateIOProcIDWithBlock")
        ioProcID = nextIOProcID
    }

    private func tapFormat() throws -> AudioStreamBasicDescription {
        var address = propertyAddress(kAudioTapPropertyFormat)
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var format = AudioStreamBasicDescription()
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format),
                  "AudioObjectGetPropertyData(kAudioTapPropertyFormat)")
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mBitsPerChannel == 32 else {
            throw CaptureError.invalidTapFormat
        }
        return format
    }

    private func stringProperty(_ selector: AudioObjectPropertySelector,
                                objectID: AudioObjectID) throws -> String {
        var address = propertyAddress(selector)
        var size = UInt32(MemoryLayout<CFString>.size)
        var value: CFString = "" as CFString
        try withUnsafeMutablePointer(to: &value) { pointer in
            try check(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer),
                      "AudioObjectGetPropertyData(\(selector))")
        }
        return value as String
    }

    private func setAggregateTapList(_ tapUIDs: [String]) throws {
        var address = propertyAddress(kAudioAggregateDevicePropertyTapList)
        var list = tapUIDs as CFArray
        let size = UInt32(MemoryLayout<CFString>.size * tapUIDs.count)
        try withUnsafeMutablePointer(to: &list) { pointer in
            try check(AudioObjectSetPropertyData(aggregateDeviceID,
                                                 &address,
                                                 0,
                                                 nil,
                                                 size,
                                                 pointer),
                      "AudioObjectSetPropertyData(kAudioAggregateDevicePropertyTapList)")
        }
    }

    private func monoSamples(from inputData: UnsafePointer<AudioBufferList>) -> [Float]? {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
        guard !buffers.isEmpty else { return nil }

        if buffers.count == 1, let data = buffers[0].mData {
            let buffer = buffers[0]
            let floatCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            guard floatCount > 0 else { return nil }
            let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self),
                                              count: floatCount)
            let channels = max(1, Int(buffer.mNumberChannels))
            guard channels > 1 else { return Array(samples) }
            let frameCount = floatCount / channels
            var mono = [Float](repeating: 0, count: frameCount)
            for frame in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += samples[frame * channels + channel]
                }
                mono[frame] = sum / Float(channels)
            }
            return mono
        }

        let channelSamples = buffers.compactMap { buffer -> [Float]? in
            guard let data = buffer.mData else { return nil }
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            guard count > 0 else { return nil }
            return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self),
                                             count: count))
        }
        guard let first = channelSamples.first else { return nil }
        var mono = [Float](repeating: 0, count: first.count)
        for samples in channelSamples {
            for index in 0..<min(mono.count, samples.count) {
                mono[index] += samples[index]
            }
        }
        let divisor = Float(channelSamples.count)
        for index in mono.indices { mono[index] /= divisor }
        return mono
    }

    private func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            Log.capture.error("\(operation, privacy: .public) failed: \(status)")
            throw CaptureError.coreAudioFailure(operation, status)
        }
    }
}

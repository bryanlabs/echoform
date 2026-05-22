import Observation
import QuartzCore

/// Observable state for the visualizer: permission, user controls, the
/// smoothed render signals the views draw from, the caption layer, and theme.
///
/// Captured frames are buffered and played back through a delay line, so the
/// visualization and captions can be nudged into sync with each other.
@MainActor
@Observable
public final class VisualizerState {
    // Permission and capture status.
    public var permission: CapturePermission = .unknown
    public var isCapturing: Bool = false

    // User controls.
    public var mode: VisualMode = .bars
    public var isPaused: Bool = false
    public var intensity: Double = 1.0
    public var brightnessLevel: Int = 1

    /// The analysis frame currently being displayed (delayed by `captionDelay`).
    public var latestFrame: AnalysisFrame = AnalysisFrame()

    // Smoothed render signals (from the delayed playback head).
    public private(set) var level: Float = 0
    public private(set) var pulse: Float = 0
    public private(set) var bass: Float = 0
    public private(set) var mid: Float = 0
    public private(set) var treble: Float = 0
    public private(set) var centroid: Float = 0
    public private(set) var bars: [Float] = []

    public private(set) var heatColumns: [[Float]] = []
    private let heatWidth = 200

    // Caption layer and the shared visualization delay.
    /// Whether the delayed caption layer is shown. Off by default.
    public var textEnabled = false
    /// Seconds of caption/visual sync offset (-2...10). Positive values hold
    /// back the visualization. Negative values can make already-recognized
    /// captions feel earlier, but cannot display text before recognition emits
    /// it.
    public var captionDelay: Double = 0
    public private(set) var captionWords: [CaptionWord] = []
    private var nextCaptionID = 0
    private let maxCaptionWords = 64

    /// Estimated lag between audio and its transcription. The caption layer
    /// offsets by this, so positive visual delay can sync words to the bars.
    public static let recognitionLatency: Double = 2.0
    public static let minCaptionDelay: Double = -2.0
    public static let maxCaptionDelay: Double = 10.0
    public static let captionDelayStep: Double = 0.25

    // Caption language and translation.
    /// Spoken language recognized by the transcriber (see `CaptionLanguage`).
    public var sourceLanguage = "en"
    /// Recognize only on-device. Off allows Apple's online recognition for
    /// languages that have no local model.
    public var onDeviceOnly = false
    /// Whether recognized speech is translated before being shown.
    public var translationEnabled = false
    /// Language the captions are translated into when translation is on.
    public var targetLanguage = "en"
    /// Short status for the caption layer, shown in the captions panel.
    public var captionStatus = ""
    /// Whether the captions and translation panel is shown.
    public var showCaptionPanel = false

    // Theme.
    public var theme: Theme = .classic
    public var customStops: [ThemeColor] = Theme.classic.stops
    public var showThemePanel = false

    // Delay line: recent frames tagged with their capture time.
    private var frameBuffer: [(time: Double, frame: AnalysisFrame)] = []
    private let bufferSeconds: Double = 12
    private var lastPlayedTime: Double = -1

    private var levelEnv = EnvelopeFollower(attack: 0.30, release: 0.05)
    private var pulseEnv = EnvelopeFollower(attack: 0.58, release: 0.10)
    private var bassEnv = EnvelopeFollower(attack: 0.38, release: 0.06)
    private var midEnv = EnvelopeFollower(attack: 0.40, release: 0.07)
    private var trebleEnv = EnvelopeFollower(attack: 0.50, release: 0.09)
    private var centroidEnv = EnvelopeFollower(attack: 0.20, release: 0.05)
    private var barEnvs: [EnvelopeFollower] = []

    public init() {}

    public var palette: Palette {
        var palette = Palette()
        palette.theme = theme
        palette.brightnessLevel = brightnessLevel
        return palette
    }

    public var customTheme: Theme {
        Theme(id: Theme.customID, name: "Custom", stops: customStops)
    }

    /// Buffers a freshly captured frame. Smoothing happens in `renderTick` so
    /// the configurable delay can be applied to playback.
    public func apply(_ frame: AnalysisFrame) {
        let now = CACurrentMediaTime()
        frameBuffer.append((now, frame))
        let cutoff = now - bufferSeconds
        while let first = frameBuffer.first, first.time < cutoff {
            frameBuffer.removeFirst()
        }
    }

    /// Advances the delayed playback head and updates the smoothed signals.
    /// Driven ~60 times a second by the playback loop.
    public func renderTick() {
        guard !isPaused, !frameBuffer.isEmpty else { return }
        let head = CACurrentMediaTime() - captionDelay
        var picked = frameBuffer[0]
        for entry in frameBuffer {
            if entry.time <= head { picked = entry } else { break }
        }

        let frame = picked.frame
        latestFrame = frame
        level = levelEnv.update(frame.rms)
        pulse = pulseEnv.update(frame.peak)
        bass = bassEnv.update(frame.bass)
        mid = midEnv.update(frame.mid)
        treble = trebleEnv.update(frame.treble)
        centroid = centroidEnv.update(frame.centroid)
        updateBars(frame.bands)

        if picked.time != lastPlayedTime {
            lastPlayedTime = picked.time
            updateHeat(bars)
        }
    }

    private func updateBars(_ raw: [Float]) {
        guard !raw.isEmpty else { return }
        if barEnvs.count != raw.count {
            barEnvs = raw.map { _ in EnvelopeFollower(attack: 0.42, release: 0.08) }
        }
        var next = [Float](repeating: 0, count: raw.count)
        for i in raw.indices { next[i] = barEnvs[i].update(raw[i]) }
        bars = next
    }

    private func updateHeat(_ column: [Float]) {
        guard !column.isEmpty else { return }
        var columns = heatColumns
        columns.append(column)
        if columns.count > heatWidth {
            columns.removeFirst(columns.count - heatWidth)
        }
        heatColumns = columns
    }

    // MARK: Controls

    public func select(_ mode: VisualMode) { self.mode = mode }
    public func togglePause() { isPaused.toggle() }
    public func cycleBrightness() { brightnessLevel = (brightnessLevel + 1) % 3 }
    public func setBrightnessLevel(_ level: Int) {
        brightnessLevel = min(2, max(0, level))
    }
    public func adjustIntensity(_ delta: Double) {
        intensity = min(1.8, max(0.3, intensity + delta))
    }
    public func setIntensity(_ value: Double) {
        intensity = min(1.8, max(0.3, value))
    }

    // MARK: Caption layer

    public func toggleText() { textEnabled.toggle() }

    /// Adjusts the caption/visual sync offset, clamped to -2...10 seconds.
    public func adjustCaptionDelay(_ delta: Double) {
        captionDelay = clampCaptionDelay(captionDelay + delta)
    }

    public func setCaptionDelay(_ value: Double) {
        captionDelay = clampCaptionDelay(value)
    }

    private func clampCaptionDelay(_ value: Double) -> Double {
        let rounded = (value * 100).rounded() / 100
        return min(Self.maxCaptionDelay, max(Self.minCaptionDelay, rounded))
    }

    /// Appends newly recognized words, trimming the oldest beyond the cap.
    /// Dropped while paused, so the caption layer freezes with the visuals.
    public func addCaptionWords(_ segments: [CaptionSegment]) {
        guard !isPaused, !segments.isEmpty else { return }
        var words = captionWords
        for segment in segments {
            words.append(CaptionWord(id: nextCaptionID,
                                     text: segment.text,
                                     spokenMediaTime: segment.spokenMediaTime))
            nextCaptionID += 1
        }
        if words.count > maxCaptionWords {
            words.removeFirst(words.count - maxCaptionWords)
        }
        captionWords = words
    }

    // MARK: Theme

    public func toggleThemePanel() {
        showThemePanel.toggle()
        if showThemePanel { showCaptionPanel = false }
    }

    public func toggleCaptionPanel() {
        showCaptionPanel.toggle()
        if showCaptionPanel { showThemePanel = false }
    }

    public func selectTheme(_ theme: Theme) { self.theme = theme }

    public func cycleTheme(forward: Bool = true) {
        let themes = Theme.presets + [customTheme]
        let current = themes.firstIndex { $0.id == theme.id } ?? 0
        let step = forward ? 1 : themes.count - 1
        theme = themes[(current + step) % themes.count]
    }

    public func applyCustomTheme() {
        theme = Theme(id: Theme.customID, name: "Custom", stops: customStops)
    }
}

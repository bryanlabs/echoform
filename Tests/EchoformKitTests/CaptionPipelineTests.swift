import Testing
@testable import EchoformKit

@Suite("CaptionPipeline")
struct CaptionPipelineTests {
    @Test("low latency captions replace the live hypothesis")
    @MainActor
    func lowLatencyCaptionsReplaceLiveText() {
        let state = VisualizerState()
        let translator = CaptionTranslator()
        let pipeline = CaptionPipeline(state: state, translator: translator)

        pipeline.consume(TranscriptionResult(text: "hello wor", isFinal: false))
        #expect(state.liveCaption?.sourceText == "hello wor")
        #expect(state.captionWords.isEmpty)

        pipeline.consume(TranscriptionResult(text: "hello world", isFinal: false))
        #expect(state.liveCaption?.sourceText == "hello world")
        #expect(state.captionWords.isEmpty)
    }

    @Test("steady captions still hold back the newest partial word")
    @MainActor
    func steadyCaptionsKeepExistingStabilityRule() {
        let state = VisualizerState()
        state.setLowLatencyCaptions(false)
        let translator = CaptionTranslator()
        let pipeline = CaptionPipeline(state: state, translator: translator)

        pipeline.consume(TranscriptionResult(text: "hello world now", isFinal: false))

        #expect(state.liveCaption == nil)
        #expect(state.captionWords.map(\.text) == ["hello", "world"])
    }
}

import Foundation

/// A language Echoform can caption or translate. `id` is the BCP-47 language
/// code used by the Translation framework; `speechLocale` is the locale used
/// by Apple's speech recognizer.
public struct CaptionLanguage: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let speechLocale: String

    public init(id: String, name: String, speechLocale: String) {
        self.id = id
        self.name = name
        self.speechLocale = speechLocale
    }

    /// Major languages offered in the captions panel. Easy to extend.
    public static let all: [CaptionLanguage] = [
        CaptionLanguage(id: "en", name: "English", speechLocale: "en-US"),
        CaptionLanguage(id: "ko", name: "Korean", speechLocale: "ko-KR"),
        CaptionLanguage(id: "ja", name: "Japanese", speechLocale: "ja-JP"),
        CaptionLanguage(id: "zh", name: "Chinese", speechLocale: "zh-CN"),
        CaptionLanguage(id: "es", name: "Spanish", speechLocale: "es-ES"),
        CaptionLanguage(id: "fr", name: "French", speechLocale: "fr-FR"),
        CaptionLanguage(id: "de", name: "German", speechLocale: "de-DE"),
        CaptionLanguage(id: "it", name: "Italian", speechLocale: "it-IT"),
        CaptionLanguage(id: "pt", name: "Portuguese", speechLocale: "pt-BR"),
        CaptionLanguage(id: "ru", name: "Russian", speechLocale: "ru-RU"),
        CaptionLanguage(id: "hi", name: "Hindi", speechLocale: "hi-IN"),
        CaptionLanguage(id: "ar", name: "Arabic", speechLocale: "ar-SA"),
    ]

    /// Looks up a language by its `id`, falling back to English.
    public static func named(_ id: String) -> CaptionLanguage {
        all.first { $0.id == id } ?? all[0]
    }
}

//
//  SpeechService.swift
//  GrammarPolice
//
//  Offline TTS via macOS AVSpeechSynthesizer. Auto-detects source language.
//

import Foundation
import AVFoundation
import NaturalLanguage

@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func speak(text: String, languageCode: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let lang = languageCode ?? Self.detectLanguage(for: trimmed) ?? "en-US"
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: lang) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0

        synthesizer.speak(utterance)
        LoggingService.shared.log("SpeechService: speak (lang=\(lang), len=\(trimmed.count))", level: .debug)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    static func detectLanguage(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else { return nil }
        // NLLanguage returns BCP-47 base codes ("en", "vi"). Voice lookup
        // works with either base or regional code; prefer common regional
        // pairings where the default voice quality is better.
        switch lang.rawValue {
        case "en": return "en-US"
        case "vi": return "vi-VN"
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "it": return "it-IT"
        case "pt": return "pt-PT"
        case "ru": return "ru-RU"
        case "ar": return "ar-SA"
        case "hi": return "hi-IN"
        case "th": return "th-TH"
        case "id": return "id-ID"
        default: return lang.rawValue
        }
    }
}

final class SpeakButtonHandler: NSObject {
    let text: String
    let languageCode: String?

    init(text: String, languageCode: String? = nil) {
        self.text = text
        self.languageCode = languageCode
    }

    @MainActor @objc func speak() {
        SpeechService.shared.speak(text: text, languageCode: languageCode)
    }
}

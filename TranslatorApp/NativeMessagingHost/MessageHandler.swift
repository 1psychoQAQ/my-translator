import Foundation
import SwiftData
import Translation
import AVFoundation

// MARK: - Message Handler

@available(macOS 15.0, *)
@MainActor
final class MessageHandler: Sendable {

    private let translationService: HostTranslationService
    private let wordBookService: HostWordBookService
    private let speechService: HostSpeechService

    init() {
        self.translationService = HostTranslationService()
        self.wordBookService = HostWordBookService()
        self.speechService = HostSpeechService()
    }

    func handle(_ message: NativeMessage) async -> NativeResponse {
        switch message.action {
        case "translate":
            return await handleTranslate(message.payload)
        case "saveWord":
            return handleSaveWord(message.payload)
        case "speak":
            return await handleSpeak(message.payload)
        case "ping":
            return .ping()
        default:
            return .failure("Unknown action: \(message.action)")
        }
    }

    // MARK: - Translate

    private func handleTranslate(_ payload: MessagePayload) async -> NativeResponse {
        guard case .translate(let translatePayload) = payload else {
            return .failure("Invalid translate payload")
        }

        let text = translatePayload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .failure("Empty text")
        }

        do {
            let translation = try await translationService.translate(
                text: text,
                from: translatePayload.sourceLanguage,
                to: translatePayload.targetLanguage,
                context: translatePayload.context
            )
            return .translateSuccess(translation)
        } catch {
            return .failure("Translation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Word

    private func handleSaveWord(_ payload: MessagePayload) -> NativeResponse {
        guard case .saveWord(let savePayload) = payload else {
            return .failure("Invalid saveWord payload")
        }

        do {
            try wordBookService.save(
                id: savePayload.id,
                text: savePayload.text,
                translation: savePayload.translation,
                source: savePayload.source,
                sourceURL: savePayload.sourceURL,
                sentence: savePayload.sentence,
                tags: savePayload.tags,
                createdAt: Date(timeIntervalSince1970: savePayload.createdAt / 1000)
            )
            return .success()
        } catch {
            return .failure("Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Speak

    private func handleSpeak(_ payload: MessagePayload) async -> NativeResponse {
        guard case .speak(let speakPayload) = payload else {
            return .failure("Invalid speak payload")
        }

        let text = speakPayload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .failure("Empty text")
        }

        await speechService.speak(text: text, language: speakPayload.language ?? "en-US")
        return .success()
    }
}

// MARK: - Host Speech Service

@MainActor
final class HostSpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(text: String, language: String) async {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)

        synthesizer.speak(utterance)

        // 等待朗读完成
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.08 + 0.5) {
                continuation.resume()
            }
        }
    }
}

// MARK: - Fallback for older macOS versions

@available(macOS, deprecated: 15.0, message: "Use macOS 15+ for full functionality")
@MainActor
final class LegacyMessageHandler: Sendable {

    func handle(_ message: NativeMessage) async -> NativeResponse {
        switch message.action {
        case "translate":
            return .failure("Translation requires macOS 15.0 or later")
        case "saveWord":
            // Word saving still works on older macOS
            let wordBookService = HostWordBookService()
            guard case .saveWord(let payload) = message.payload else {
                return .failure("Invalid saveWord payload")
            }
            do {
                try wordBookService.save(
                    id: payload.id,
                    text: payload.text,
                    translation: payload.translation,
                    source: payload.source,
                    sourceURL: payload.sourceURL,
                    sentence: payload.sentence,
                    tags: payload.tags,
                    createdAt: Date(timeIntervalSince1970: payload.createdAt / 1000)
                )
                return .success()
            } catch {
                return .failure("Save failed: \(error.localizedDescription)")
            }
        case "ping":
            return .ping()
        default:
            return .failure("Unknown action: \(message.action)")
        }
    }
}

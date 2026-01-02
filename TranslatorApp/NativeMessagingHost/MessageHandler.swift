import Foundation
import SwiftData
import Translation

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

    func speak(text: String, language: String) async {
        // 使用系统 say 命令，在 CLI 环境下更可靠
        // say 命令会阻塞直到朗读完成
        let voice = voiceForLanguage(language)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        task.arguments = ["-v", voice, text]

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // 静默失败，say 命令出错时不影响主流程
        }
    }

    private func voiceForLanguage(_ language: String) -> String {
        // 根据语言代码选择合适的系统语音
        switch language.lowercased() {
        case "zh-cn", "zh-hans", "zh":
            return "Tingting"  // 中文女声
        case "zh-tw", "zh-hant":
            return "Meijia"    // 台湾中文
        case "ja", "ja-jp":
            return "Kyoko"     // 日语
        case "ko", "ko-kr":
            return "Yuna"      // 韩语
        case "en-gb":
            return "Daniel"    // 英式英语
        default:
            return "Samantha"  // 美式英语（默认）
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

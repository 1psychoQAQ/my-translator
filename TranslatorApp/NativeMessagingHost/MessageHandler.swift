import Foundation
import SwiftData
import Translation

// MARK: - Message Handler

@available(macOS 15.0, *)
@MainActor
final class MessageHandler: Sendable {

    private let translationService: HostTranslationService
    private let wordBookService: HostWordBookService

    init() {
        self.translationService = HostTranslationService()
        self.wordBookService = HostWordBookService()
    }

    func handle(_ message: NativeMessage) async -> NativeResponse {
        switch message.action {
        case "translate":
            return await handleTranslate(message.payload)
        case "saveWord":
            return handleSaveWord(message.payload)
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
                to: translatePayload.targetLanguage
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
                tags: savePayload.tags,
                createdAt: Date(timeIntervalSince1970: savePayload.createdAt / 1000)
            )
            return .success()
        } catch {
            return .failure("Save failed: \(error.localizedDescription)")
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

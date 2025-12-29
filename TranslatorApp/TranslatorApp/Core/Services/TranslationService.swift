import Foundation
import SwiftUI
import Translation

// MARK: - Translation Service

@available(macOS 15.0, *)
final class TranslationService: TranslationServiceProtocol {

    func translate(_ text: String, from sourceLanguage: String?, to targetLanguage: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslatorError.translationFailed(reason: "文本为空")
        }

        return try await TranslationCoordinator.shared.translate(
            text: text,
            from: sourceLanguage ?? "en",
            to: targetLanguage
        )
    }
}

// MARK: - Translation Coordinator (单例窗口管理)

@available(macOS 15.0, *)
@MainActor
private class TranslationCoordinator {

    static let shared = TranslationCoordinator()

    private var helperWindow: NSWindow?
    private var viewModel = TranslationViewModel()

    private init() {}

    func translate(text: String, from source: String, to target: String) async throws -> String {
        // 确保窗口存在
        ensureWindowExists()

        // 执行翻译
        return try await viewModel.translate(text: text, from: source, to: target)
    }

    private func ensureWindowExists() {
        guard helperWindow == nil else { return }

        let hostingView = NSHostingView(rootView: TranslationHelperView(viewModel: viewModel))

        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFront(nil)
        window.level = .floating
        self.helperWindow = window
    }
}

// MARK: - Translation ViewModel

@available(macOS 15.0, *)
@MainActor
private class TranslationViewModel: ObservableObject {

    @Published var configuration: TranslationSession.Configuration?

    private var cachedSession: TranslationSession?
    private var pendingText: String?
    private var continuation: CheckedContinuation<String, Error>?

    func translate(text: String, from source: String, to target: String) async throws -> String {
        let sourceLang = Locale.Language(identifier: source)
        let targetLang = Locale.Language(identifier: target)

        // 如果已有缓存的会话，直接使用
        if let session = cachedSession {
            let response = try await session.translate(text)
            return response.targetText
        }

        // 首次翻译，需要通过 .translationTask 获取会话
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.pendingText = text
            // 设置配置触发 .translationTask
            self.configuration = TranslationSession.Configuration(source: sourceLang, target: targetLang)
        }
    }

    func onSessionReady(_ session: TranslationSession) async {
        // 缓存会话供后续使用
        self.cachedSession = session

        guard let text = pendingText, let cont = continuation else { return }
        pendingText = nil
        continuation = nil

        do {
            let response = try await session.translate(text)
            cont.resume(returning: response.targetText)
        } catch {
            cont.resume(throwing: TranslatorError.translationFailed(reason: error.localizedDescription))
        }
    }
}

// MARK: - Translation Helper View

@available(macOS 15.0, *)
private struct TranslationHelperView: View {
    @ObservedObject var viewModel: TranslationViewModel

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(viewModel.configuration) { session in
                await viewModel.onSessionReady(session)
            }
    }
}

// MARK: - Legacy Fallback

final class LegacyTranslationService: TranslationServiceProtocol {
    func translate(_ text: String, from sourceLanguage: String?, to targetLanguage: String) async throws -> String {
        throw TranslatorError.translationFailed(reason: "翻译功能需要 macOS 15.0 或更高版本")
    }
}

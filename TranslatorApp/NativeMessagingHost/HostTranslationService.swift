import Foundation
import Translation
import AppKit
import SwiftUI

// MARK: - Host Translation Service
// Uses Apple Translation Framework in command-line context via a hidden SwiftUI window

@available(macOS 15.0, *)
@MainActor
final class HostTranslationService {

    private var translationWindow: NSWindow?
    private var viewModel: TranslationBridgeViewModel?

    init() {
        // Initialize the hidden window for SwiftUI translation
        setupTranslationWindow()
    }

    private func setupTranslationWindow() {
        let vm = TranslationBridgeViewModel()
        self.viewModel = vm

        let hostingView = NSHostingView(rootView: TranslationBridgeView(viewModel: vm))

        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFront(nil)
        window.level = .floating

        self.translationWindow = window
    }

    func translate(text: String, from sourceLanguage: String?, to targetLanguage: String) async throws -> String {
        guard let viewModel = viewModel else {
            throw TranslationError.notInitialized
        }

        return try await viewModel.translate(
            text: text,
            from: sourceLanguage ?? "en",
            to: targetLanguage
        )
    }
}

// MARK: - Translation Bridge ViewModel

@available(macOS 15.0, *)
@MainActor
final class TranslationBridgeViewModel: ObservableObject {

    @Published var configuration: TranslationSession.Configuration?

    private var cachedSession: TranslationSession?
    private var pendingText: String?
    private var continuation: CheckedContinuation<String, Error>?
    private var currentSourceLang: String?
    private var currentTargetLang: String?

    func translate(text: String, from source: String, to target: String) async throws -> String {
        // If we have a cached session with matching languages, use it directly
        if let session = cachedSession,
           currentSourceLang == source && currentTargetLang == target {
            let response = try await session.translate(text)
            return response.targetText
        }

        // Need to create a new session via .translationTask
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.pendingText = text
            self.currentSourceLang = source
            self.currentTargetLang = target

            let sourceLang = Locale.Language(identifier: source)
            let targetLang = Locale.Language(identifier: target)
            self.configuration = TranslationSession.Configuration(source: sourceLang, target: targetLang)
        }
    }

    func onSessionReady(_ session: TranslationSession) {
        // Cache the session
        self.cachedSession = session

        guard let text = pendingText, let cont = continuation else { return }
        pendingText = nil
        continuation = nil

        // Perform translation synchronously on MainActor
        Task { @MainActor in
            do {
                let response = try await session.translate(text)
                cont.resume(returning: response.targetText)
            } catch {
                cont.resume(throwing: TranslationError.failed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Translation Bridge View

@available(macOS 15.0, *)
struct TranslationBridgeView: View {
    @ObservedObject var viewModel: TranslationBridgeViewModel

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(viewModel.configuration) { session in
                viewModel.onSessionReady(session)
            }
    }
}

// MARK: - Translation Error

enum TranslationError: LocalizedError, Sendable {
    case notInitialized
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Translation service not initialized"
        case .failed(let reason):
            return "Translation failed: \(reason)"
        }
    }
}

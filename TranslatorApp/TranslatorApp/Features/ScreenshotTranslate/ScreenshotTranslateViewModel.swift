import Foundation
import SwiftUI
import AppKit

@MainActor
final class ScreenshotTranslateViewModel: ObservableObject {

    private var screenshotService: ScreenshotService?
    private var ocrService: OCRServiceProtocol?
    private var translationService: TranslationServiceProtocol?
    private var wordBookManager: WordBookManagerProtocol?

    // Placeholder for deferred initialization
    nonisolated static let placeholder = ScreenshotTranslateViewModel()

    nonisolated init() {}

    func configure(
        screenshotService: ScreenshotServiceProtocol,
        ocrService: OCRServiceProtocol,
        translationService: TranslationServiceProtocol,
        wordBookManager: WordBookManagerProtocol
    ) {
        self.screenshotService = screenshotService as? ScreenshotService
        self.ocrService = ocrService
        self.translationService = translationService
        self.wordBookManager = wordBookManager
    }

    func startScreenshotTranslation() async {
        // 检查屏幕录制权限
        let permissions = PermissionsManager.shared
        if !permissions.hasScreenCapturePermission {
            permissions.requestScreenCapturePermission()
            return
        }

        guard let screenshotService = screenshotService else {
            showErrorAlert("应用尚未完成初始化，请稍后重试")
            return
        }

        // 显示选区窗口，传入翻译回调
        let action = await screenshotService.showSelectionAndCapture { [weak self] rect in
            guard let self = self else {
                throw TranslatorError.screenshotFailed(reason: "ViewModel 已释放")
            }
            return try await self.performTranslation(rect: rect)
        }

        // 根据用户操作执行相应逻辑
        switch action {
        case .saveToWordBook(let original, let translated):
            saveToWordBook(original: original, translated: translated)

        case .copied:
            // 复制操作在 overlay 中已完成
            print("✅ 已复制到剪贴板")

        case .cancelled:
            // 用户取消，什么都不做
            print("ℹ️ 用户取消")
        }
    }

    /// 执行翻译：截图 → OCR → 翻译
    private func performTranslation(rect: CGRect) async throws -> (original: String, translated: String) {
        guard let screenshotService = screenshotService,
              let ocrService = ocrService,
              let translationService = translationService else {
            throw TranslatorError.screenshotFailed(reason: "服务未配置")
        }

        // 1. 截图
        print("📸 Capturing region: \(rect)")
        let image = try await screenshotService.captureRegion(rect)
        print("✅ Screenshot captured: \(image.width)x\(image.height)")

        // 2. OCR
        print("🔍 Running OCR...")
        let recognizedText = try ocrService.extractText(from: image)
        print("✅ OCR result: \(recognizedText.prefix(50))...")

        guard !recognizedText.isEmpty else {
            throw TranslatorError.ocrFailed(reason: "未识别到文字")
        }

        // 3. 翻译 (英语 -> 中文)
        print("🌐 Translating...")
        let translatedText = try await translationService.translate(
            recognizedText,
            from: "en",
            to: "zh-Hans"
        )
        print("✅ Translation result: \(translatedText.prefix(50))...")

        return (original: recognizedText, translated: translatedText)
    }

    private func saveToWordBook(original: String, translated: String) {
        guard let manager = wordBookManager else {
            print("❌ 单词本服务未配置")
            return
        }

        let word = Word(
            text: original,
            translation: translated,
            source: "screenshot"
        )

        do {
            try manager.save(word)
            print("✅ 已保存到单词本")
        } catch {
            print("❌ 保存失败: \(error.localizedDescription)")
        }
    }

    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "错误"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

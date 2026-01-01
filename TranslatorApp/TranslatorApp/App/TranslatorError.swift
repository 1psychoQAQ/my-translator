import Foundation
import CoreGraphics

enum TranslatorError: LocalizedError {
    case ocrFailed(reason: String)
    case translationFailed(reason: String)
    case screenshotFailed(reason: String)
    case wordBookError(reason: String)
    case permissionDenied(reason: String)

    var errorDescription: String? {
        switch self {
        case .ocrFailed(let reason):
            return "OCR 失败: \(reason)"
        case .translationFailed(let reason):
            return "翻译失败: \(reason)"
        case .screenshotFailed(let reason):
            return "截图失败: \(reason)"
        case .wordBookError(let reason):
            return "单词本错误: \(reason)"
        case .permissionDenied(let reason):
            return "权限被拒绝: \(reason)"
        }
    }
}

// MARK: - Service Protocols

protocol TranslationServiceProtocol {
    func translate(_ text: String, from sourceLanguage: String?, to targetLanguage: String) async throws -> String
}

protocol OCRServiceProtocol {
    func extractText(from image: CGImage) throws -> String
}

protocol ScreenshotServiceProtocol {
    func captureRegion(_ rect: CGRect) async throws -> CGImage
}

protocol WordBookManagerProtocol {
    func save(_ word: Word) throws
    func saveAll(_ words: [Word], skipDuplicates: Bool) throws -> Int
    func delete(_ word: Word) throws
    func deleteAll() throws
    func fetchAll() throws -> [Word]
    func search(_ keyword: String) throws -> [Word]
}

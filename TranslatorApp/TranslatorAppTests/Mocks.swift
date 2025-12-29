import Foundation
import CoreGraphics
@testable import TranslatorApp

// MARK: - Mock Translation Service

final class MockTranslationService: TranslationServiceProtocol {
    var mockResult = "模拟翻译结果"
    var shouldThrow = false
    var errorToThrow: TranslatorError = .translationFailed(reason: "mock error")
    var translateCallCount = 0
    var lastTranslatedText: String?

    func translate(_ text: String, from sourceLanguage: String?, to targetLanguage: String) async throws -> String {
        translateCallCount += 1
        lastTranslatedText = text

        if shouldThrow {
            throw errorToThrow
        }
        return mockResult
    }
}

// MARK: - Mock OCR Service

final class MockOCRService: OCRServiceProtocol {
    var mockText = "Hello World"
    var shouldThrow = false
    var errorToThrow: TranslatorError = .ocrFailed(reason: "mock error")
    var extractCallCount = 0

    func extractText(from image: CGImage) throws -> String {
        extractCallCount += 1

        if shouldThrow {
            throw errorToThrow
        }
        return mockText
    }
}

// MARK: - Mock Word Book Manager

final class MockWordBookManager: WordBookManagerProtocol {
    var words: [Word] = []
    var shouldThrow = false
    var errorToThrow: TranslatorError = .wordBookError(reason: "mock error")

    var saveCallCount = 0
    var deleteCallCount = 0
    var fetchAllCallCount = 0
    var searchCallCount = 0

    func save(_ word: Word) throws {
        saveCallCount += 1
        if shouldThrow {
            throw errorToThrow
        }
        words.append(word)
    }

    func delete(_ word: Word) throws {
        deleteCallCount += 1
        if shouldThrow {
            throw errorToThrow
        }
        words.removeAll { $0.id == word.id }
    }

    func fetchAll() throws -> [Word] {
        fetchAllCallCount += 1
        if shouldThrow {
            throw errorToThrow
        }
        return words
    }

    func search(_ keyword: String) throws -> [Word] {
        searchCallCount += 1
        if shouldThrow {
            throw errorToThrow
        }
        return words.filter {
            $0.text.contains(keyword) || $0.translation.contains(keyword)
        }
    }
}

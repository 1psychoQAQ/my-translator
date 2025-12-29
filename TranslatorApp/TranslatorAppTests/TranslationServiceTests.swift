import XCTest
@testable import TranslatorApp

final class TranslationServiceTests: XCTestCase {

    // MARK: - LegacyTranslationService Tests

    func testLegacyService_shouldThrowError() async {
        // Given
        let sut = LegacyTranslationService()

        // When/Then
        do {
            _ = try await sut.translate("Hello", from: "en", to: "zh-Hans")
            XCTFail("Should throw error")
        } catch {
            guard let translatorError = error as? TranslatorError else {
                XCTFail("Expected TranslatorError")
                return
            }

            if case .translationFailed(let reason) = translatorError {
                XCTAssertTrue(reason.contains("macOS 15.0"), "Error should mention version requirement")
            } else {
                XCTFail("Expected translationFailed error")
            }
        }
    }

    // MARK: - TranslationService Tests (requires macOS 15.0)

    @available(macOS 15.0, *)
    func testTranslate_withEmptyText_shouldThrowError() async {
        // Given
        let sut = TranslationService()

        // When/Then
        do {
            _ = try await sut.translate("", from: "en", to: "zh-Hans")
            XCTFail("Should throw error for empty text")
        } catch {
            guard let translatorError = error as? TranslatorError else {
                XCTFail("Expected TranslatorError")
                return
            }

            if case .translationFailed(let reason) = translatorError {
                XCTAssertTrue(reason.contains("为空"), "Error should indicate empty text")
            } else {
                XCTFail("Expected translationFailed error")
            }
        }
    }

    @available(macOS 15.0, *)
    func testTranslate_withWhitespaceOnlyText_shouldThrowError() async {
        // Given
        let sut = TranslationService()

        // When/Then
        do {
            _ = try await sut.translate("   \n\t  ", from: "en", to: "zh-Hans")
            XCTFail("Should throw error for whitespace-only text")
        } catch {
            guard let translatorError = error as? TranslatorError else {
                XCTFail("Expected TranslatorError")
                return
            }

            if case .translationFailed = translatorError {
                // Expected
            } else {
                XCTFail("Expected translationFailed error")
            }
        }
    }

    // MARK: - Mock Service Tests

    func testMockService_shouldReturnMockResult() async throws {
        // Given
        let mockService = MockTranslationService()
        mockService.mockResult = "你好"

        // When
        let result = try await mockService.translate("Hello", from: "en", to: "zh-Hans")

        // Then
        XCTAssertEqual(result, "你好")
        XCTAssertEqual(mockService.translateCallCount, 1)
        XCTAssertEqual(mockService.lastTranslatedText, "Hello")
    }

    func testMockService_shouldThrowWhenConfigured() async {
        // Given
        let mockService = MockTranslationService()
        mockService.shouldThrow = true
        mockService.errorToThrow = .translationFailed(reason: "Test error")

        // When/Then
        do {
            _ = try await mockService.translate("Hello", from: "en", to: "zh-Hans")
            XCTFail("Should throw error")
        } catch {
            guard let translatorError = error as? TranslatorError else {
                XCTFail("Expected TranslatorError")
                return
            }

            if case .translationFailed(let reason) = translatorError {
                XCTAssertEqual(reason, "Test error")
            } else {
                XCTFail("Expected translationFailed error")
            }
        }
    }

    // MARK: - Protocol Conformance Tests

    func testProtocolConformance_translationService() {
        if #available(macOS 15.0, *) {
            let service: TranslationServiceProtocol = TranslationService()
            XCTAssertNotNil(service)
        }
    }

    func testProtocolConformance_legacyService() {
        let service: TranslationServiceProtocol = LegacyTranslationService()
        XCTAssertNotNil(service)
    }

    func testProtocolConformance_mockService() {
        let service: TranslationServiceProtocol = MockTranslationService()
        XCTAssertNotNil(service)
    }
}

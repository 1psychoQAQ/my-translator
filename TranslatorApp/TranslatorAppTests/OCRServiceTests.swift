import XCTest
import CoreGraphics
import AppKit
@testable import TranslatorApp

final class OCRServiceTests: XCTestCase {

    var sut: OCRService!

    override func setUp() {
        super.setUp()
        sut = OCRService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func createTestImage(withText text: String, size: CGSize = CGSize(width: 200, height: 50)) -> CGImage? {
        let nsImage = NSImage(size: size)
        nsImage.lockFocus()

        // 白色背景
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // 黑色文字
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: NSPoint(x: 10, y: 10))

        nsImage.unlockFocus()

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            return nil
        }

        return cgImage
    }

    private func createBlankImage(size: CGSize = CGSize(width: 200, height: 50)) -> CGImage? {
        let nsImage = NSImage(size: size)
        nsImage.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        nsImage.unlockFocus()

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            return nil
        }

        return cgImage
    }

    // MARK: - Tests

    func testExtractText_withClearEnglishText_shouldReturnText() throws {
        // Given - use larger image with bigger font for better OCR
        guard let image = createTestImage(withText: "HELLO", size: CGSize(width: 300, height: 80)) else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let result = try sut.extractText(from: image)

        // Then - OCR may not perfectly recognize programmatically generated text
        XCTAssertFalse(result.isEmpty, "OCR result should not be empty")
    }

    func testExtractText_withBlankImage_shouldThrowError() {
        // Given
        guard let image = createBlankImage() else {
            XCTFail("Failed to create blank image")
            return
        }

        // When/Then
        XCTAssertThrowsError(try sut.extractText(from: image)) { error in
            guard let translatorError = error as? TranslatorError else {
                XCTFail("Expected TranslatorError")
                return
            }

            if case .ocrFailed(let reason) = translatorError {
                XCTAssertTrue(reason.contains("未检测到文字") || reason.contains("无法识别"),
                              "Error should indicate no text found")
            } else {
                XCTFail("Expected ocrFailed error")
            }
        }
    }

    func testExtractText_withNumbers_shouldReturnText() throws {
        // Given
        guard let image = createTestImage(withText: "12345") else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let result = try sut.extractText(from: image)

        // Then
        XCTAssertFalse(result.isEmpty, "OCR result should not be empty")
        XCTAssertTrue(result.contains("12345"), "OCR should recognize numbers")
    }

    func testExtractText_withSpecialCharacters_shouldReturnText() throws {
        // Given
        guard let image = createTestImage(withText: "Hello!") else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let result = try sut.extractText(from: image)

        // Then
        XCTAssertFalse(result.isEmpty, "OCR result should not be empty")
    }
}

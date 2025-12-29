import Foundation
import Vision

final class OCRService: OCRServiceProtocol {

    func extractText(from image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja", "ko"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw TranslatorError.ocrFailed(reason: error.localizedDescription)
        }

        guard let observations = request.results else {
            throw TranslatorError.ocrFailed(reason: "无法识别文字")
        }

        let recognizedText = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        if recognizedText.isEmpty {
            throw TranslatorError.ocrFailed(reason: "图片中未检测到文字")
        }

        return recognizedText
    }
}

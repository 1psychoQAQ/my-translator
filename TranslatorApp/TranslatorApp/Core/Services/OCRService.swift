import Foundation
import Vision

final class OCRService: OCRServiceProtocol {

    /// 基础置信度阈值
    private let baseConfidence: Float = 0.5

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

        guard let observations = request.results, !observations.isEmpty else {
            throw TranslatorError.ocrFailed(reason: "未检测到文字")
        }

        let recognizedText = observations
            .compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first else { return nil }

                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }

                // 动态置信度阈值：基于文本长度和边界框大小
                let requiredConfidence = calculateRequiredConfidence(
                    text: text,
                    boundingBox: observation.boundingBox,
                    baseConfidence: baseConfidence
                )

                guard candidate.confidence >= requiredConfidence else { return nil }

                // 过滤纯标点/符号
                if text.allSatisfy({ $0.isPunctuation || $0.isWhitespace || $0.isSymbol }) {
                    return nil
                }

                return text
            }
            .joined(separator: "\n")

        if recognizedText.isEmpty {
            throw TranslatorError.ocrFailed(reason: "未检测到有效文字")
        }

        return recognizedText
    }

    /// 动态计算所需置信度
    /// - 短文本（1-2字符）需要更高置信度
    /// - 边界框很小的识别结果需要更高置信度（可能是噪点）
    private func calculateRequiredConfidence(
        text: String,
        boundingBox: CGRect,
        baseConfidence: Float
    ) -> Float {
        var confidence = baseConfidence

        // 边界框面积占比（0-1）
        let boxArea = boundingBox.width * boundingBox.height

        // 短文本 + 小边界框 = 很可能是噪点，需要高置信度
        if text.count <= 2 {
            // 单字符：基础 0.7，边界框越小要求越高
            // 双字符：基础 0.6
            let lengthPenalty: Float = text.count == 1 ? 0.2 : 0.1
            confidence += lengthPenalty

            // 边界框面积 < 1% 的单字符，额外增加置信度要求
            if boxArea < 0.01 && text.count == 1 {
                confidence += 0.15
            }
        }

        // 边界框高度很小（< 2%），可能是噪点
        if boundingBox.height < 0.02 {
            confidence += 0.1
        }

        return min(confidence, 0.95)  // 上限 0.95
    }
}

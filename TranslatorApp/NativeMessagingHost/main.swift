import Foundation
import AppKit

// MARK: - Native Messaging Host Entry Point
//
// Chrome Native Messaging protocol:
// - Read from stdin: 4-byte length (little-endian) + JSON message body
// - Write to stdout: 4-byte length (little-endian) + JSON message body
//
// This host handles:
// - translate: Translate text using Apple Translation Framework
// - saveWord: Save word to SwiftData (shared with main app)
// - ping: Health check

@main
struct NativeMessagingHost {

    @MainActor
    static func main() async {
        // 禁止在 Dock 显示图标（因为 import AppKit 会让 macOS 认为是 GUI 应用）
        NSApplication.shared.setActivationPolicy(.prohibited)

        // Set up stderr for logging (Chrome captures stdout for messages)
        setbuf(stderr, nil)
        log("Native Messaging Host started")

        // Create handler on MainActor
        let handler: Any
        if #available(macOS 15.0, *) {
            handler = MessageHandler()
        } else {
            handler = LegacyMessageHandler()
        }

        // Process messages in a loop
        while let message = readMessage() {
            log("Received message: \(message.action)")

            let response: NativeResponse
            if #available(macOS 15.0, *) {
                response = await (handler as! MessageHandler).handle(message)
            } else {
                response = await (handler as! LegacyMessageHandler).handle(message)
            }

            writeMessage(response)
            log("Sent response for: \(message.action)")
        }

        log("Native Messaging Host exiting")
    }

    // MARK: - Read Message from stdin

    nonisolated static func readMessage() -> NativeMessage? {
        // Read 4-byte length (little-endian)
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let bytesRead = fread(&lengthBytes, 1, 4, stdin)

        guard bytesRead == 4 else {
            if bytesRead == 0 {
                log("stdin closed, exiting")
            } else {
                log("Failed to read message length, got \(bytesRead) bytes")
            }
            return nil
        }

        let length = UInt32(lengthBytes[0]) |
                     UInt32(lengthBytes[1]) << 8 |
                     UInt32(lengthBytes[2]) << 16 |
                     UInt32(lengthBytes[3]) << 24

        guard length > 0, length < 1024 * 1024 else { // Max 1MB
            log("Invalid message length: \(length)")
            return nil
        }

        // Read message body
        var messageBytes = [UInt8](repeating: 0, count: Int(length))
        let messageRead = fread(&messageBytes, 1, Int(length), stdin)

        guard messageRead == Int(length) else {
            log("Failed to read message body, expected \(length) got \(messageRead)")
            return nil
        }

        // Parse JSON
        let data = Data(messageBytes)
        do {
            let message = try JSONDecoder().decode(NativeMessage.self, from: data)
            return message
        } catch {
            log("Failed to parse message: \(error)")
            return nil
        }
    }

    // MARK: - Write Message to stdout

    nonisolated static func writeMessage(_ response: NativeResponse) {
        do {
            let data = try JSONEncoder().encode(response)

            // Write 4-byte length (little-endian)
            let length = UInt32(data.count)
            var lengthBytes = [UInt8](repeating: 0, count: 4)
            lengthBytes[0] = UInt8(length & 0xFF)
            lengthBytes[1] = UInt8((length >> 8) & 0xFF)
            lengthBytes[2] = UInt8((length >> 16) & 0xFF)
            lengthBytes[3] = UInt8((length >> 24) & 0xFF)

            fwrite(lengthBytes, 1, 4, stdout)

            // Write message body
            _ = data.withUnsafeBytes { buffer in
                fwrite(buffer.baseAddress, 1, data.count, stdout)
            }

            fflush(stdout)
        } catch {
            log("Failed to encode response: \(error)")
        }
    }

    // MARK: - Logging (to stderr)

    nonisolated static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        fputs("[\(timestamp)] NativeMessagingHost: \(message)\n", stderr)
    }
}

// MARK: - Message Types

struct NativeMessage: Codable, Sendable {
    let action: String
    let payload: MessagePayload
}

enum MessagePayload: Codable, Sendable {
    case translate(TranslatePayload)
    case saveWord(SaveWordPayload)
    case speak(SpeakPayload)
    case ping
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let translate = try? container.decode(TranslatePayload.self) {
            self = .translate(translate)
        } else if let saveWord = try? container.decode(SaveWordPayload.self) {
            self = .saveWord(saveWord)
        } else if let speak = try? container.decode(SpeakPayload.self) {
            self = .speak(speak)
        } else if let empty = try? container.decode([String: String].self), empty.isEmpty {
            self = .ping
        } else {
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .translate(let payload):
            try container.encode(payload)
        case .saveWord(let payload):
            try container.encode(payload)
        case .speak(let payload):
            try container.encode(payload)
        case .ping:
            try container.encode([String: String]())
        case .unknown:
            try container.encode([String: String]())
        }
    }
}

struct TranslatePayload: Codable, Sendable {
    let text: String
    let sourceLanguage: String?
    let targetLanguage: String
    let context: String?  // 上下文句子，用于语境翻译
}

struct SaveWordPayload: Codable, Sendable {
    let id: String
    let text: String
    let translation: String
    let source: String
    let sourceURL: String?
    let sentence: String?  // 完整句子，用于语境回顾
    let tags: [String]
    let createdAt: Double
}

struct SpeakPayload: Codable, Sendable {
    let text: String
    let language: String?  // 默认 en-US
}

// MARK: - Response Types

struct NativeResponse: Codable, Sendable {
    let success: Bool
    let translation: String?
    let version: String?
    let error: String?

    static func translateSuccess(_ translation: String) -> NativeResponse {
        NativeResponse(success: true, translation: translation, version: nil, error: nil)
    }

    static func success() -> NativeResponse {
        NativeResponse(success: true, translation: nil, version: nil, error: nil)
    }

    static func ping() -> NativeResponse {
        NativeResponse(success: true, translation: nil, version: "1.0.0", error: nil)
    }

    static func failure(_ error: String) -> NativeResponse {
        NativeResponse(success: false, translation: nil, version: nil, error: error)
    }
}

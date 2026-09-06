import Foundation

// MARK: - 供应商枚举

/// 大模型供应商，后续可扩展更多厂商
enum LLMProvider: String, CaseIterable, Identifiable {
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        }
    }

    var baseURL: URL {
        switch self {
        case .deepseek: return URL(string: "https://api.deepseek.com")!
        }
    }

    var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        }
    }
}

// MARK: - 消息模型

struct ChatMessage: Identifiable {
    enum Role: String {
        case system
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

// MARK: - 服务协议

/// 大模型服务统一接口，划词提问与截图提问均复用此接口
protocol LLMServiceProtocol {
    func chat(messages: [ChatMessage]) async throws -> String
}

// MARK: - DeepSeek 实现

final class DeepSeekService: LLMServiceProtocol {

    private let apiKey: String
    private let baseURL: URL
    private let model: String
    private let session: URLSession

    init(apiKey: String, baseURL: URL, model: String) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = URLSession(configuration: .default)
    }

    func chat(messages: [ChatMessage]) async throws -> String {
        let url = baseURL.appendingPathComponent("chat/completions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TranslatorError.aiFailed(reason: "无效的响应")
        }

        guard (200...299).contains(http.statusCode) else {
            let message = Self.extractError(from: data) ?? "HTTP \(http.statusCode)"
            throw TranslatorError.aiFailed(reason: message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw TranslatorError.aiFailed(reason: "无法解析响应")
        }

        return content
    }

    private static func extractError(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
}

// MARK: - 工厂

/// 根据供应商与 API Key 构建对应的大模型服务
enum LLMServiceFactory {
    static func makeService(provider: LLMProvider, apiKey: String) -> LLMServiceProtocol {
        switch provider {
        case .deepseek:
            return DeepSeekService(apiKey: apiKey, baseURL: provider.baseURL, model: provider.defaultModel)
        }
    }
}

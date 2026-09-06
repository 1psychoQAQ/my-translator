import Foundation
import Combine

/// 大模型设置（供应商 + API Key）
/// API Key 通过钥匙串加密存储，避免明文落盘
final class LLMSettings: ObservableObject {

    static let shared = LLMSettings()

    private let defaults = UserDefaults.standard
    private let providerKey = "llmProvider"
    private let keychainService = "com.translator.app.llm"
    private let keychainAccount = "apiKey"

    @Published var provider: LLMProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: providerKey)
        }
    }

    @Published var apiKey: String {
        didSet {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainManager.delete(service: keychainService, account: keychainAccount)
            } else {
                KeychainManager.save(trimmed, service: keychainService, account: keychainAccount)
            }
        }
    }

    private init() {
        if let raw = defaults.string(forKey: providerKey), let provider = LLMProvider(rawValue: raw) {
            self.provider = provider
        } else {
            self.provider = .deepseek
        }

        self.apiKey = KeychainManager.load(service: keychainService, account: keychainAccount) ?? ""
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeService() -> LLMServiceProtocol {
        LLMServiceFactory.makeService(provider: provider, apiKey: apiKey)
    }
}

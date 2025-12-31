import Foundation
import SwiftData

@Model
class Word {
    var id: UUID
    var text: String
    var translation: String
    var source: String
    var sourceURL: String?
    var sentence: String?  // 完整句子，用于语境回顾
    var tags: [String]
    var createdAt: Date
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        text: String,
        translation: String,
        source: String = "screenshot",
        sourceURL: String? = nil,
        sentence: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.translation = translation
        self.source = source
        self.sourceURL = sourceURL
        self.sentence = sentence
        self.tags = tags
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}

extension Word {
    static var preview: Word {
        Word(
            text: "Hello",
            translation: "你好",
            source: "screenshot"
        )
    }
}

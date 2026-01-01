import Foundation
import SwiftData

extension Notification.Name {
    static let wordBookDidChange = Notification.Name("wordBookDidChange")
}

final class WordBookManager: WordBookManagerProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ word: Word) throws {
        modelContext.insert(word)
        do {
            try modelContext.save()
            // 发送通知，触发单词本刷新
            NotificationCenter.default.post(name: .wordBookDidChange, object: nil)
        } catch {
            throw TranslatorError.wordBookError(reason: "保存失败: \(error.localizedDescription)")
        }
    }

    func delete(_ word: Word) throws {
        modelContext.delete(word)
        do {
            try modelContext.save()
        } catch {
            throw TranslatorError.wordBookError(reason: "删除失败: \(error.localizedDescription)")
        }
    }

    func deleteAll() throws {
        do {
            try modelContext.delete(model: Word.self)
            try modelContext.save()
        } catch {
            throw TranslatorError.wordBookError(reason: "清空失败: \(error.localizedDescription)")
        }
    }

    /// Save multiple words, optionally skipping duplicates
    /// - Returns: Number of words actually saved
    func saveAll(_ words: [Word], skipDuplicates: Bool) throws -> Int {
        var savedCount = 0
        let existingWords = try fetchAll()
        let existingTexts = Set(existingWords.map { $0.text.lowercased() })

        for word in words {
            if skipDuplicates && existingTexts.contains(word.text.lowercased()) {
                continue
            }
            modelContext.insert(word)
            savedCount += 1
        }

        do {
            try modelContext.save()
        } catch {
            throw TranslatorError.wordBookError(reason: "批量保存失败: \(error.localizedDescription)")
        }

        return savedCount
    }

    func fetchAll() throws -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw TranslatorError.wordBookError(reason: "获取失败: \(error.localizedDescription)")
        }
    }

    func search(_ keyword: String) throws -> [Word] {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKeyword.isEmpty else {
            return try fetchAll()
        }

        let predicate = #Predicate<Word> { word in
            word.text.localizedStandardContains(trimmedKeyword) ||
            word.translation.localizedStandardContains(trimmedKeyword)
        }

        let descriptor = FetchDescriptor<Word>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw TranslatorError.wordBookError(reason: "搜索失败: \(error.localizedDescription)")
        }
    }
}

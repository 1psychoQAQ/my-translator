import Foundation
import SwiftData

final class WordBookManager: WordBookManagerProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ word: Word) throws {
        modelContext.insert(word)
        do {
            try modelContext.save()
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

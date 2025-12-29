import Foundation
import SwiftUI

@MainActor
final class WordBookViewModel: ObservableObject {

    @Published var words: [Word] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let wordBookManager: WordBookManagerProtocol

    init(wordBookManager: WordBookManagerProtocol) {
        self.wordBookManager = wordBookManager
    }

    func loadWords() {
        isLoading = true
        errorMessage = nil

        do {
            if searchText.isEmpty {
                words = try wordBookManager.fetchAll()
            } else {
                words = try wordBookManager.search(searchText)
            }
        } catch let error as TranslatorError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteWord(_ word: Word) {
        do {
            try wordBookManager.delete(word)
            words.removeAll { $0.id == word.id }
        } catch let error as TranslatorError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteWords(at offsets: IndexSet) {
        for index in offsets {
            let word = words[index]
            deleteWord(word)
        }
    }
}

import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class WordBookViewModel: ObservableObject {

    @Published var words: [Word] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let wordBookManager: WordBookManagerProtocol
    private let importExportService = ImportExportService.shared
    private var localObserver: NSObjectProtocol?
    private var distributedObserver: NSObjectProtocol?

    init(wordBookManager: WordBookManagerProtocol) {
        self.wordBookManager = wordBookManager
        setupNotificationObserver()
    }

    deinit {
        if let observer = localObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = distributedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func setupNotificationObserver() {
        // 监听本地单词本变化通知（截图翻译收藏）
        localObserver = NotificationCenter.default.addObserver(
            forName: .wordBookDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadWords()
        }

        // 监听分布式通知（Chrome 插件收藏，跨进程通信）
        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.translator.app.wordBookDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadWords()
        }
    }

    // MARK: - Export

    func exportWords(format: ExportFormat) {
        guard !words.isEmpty else {
            errorMessage = "No data to export"
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = format == .json
            ? [.json]
            : [.commaSeparatedText]
        savePanel.nameFieldStringValue = "wordbook.\(format.fileExtension)"
        savePanel.title = "Export words"
        savePanel.message = "Choose save location"

        savePanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = savePanel.url else { return }

            Task { @MainActor in
                do {
                    let data = try self.importExportService.export(words: self.words, format: format)
                    try data.write(to: url)
                    self.successMessage = "Exported \(self.words.count) words successfully"
                } catch {
                    self.errorMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Import

    func importWords() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json, .commaSeparatedText]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.title = "Import words"
        openPanel.message = "Select JSON or CSV file"

        openPanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = openPanel.url else { return }

            Task { @MainActor in
                do {
                    let importedWords = try self.importExportService.importFromFile(url: url)
                    let savedCount = try self.wordBookManager.saveAll(importedWords, skipDuplicates: true)
                    self.successMessage = "Imported \(savedCount) words (\(importedWords.count - savedCount) duplicates skipped)"
                    self.loadWords()
                } catch {
                    self.errorMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func clearSuccessMessage() {
        successMessage = nil
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

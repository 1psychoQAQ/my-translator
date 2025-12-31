import Foundation
import SwiftData

// MARK: - Host Word Book Service
// Shares SwiftData database with main TranslatorApp

@MainActor
final class HostWordBookService: Sendable {

    private let modelContainer: ModelContainer

    init() {
        // Use the same schema as the main app (must use same class name "Word")
        let schema = Schema([Word.self])

        // Use the same storage location as the main app
        // SwiftData uses: ~/Library/Application Support/<bundle-id>/default.store
        // We need to point to the main app's data location
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mainAppBundleID = "com.translator.app"
        let storeURL = appSupportURL
            .appendingPathComponent(mainAppBundleID)
            .appendingPathComponent("default.store")

        NativeMessagingHost.log("SwiftData store path: \(storeURL.path)")

        // Ensure directory exists
        let storeDir = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let modelConfiguration = ModelConfiguration(
            url: storeURL,
            allowsSave: true
        )

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            NativeMessagingHost.log("Failed to create ModelContainer: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func save(
        id: String,
        text: String,
        translation: String,
        source: String,
        sourceURL: String?,
        sentence: String?,
        tags: [String],
        createdAt: Date
    ) throws {
        let context = modelContainer.mainContext

        // Check if word already exists
        let predicate = #Predicate<Word> { word in
            word.text == text
        }
        let descriptor = FetchDescriptor<Word>(predicate: predicate)

        if let existingWords = try? context.fetch(descriptor), !existingWords.isEmpty {
            NativeMessagingHost.log("Word already exists: \(text)")
            return // Skip duplicate
        }

        let word = Word(
            id: UUID(uuidString: id) ?? UUID(),
            text: text,
            translation: translation,
            source: source,
            sourceURL: sourceURL,
            sentence: sentence,
            tags: tags,
            createdAt: createdAt
        )

        context.insert(word)
        try context.save()

        NativeMessagingHost.log("Saved word: \(text) -> \(translation)")
    }
}

// MARK: - Word Model
// Must match the main app's Word model exactly (same class name for SwiftData compatibility)

@Model
final class Word {
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
        source: String = "webpage",
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

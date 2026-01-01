import Foundation

/// Word data transfer object for import/export (without SwiftData dependencies)
struct WordDTO: Codable {
    let id: String
    let text: String
    let translation: String
    let source: String
    let sourceURL: String?
    let sentence: String?
    let tags: [String]
    let createdAt: Date
    let syncedAt: Date?

    init(from word: Word) {
        self.id = word.id.uuidString
        self.text = word.text
        self.translation = word.translation
        self.source = word.source
        self.sourceURL = word.sourceURL
        self.sentence = word.sentence
        self.tags = word.tags
        self.createdAt = word.createdAt
        self.syncedAt = word.syncedAt
    }

    func toWord() -> Word {
        Word(
            id: UUID(uuidString: id) ?? UUID(),
            text: text,
            translation: translation,
            source: source,
            sourceURL: sourceURL,
            sentence: sentence,
            tags: tags,
            createdAt: createdAt,
            syncedAt: syncedAt
        )
    }
}

/// Export file format
struct ExportData: Codable {
    let version: String
    let exportedAt: Date
    let appName: String
    let wordCount: Int
    let words: [WordDTO]

    init(words: [Word]) {
        self.version = "1.0"
        self.exportedAt = Date()
        self.appName = "Translator"
        self.wordCount = words.count
        self.words = words.map { WordDTO(from: $0) }
    }
}

enum ExportFormat {
    case json
    case csv

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }

    var contentType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        }
    }
}

enum ImportExportError: LocalizedError {
    case exportFailed(String)
    case importFailed(String)
    case invalidFormat(String)
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .exportFailed(let reason): return "Export failed: \(reason)"
        case .importFailed(let reason): return "Import failed: \(reason)"
        case .invalidFormat(let reason): return "Invalid format: \(reason)"
        case .fileAccessDenied: return "File access denied"
        }
    }
}

final class ImportExportService {

    static let shared = ImportExportService()

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private init() {}

    // MARK: - Export

    func exportToJSON(words: [Word]) throws -> Data {
        let exportData = ExportData(words: words)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(exportData)
        } catch {
            throw ImportExportError.exportFailed(error.localizedDescription)
        }
    }

    func exportToCSV(words: [Word]) throws -> Data {
        var csv = "id,text,translation,source,sourceURL,sentence,tags,createdAt,syncedAt\n"

        for word in words {
            let row = [
                escapeCSV(word.id.uuidString),
                escapeCSV(word.text),
                escapeCSV(word.translation),
                escapeCSV(word.source),
                escapeCSV(word.sourceURL ?? ""),
                escapeCSV(word.sentence ?? ""),
                escapeCSV(word.tags.joined(separator: ";")),
                escapeCSV(csvDateFormatter.string(from: word.createdAt)),
                escapeCSV(word.syncedAt.map { csvDateFormatter.string(from: $0) } ?? "")
            ].joined(separator: ",")

            csv += row + "\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw ImportExportError.exportFailed("CSV encoding failed")
        }

        return data
    }

    func export(words: [Word], format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            return try exportToJSON(words: words)
        case .csv:
            return try exportToCSV(words: words)
        }
    }

    // MARK: - Import

    func importFromJSON(data: Data) throws -> [Word] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let exportData = try decoder.decode(ExportData.self, from: data)
            return exportData.words.map { $0.toWord() }
        } catch {
            throw ImportExportError.importFailed("JSON parsing failed: \(error.localizedDescription)")
        }
    }

    func importFromCSV(data: Data) throws -> [Word] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportExportError.importFailed("CSV encoding failed")
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard lines.count > 1 else {
            throw ImportExportError.invalidFormat("CSV file is empty or has no data rows")
        }

        // Parse header
        let header = parseCSVLine(lines[0])
        let textIndex = header.firstIndex(of: "text") ?? 0
        let translationIndex = header.firstIndex(of: "translation") ?? 1
        let sourceIndex = header.firstIndex(of: "source")
        let sourceURLIndex = header.firstIndex(of: "sourceURL")
        let sentenceIndex = header.firstIndex(of: "sentence")
        let tagsIndex = header.firstIndex(of: "tags")
        let createdAtIndex = header.firstIndex(of: "createdAt")

        var words: [Word] = []

        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i])
            guard fields.count >= 2 else { continue }

            let text = fields.indices.contains(textIndex) ? fields[textIndex] : ""
            let translation = fields.indices.contains(translationIndex) ? fields[translationIndex] : ""

            guard !text.isEmpty else { continue }

            let source = sourceIndex.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? "imported"
            let sourceURL = sourceURLIndex.flatMap { fields.indices.contains($0) ? fields[$0] : nil }
            let sentence = sentenceIndex.flatMap { fields.indices.contains($0) ? fields[$0] : nil }
            let tagsString = tagsIndex.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            let tags = tagsString.isEmpty ? [] : tagsString.components(separatedBy: ";")

            var createdAt = Date()
            if let index = createdAtIndex, fields.indices.contains(index), !fields[index].isEmpty {
                createdAt = csvDateFormatter.date(from: fields[index]) ?? Date()
            }

            let word = Word(
                text: text,
                translation: translation,
                source: source,
                sourceURL: sourceURL?.isEmpty == true ? nil : sourceURL,
                sentence: sentence?.isEmpty == true ? nil : sentence,
                tags: tags,
                createdAt: createdAt
            )

            words.append(word)
        }

        return words
    }

    func importFromFile(url: URL) throws -> [Word] {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportExportError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "json":
            return try importFromJSON(data: data)
        case "csv":
            return try importFromCSV(data: data)
        default:
            throw ImportExportError.invalidFormat("Unsupported file format: \(ext). Use .json or .csv")
        }
    }

    // MARK: - CSV Helpers

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                if inQuotes {
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentField.append("\"")
                        i = nextIndex
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }

            i = line.index(after: i)
        }

        fields.append(currentField)
        return fields
    }
}

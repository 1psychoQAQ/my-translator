import XCTest
import SwiftData
@testable import TranslatorApp

final class WordBookManagerTests: XCTestCase {

    var sut: WordBookManager!
    var modelContainer: ModelContainer!

    @MainActor
    override func setUp() {
        super.setUp()

        // 使用内存数据库进行测试
        let schema = Schema([Word.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        sut = WordBookManager(modelContext: modelContainer.mainContext)
    }

    override func tearDown() {
        sut = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    @MainActor
    func testSave_shouldAddWordToDatabase() throws {
        // Given
        let word = Word(text: "Hello", translation: "你好", source: "screenshot")

        // When
        try sut.save(word)

        // Then
        let words = try sut.fetchAll()
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.text, "Hello")
        XCTAssertEqual(words.first?.translation, "你好")
    }

    @MainActor
    func testSave_multipleWords_shouldAddAllWords() throws {
        // Given
        let word1 = Word(text: "Hello", translation: "你好", source: "screenshot")
        let word2 = Word(text: "World", translation: "世界", source: "webpage")
        let word3 = Word(text: "Test", translation: "测试", source: "video")

        // When
        try sut.save(word1)
        try sut.save(word2)
        try sut.save(word3)

        // Then
        let words = try sut.fetchAll()
        XCTAssertEqual(words.count, 3)
    }

    // MARK: - Delete Tests

    @MainActor
    func testDelete_shouldRemoveWordFromDatabase() throws {
        // Given
        let word = Word(text: "Hello", translation: "你好", source: "screenshot")
        try sut.save(word)
        XCTAssertEqual(try sut.fetchAll().count, 1)

        // When
        try sut.delete(word)

        // Then
        let words = try sut.fetchAll()
        XCTAssertEqual(words.count, 0)
    }

    @MainActor
    func testDelete_onlyTargetWord_shouldKeepOthers() throws {
        // Given
        let word1 = Word(text: "Hello", translation: "你好", source: "screenshot")
        let word2 = Word(text: "World", translation: "世界", source: "webpage")
        try sut.save(word1)
        try sut.save(word2)

        // When
        try sut.delete(word1)

        // Then
        let words = try sut.fetchAll()
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.text, "World")
    }

    // MARK: - FetchAll Tests

    @MainActor
    func testFetchAll_emptyDatabase_shouldReturnEmptyArray() throws {
        // When
        let words = try sut.fetchAll()

        // Then
        XCTAssertTrue(words.isEmpty)
    }

    @MainActor
    func testFetchAll_shouldReturnSortedByCreatedAtDescending() throws {
        // Given
        let word1 = Word(text: "First", translation: "第一", createdAt: Date().addingTimeInterval(-100))
        let word2 = Word(text: "Second", translation: "第二", createdAt: Date().addingTimeInterval(-50))
        let word3 = Word(text: "Third", translation: "第三", createdAt: Date())

        try sut.save(word1)
        try sut.save(word2)
        try sut.save(word3)

        // When
        let words = try sut.fetchAll()

        // Then
        XCTAssertEqual(words.count, 3)
        XCTAssertEqual(words[0].text, "Third")
        XCTAssertEqual(words[1].text, "Second")
        XCTAssertEqual(words[2].text, "First")
    }

    // MARK: - Search Tests

    @MainActor
    func testSearch_byOriginalText_shouldReturnMatchingWords() throws {
        // Given
        let word1 = Word(text: "Hello World", translation: "你好世界", source: "screenshot")
        let word2 = Word(text: "Goodbye", translation: "再见", source: "webpage")
        try sut.save(word1)
        try sut.save(word2)

        // When
        let results = try sut.search("Hello")

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, "Hello World")
    }

    @MainActor
    func testSearch_byTranslation_shouldReturnMatchingWords() throws {
        // Given
        let word1 = Word(text: "Hello", translation: "你好世界", source: "screenshot")
        let word2 = Word(text: "Test", translation: "测试", source: "webpage")
        try sut.save(word1)
        try sut.save(word2)

        // When
        let results = try sut.search("世界")

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.translation, "你好世界")
    }

    @MainActor
    func testSearch_emptyKeyword_shouldReturnAllWords() throws {
        // Given
        let word1 = Word(text: "Hello", translation: "你好", source: "screenshot")
        let word2 = Word(text: "World", translation: "世界", source: "webpage")
        try sut.save(word1)
        try sut.save(word2)

        // When
        let results = try sut.search("")

        // Then
        XCTAssertEqual(results.count, 2)
    }

    @MainActor
    func testSearch_whitespaceKeyword_shouldReturnAllWords() throws {
        // Given
        let word = Word(text: "Hello", translation: "你好", source: "screenshot")
        try sut.save(word)

        // When
        let results = try sut.search("   ")

        // Then
        XCTAssertEqual(results.count, 1)
    }

    @MainActor
    func testSearch_noMatch_shouldReturnEmptyArray() throws {
        // Given
        let word = Word(text: "Hello", translation: "你好", source: "screenshot")
        try sut.save(word)

        // When
        let results = try sut.search("NotExists")

        // Then
        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testSearch_caseInsensitive_shouldReturnMatchingWords() throws {
        // Given
        let word = Word(text: "Hello World", translation: "你好世界", source: "screenshot")
        try sut.save(word)

        // When
        let results = try sut.search("hello")

        // Then
        XCTAssertEqual(results.count, 1)
    }
}

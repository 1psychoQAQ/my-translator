import XCTest
@testable import TranslatorApp

@MainActor
final class WordBookViewModelTests: XCTestCase {

    var sut: WordBookViewModel!
    var mockManager: MockWordBookManager!

    override func setUp() {
        super.setUp()
        mockManager = MockWordBookManager()
        sut = WordBookViewModel(wordBookManager: mockManager)
    }

    override func tearDown() {
        sut = nil
        mockManager = nil
        super.tearDown()
    }

    // MARK: - LoadWords Tests

    func testLoadWords_shouldFetchAllWords() {
        // Given
        let word = Word(text: "Hello", translation: "你好", source: "screenshot")
        mockManager.words = [word]

        // When
        sut.loadWords()

        // Then
        XCTAssertEqual(sut.words.count, 1)
        XCTAssertEqual(sut.words.first?.text, "Hello")
        XCTAssertEqual(mockManager.fetchAllCallCount, 1)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadWords_withSearchText_shouldSearchWords() {
        // Given
        let word = Word(text: "Hello World", translation: "你好世界", source: "screenshot")
        mockManager.words = [word]
        sut.searchText = "Hello"

        // When
        sut.loadWords()

        // Then
        XCTAssertEqual(mockManager.searchCallCount, 1)
        XCTAssertEqual(mockManager.fetchAllCallCount, 0)
    }

    func testLoadWords_withError_shouldSetErrorMessage() {
        // Given
        mockManager.shouldThrow = true
        mockManager.errorToThrow = .wordBookError(reason: "Test error")

        // When
        sut.loadWords()

        // Then
        XCTAssertTrue(sut.words.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("Test error") ?? false)
    }

    // MARK: - DeleteWord Tests

    func testDeleteWord_shouldRemoveFromList() {
        // Given
        let word = Word(text: "Hello", translation: "你好", source: "screenshot")
        mockManager.words = [word]
        sut.loadWords()
        XCTAssertEqual(sut.words.count, 1)

        // When
        sut.deleteWord(word)

        // Then
        XCTAssertTrue(sut.words.isEmpty)
        XCTAssertEqual(mockManager.deleteCallCount, 1)
    }

    func testDeleteWord_withError_shouldSetErrorMessage() {
        // Given
        let word = Word(text: "Hello", translation: "你好", source: "screenshot")
        sut.words = [word]
        mockManager.shouldThrow = true
        mockManager.errorToThrow = .wordBookError(reason: "Delete failed")

        // When
        sut.deleteWord(word)

        // Then
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage?.contains("Delete failed") ?? false)
    }

    func testDeleteWords_atOffsets_shouldDeleteSingleItem() {
        // Given
        let word1 = Word(text: "Hello", translation: "你好", source: "screenshot")
        let word2 = Word(text: "World", translation: "世界", source: "webpage")
        mockManager.words = [word1, word2]
        sut.loadWords()

        // When
        sut.deleteWords(at: IndexSet([0]))

        // Then
        XCTAssertEqual(sut.words.count, 1)
        XCTAssertEqual(sut.words.first?.text, "World")
        XCTAssertEqual(mockManager.deleteCallCount, 1)
    }

    // MARK: - State Tests

    func testInitialState() {
        // Then
        XCTAssertTrue(sut.words.isEmpty)
        XCTAssertEqual(sut.searchText, "")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
}

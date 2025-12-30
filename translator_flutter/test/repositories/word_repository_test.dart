import 'package:flutter_test/flutter_test.dart';
import 'package:translator_flutter/core/result.dart';
import 'package:translator_flutter/models/word.dart';
import 'package:translator_flutter/repositories/word_repository.dart';
import 'package:translator_flutter/services/sync_service.dart';

/// Simple mock implementation of SyncServiceProtocol
class FakeSyncService implements SyncServiceProtocol {
  List<Word> wordsToReturn = [];
  Exception? errorToThrow;
  List<Word> uploadedWords = [];
  List<String> deletedIds = [];

  @override
  Future<List<Word>> download() async {
    if (errorToThrow != null) throw errorToThrow!;
    return wordsToReturn;
  }

  @override
  Future<void> upload(List<Word> words) async {
    if (errorToThrow != null) throw errorToThrow!;
    uploadedWords.addAll(words);
  }

  @override
  Future<void> deleteWord(String id) async {
    if (errorToThrow != null) throw errorToThrow!;
    deletedIds.add(id);
  }

  @override
  Stream<List<Word>> watchChanges() {
    return Stream.value(wordsToReturn);
  }
}

void main() {
  late FakeSyncService fakeSyncService;
  late WordRepository repository;

  final testWords = [
    Word(
      id: '1',
      text: 'hello',
      translation: 'nihao',
      source: 'webpage',
      createdAt: DateTime.now(),
    ),
    Word(
      id: '2',
      text: 'world',
      translation: 'shijie',
      source: 'video',
      createdAt: DateTime.now(),
    ),
  ];

  setUp(() {
    fakeSyncService = FakeSyncService();
    repository = WordRepository(fakeSyncService);
  });

  group('WordRepository', () {
    test('fetchWords returns success on successful download', () async {
      fakeSyncService.wordsToReturn = testWords;

      final result = await repository.fetchWords();

      expect(result, isA<Success<List<Word>>>());
      expect((result as Success).data.length, 2);
    });

    test('fetchWords returns failure on error', () async {
      fakeSyncService.errorToThrow = Exception('Network error');

      final result = await repository.fetchWords();

      expect(result, isA<Failure<List<Word>>>());
    });

    test('addWord uploads word', () async {
      final word = testWords[0];

      final result = await repository.addWord(word);

      expect(result, isA<Success<void>>());
      expect(fakeSyncService.uploadedWords, contains(word));
    });

    test('deleteWord calls sync service', () async {
      final result = await repository.deleteWord('1');

      expect(result, isA<Success<void>>());
      expect(fakeSyncService.deletedIds, contains('1'));
    });

    test('searchWords filters cached words', () async {
      fakeSyncService.wordsToReturn = testWords;

      // First fetch to populate cache
      await repository.fetchWords();

      final result = await repository.searchWords('hello');

      expect(result, isA<Success<List<Word>>>());
      final words = (result as Success<List<Word>>).data;
      expect(words.length, 1);
      expect(words[0].text, 'hello');
    });

    test('searchWords searches in translation too', () async {
      fakeSyncService.wordsToReturn = testWords;

      await repository.fetchWords();

      final result = await repository.searchWords('nihao');

      expect(result, isA<Success<List<Word>>>());
      final words = (result as Success<List<Word>>).data;
      expect(words.length, 1);
      expect(words[0].translation, 'nihao');
    });

    test('cachedWords returns empty list initially', () {
      expect(repository.cachedWords, isEmpty);
    });

    test('cachedWords returns words after fetch', () async {
      fakeSyncService.wordsToReturn = testWords;

      await repository.fetchWords();

      expect(repository.cachedWords.length, 2);
    });
  });
}

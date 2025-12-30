import 'package:flutter_test/flutter_test.dart';
import 'package:translator_flutter/core/errors.dart';
import 'package:translator_flutter/core/result.dart';
import 'package:translator_flutter/models/word.dart';
import 'package:translator_flutter/providers/word_book_notifier.dart';
import 'package:translator_flutter/providers/word_book_state.dart';
import 'package:translator_flutter/repositories/word_repository.dart';
import 'package:translator_flutter/services/sync_service.dart';

/// Simple fake implementation of WordRepository
class FakeWordRepository implements WordRepository {
  Result<List<Word>>? fetchResult;
  Result<List<Word>>? searchResult;
  Result<void>? deleteResult;
  Result<void>? addResult;

  List<Word> _cache = [];
  String? lastSearchQuery;
  String? lastDeletedId;

  @override
  Future<Result<List<Word>>> fetchWords() async {
    if (fetchResult != null) {
      if (fetchResult is Success<List<Word>>) {
        _cache = (fetchResult as Success<List<Word>>).data;
      }
      return fetchResult!;
    }
    return const Success([]);
  }

  @override
  Future<Result<List<Word>>> searchWords(String query) async {
    lastSearchQuery = query;
    return searchResult ?? fetchResult ?? const Success([]);
  }

  @override
  Future<Result<void>> deleteWord(String id) async {
    lastDeletedId = id;
    if (deleteResult != null) return deleteResult!;
    _cache.removeWhere((w) => w.id == id);
    return const Success(null);
  }

  @override
  Future<Result<void>> addWord(Word word) async {
    return addResult ?? const Success(null);
  }

  @override
  Future<Result<void>> updateWord(Word word) async {
    return const Success(null);
  }

  @override
  Stream<List<Word>> watchWords() {
    return Stream.value(_cache);
  }

  @override
  List<Word> get cachedWords => _cache;
}

void main() {
  late FakeWordRepository fakeRepository;

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
    fakeRepository = FakeWordRepository();
  });

  group('WordBookNotifier', () {
    test('loads words successfully', () async {
      fakeRepository.fetchResult = Success(testWords);

      final notifier = WordBookNotifier(fakeRepository);

      // Wait for async load
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.state, isA<WordBookLoaded>());
      final loaded = notifier.state as WordBookLoaded;
      expect(loaded.words.length, 2);
    });

    test('handles fetch error', () async {
      fakeRepository.fetchResult =
          const Failure(SyncError('Network error'));

      final notifier = WordBookNotifier(fakeRepository);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.state, isA<WordBookError>());
      final error = notifier.state as WordBookError;
      expect(error.error.message, 'Network error');
    });

    test('search calls repository with query', () async {
      fakeRepository.fetchResult = Success(testWords);
      fakeRepository.searchResult = Success([testWords[0]]);

      final notifier = WordBookNotifier(fakeRepository);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await notifier.search('hello');

      expect(fakeRepository.lastSearchQuery, 'hello');
    });

    test('deleteWord removes word from state', () async {
      fakeRepository.fetchResult = Success(testWords);

      final notifier = WordBookNotifier(fakeRepository);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await notifier.deleteWord('1');

      expect(fakeRepository.lastDeletedId, '1');
      final loaded = notifier.state as WordBookLoaded;
      expect(loaded.words.length, 1);
      expect(loaded.words[0].id, '2');
    });

    test('words getter returns empty list when not loaded', () async {
      fakeRepository.fetchResult = const Failure(SyncError('Error'));

      final notifier = WordBookNotifier(fakeRepository);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.words, isEmpty);
    });
  });

  group('WordBookStateX', () {
    test('isLoading returns correct value', () {
      const loading = WordBookLoading();
      const loaded = WordBookLoaded([]);

      expect(loading.isLoading, isTrue);
      expect(loaded.isLoading, isFalse);
    });

    test('isLoaded returns correct value', () {
      const loading = WordBookLoading();
      const loaded = WordBookLoaded([]);

      expect(loading.isLoaded, isFalse);
      expect(loaded.isLoaded, isTrue);
    });

    test('wordsOrNull returns words when loaded', () {
      final words = [
        Word(
          id: '1',
          text: 'test',
          translation: 'test',
          source: 'webpage',
          createdAt: DateTime.now(),
        ),
      ];
      final loaded = WordBookLoaded(words);

      expect(loaded.wordsOrNull, equals(words));
    });

    test('wordsOrNull returns null when not loaded', () {
      const loading = WordBookLoading();

      expect(loading.wordsOrNull, isNull);
    });
  });
}

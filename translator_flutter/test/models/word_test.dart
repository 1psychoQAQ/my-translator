import 'package:flutter_test/flutter_test.dart';
import 'package:translator_flutter/models/word.dart';

void main() {
  group('Word', () {
    final now = DateTime.now();

    test('creates word with required fields', () {
      final word = Word(
        id: '123',
        text: 'hello',
        translation: 'nihao',
        source: WordSource.webpage,
        createdAt: now,
      );

      expect(word.id, '123');
      expect(word.text, 'hello');
      expect(word.translation, 'nihao');
      expect(word.source, 'webpage');
      expect(word.createdAt, now);
      expect(word.tags, isEmpty);
      expect(word.sourceURL, isNull);
      expect(word.syncedAt, isNull);
    });

    test('creates word with all fields', () {
      final syncedAt = DateTime.now();
      final word = Word(
        id: '123',
        text: 'hello',
        translation: 'nihao',
        source: WordSource.video,
        sourceURL: 'https://example.com',
        tags: ['tag1', 'tag2'],
        createdAt: now,
        syncedAt: syncedAt,
      );

      expect(word.sourceURL, 'https://example.com');
      expect(word.tags, ['tag1', 'tag2']);
      expect(word.syncedAt, syncedAt);
    });

    test('copyWith creates new instance with updated fields', () {
      final word = Word(
        id: '123',
        text: 'hello',
        translation: 'nihao',
        source: WordSource.webpage,
        createdAt: now,
      );

      final updated = word.copyWith(text: 'world');

      expect(updated.id, '123');
      expect(updated.text, 'world');
      expect(updated.translation, 'nihao');
    });

    test('equality works correctly', () {
      final word1 = Word(
        id: '123',
        text: 'hello',
        translation: 'nihao',
        source: WordSource.webpage,
        createdAt: now,
      );

      final word2 = Word(
        id: '123',
        text: 'hello',
        translation: 'nihao',
        source: WordSource.webpage,
        createdAt: now,
      );

      expect(word1, equals(word2));
    });

    test('toJson and fromJson work correctly', () {
      final word = Word(
        id: '123',
        text: 'hello',
        translation: 'nihao',
        source: WordSource.screenshot,
        tags: ['test'],
        createdAt: now,
      );

      final json = word.toJson();
      final restored = Word.fromJson(json);

      expect(restored.id, word.id);
      expect(restored.text, word.text);
      expect(restored.translation, word.translation);
      expect(restored.source, word.source);
      expect(restored.tags, word.tags);
    });
  });

  group('WordSource', () {
    test('has correct constants', () {
      expect(WordSource.webpage, 'webpage');
      expect(WordSource.video, 'video');
      expect(WordSource.screenshot, 'screenshot');
    });
  });
}

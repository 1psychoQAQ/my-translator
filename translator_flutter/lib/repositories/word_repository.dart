import '../core/errors.dart';
import '../core/result.dart';
import '../models/word.dart';
import '../services/sync_service.dart';

/// Repository for word data operations
/// Uses Result pattern for error handling
class WordRepository {
  WordRepository(this._syncService);

  final SyncServiceProtocol _syncService;

  /// In-memory cache
  List<Word> _cache = [];

  /// Fetch all words from remote
  Future<Result<List<Word>>> fetchWords() async {
    try {
      final words = await _syncService.download();
      _cache = words;
      return Success(words);
    } on Exception catch (e) {
      return Failure(SyncError('Failed to fetch words', e));
    }
  }

  /// Add a new word
  Future<Result<void>> addWord(Word word) async {
    try {
      await _syncService.upload([word]);
      _cache = [word, ..._cache];
      return const Success(null);
    } on Exception catch (e) {
      return Failure(SyncError('Failed to add word', e));
    }
  }

  /// Update an existing word
  Future<Result<void>> updateWord(Word word) async {
    try {
      await _syncService.upload([word]);
      final index = _cache.indexWhere((w) => w.id == word.id);
      if (index != -1) {
        _cache[index] = word;
      }
      return const Success(null);
    } on Exception catch (e) {
      return Failure(SyncError('Failed to update word', e));
    }
  }

  /// Delete a word
  Future<Result<void>> deleteWord(String id) async {
    try {
      await _syncService.deleteWord(id);
      _cache.removeWhere((w) => w.id == id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(SyncError('Failed to delete word', e));
    }
  }

  /// Search words by query
  Future<Result<List<Word>>> searchWords(String query) async {
    try {
      if (_cache.isEmpty) {
        final result = await fetchWords();
        if (result is Failure) {
          return result as Failure<List<Word>>;
        }
      }

      final lowerQuery = query.toLowerCase();
      final filtered = _cache.where((word) {
        return word.text.toLowerCase().contains(lowerQuery) ||
            word.translation.toLowerCase().contains(lowerQuery);
      }).toList();

      return Success(filtered);
    } on Exception catch (e) {
      return Failure(SyncError('Failed to search words', e));
    }
  }

  /// Watch real-time changes
  Stream<List<Word>> watchWords() {
    return _syncService.watchChanges().map((words) {
      _cache = words;
      return words;
    });
  }

  /// Get cached words (synchronous)
  List<Word> get cachedWords => List.unmodifiable(_cache);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/result.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';
import 'word_book_state.dart';

/// State notifier for word book
class WordBookNotifier extends StateNotifier<WordBookState> {
  WordBookNotifier(this._repository) : super(const WordBookLoading()) {
    _load();
  }

  final WordRepository _repository;

  /// Current search query
  String _searchQuery = '';

  /// Load words from repository
  Future<void> _load() async {
    state = const WordBookLoading();

    final result = _searchQuery.isEmpty
        ? await _repository.fetchWords()
        : await _repository.searchWords(_searchQuery);

    state = result.when(
      success: (words) => WordBookLoaded(words),
      failure: (error) => WordBookError(error),
    );
  }

  /// Refresh words
  Future<void> refresh() async {
    await _load();
  }

  /// Search words
  Future<void> search(String query) async {
    _searchQuery = query;
    await _load();
  }

  /// Delete a word
  Future<void> deleteWord(String id) async {
    final result = await _repository.deleteWord(id);
    result.when(
      success: (_) {
        // Update state if currently loaded
        final currentState = state;
        if (currentState is WordBookLoaded) {
          final words = currentState.words.where((w) => w.id != id).toList();
          state = WordBookLoaded(words);
        }
      },
      failure: (error) {
        // Could show error snackbar here
      },
    );
  }

  /// Add a word
  Future<bool> addWord(Word word) async {
    final result = await _repository.addWord(word);
    return result.when(
      success: (_) {
        // Reload to include new word
        refresh();
        return true;
      },
      failure: (_) => false,
    );
  }

  /// Get all words (for testing)
  List<Word> get words {
    final currentState = state;
    if (currentState is WordBookLoaded) {
      return currentState.words;
    }
    return [];
  }
}

/// Extension to check state type
extension WordBookStateX on WordBookState {
  /// Check if loading
  bool get isLoading => this is WordBookLoading;

  /// Check if loaded
  bool get isLoaded => this is WordBookLoaded;

  /// Check if error
  bool get isError => this is WordBookError;

  /// Get words if loaded
  List<Word>? get wordsOrNull {
    final self = this;
    if (self is WordBookLoaded) {
      return self.words;
    }
    return null;
  }
}

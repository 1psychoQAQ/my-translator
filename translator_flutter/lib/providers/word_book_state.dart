import '../core/errors.dart';
import '../models/word.dart';

/// State for word book screen using sealed class pattern
sealed class WordBookState {
  const WordBookState();
}

class WordBookLoading extends WordBookState {
  const WordBookLoading();
}

class WordBookLoaded extends WordBookState {
  const WordBookLoaded(this.words);
  final List<Word> words;
}

class WordBookError extends WordBookState {
  const WordBookError(this.error);
  final AppError error;
}

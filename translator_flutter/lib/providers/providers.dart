import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/word_repository.dart';
import '../services/sync_service.dart';
import 'word_book_notifier.dart';
import 'word_book_state.dart';

/// Firebase Firestore instance provider
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return SyncService(firestore);
});

/// Word repository provider
final wordRepositoryProvider = Provider<WordRepository>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return WordRepository(syncService);
});

/// Word book state provider
final wordBookProvider =
    StateNotifierProvider<WordBookNotifier, WordBookState>((ref) {
  final repository = ref.watch(wordRepositoryProvider);
  return WordBookNotifier(repository);
});

/// Real-time words stream provider
final wordsStreamProvider = StreamProvider<List<dynamic>>((ref) {
  final repository = ref.watch(wordRepositoryProvider);
  return repository.watchWords();
});

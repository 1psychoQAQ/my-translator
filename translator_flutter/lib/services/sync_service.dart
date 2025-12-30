import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/word.dart';

/// Protocol for sync service (for testing)
abstract class SyncServiceProtocol {
  Future<void> upload(List<Word> words);
  Future<List<Word>> download();
  Stream<List<Word>> watchChanges();
  Future<void> deleteWord(String id);
}

/// Firebase Firestore sync service
class SyncService implements SyncServiceProtocol {
  SyncService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Collection name in Firestore
  static const String _collectionName = 'words';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  @override
  Future<void> upload(List<Word> words) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (final word in words) {
      final docRef = _collection.doc(word.id);
      final data = word.copyWith(syncedAt: now).toJson();

      // Convert DateTime to Timestamp for Firestore
      data['createdAt'] = Timestamp.fromDate(word.createdAt);
      data['syncedAt'] = Timestamp.fromDate(now);

      batch.set(docRef, data, SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<List<Word>> download() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return _wordFromFirestore(data);
    }).toList();
  }

  @override
  Stream<List<Word>> watchChanges() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _wordFromFirestore(data);
      }).toList();
    });
  }

  @override
  Future<void> deleteWord(String id) async {
    await _collection.doc(id).delete();
  }

  /// Convert Firestore document to Word
  Word _wordFromFirestore(Map<String, dynamic> data) {
    // Convert Timestamp to DateTime
    final createdAt = data['createdAt'];
    final syncedAt = data['syncedAt'];

    final jsonData = Map<String, dynamic>.from(data);

    if (createdAt is Timestamp) {
      jsonData['createdAt'] = createdAt.toDate().toIso8601String();
    }
    if (syncedAt is Timestamp) {
      jsonData['syncedAt'] = syncedAt.toDate().toIso8601String();
    }

    return Word.fromJson(jsonData);
  }
}

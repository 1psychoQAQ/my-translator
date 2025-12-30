import 'package:mockito/annotations.dart';
import 'package:translator_flutter/repositories/word_repository.dart';
import 'package:translator_flutter/services/sync_service.dart';

@GenerateMocks([
  SyncService,
  WordRepository,
])
void main() {}

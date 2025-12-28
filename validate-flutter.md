# Flutter App 验收规范

## 技术栈

| 组件 | 技术 |
|-----|------|
| 框架 | Flutter 3.x |
| 语言 | Dart |
| 状态管理 | Riverpod（推荐）或 Provider |
| 云同步 | Firebase Firestore |
| 测试 | flutter_test + mockito |

---

## 模块职责

| 模块 | 职责 | 位置 |
|-----|------|------|
| `Word` | 数据模型 | `lib/models/` |
| `SyncService` | Firebase 同步 | `lib/services/` |
| `WordRepository` | 本地 + 远程数据源 | `lib/repositories/` |
| `WordBookNotifier` | 状态管理 | `lib/providers/` |
| `WordBookScreen` | UI | `lib/screens/` |

---

## 依赖注入

使用 **Riverpod** 进行依赖注入：

### Provider 定义

```dart
// lib/providers/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 服务层 Provider
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return SyncService(firestore);
});

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return WordRepository(syncService);
});

// 状态 Provider
final wordBookProvider = StateNotifierProvider<WordBookNotifier, WordBookState>((ref) {
  final repository = ref.watch(wordRepositoryProvider);
  return WordBookNotifier(repository);
});
```

### 接口定义

```dart
// lib/services/sync_service.dart
abstract class SyncServiceProtocol {
  Future<void> upload(List<Word> words);
  Future<List<Word>> download();
  Stream<List<Word>> watchChanges();
}

class SyncService implements SyncServiceProtocol {
  final FirebaseFirestore _firestore;

  SyncService(this._firestore);

  @override
  Future<void> upload(List<Word> words) async {
    // 实现
  }

  @override
  Future<List<Word>> download() async {
    // 实现
  }

  @override
  Stream<List<Word>> watchChanges() {
    // 实现
  }
}
```

### 测试时覆盖

```dart
// 测试时可以覆盖 Provider
void main() {
  testWidgets('word book displays words', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncServiceProvider.overrideWithValue(MockSyncService()),
        ],
        child: const MyApp(),
      ),
    );
  });
}
```

---

## 错误处理

### Result 模式

```dart
// lib/core/result.dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}

// 扩展方法
extension ResultExtension<T> on Result<T> {
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final error) => failure(error),
    };
  }
}
```

### 错误类型

```dart
// lib/core/errors.dart
sealed class AppError {
  final String message;
  final Object? cause;

  const AppError(this.message, [this.cause]);
}

class SyncError extends AppError {
  const SyncError(super.message, [super.cause]);
}

class NetworkError extends AppError {
  const NetworkError(super.message, [super.cause]);
}

class StorageError extends AppError {
  const StorageError(super.message, [super.cause]);
}
```

### 使用示例

```dart
// ✅ 显式处理
class WordRepository {
  Future<Result<List<Word>>> fetchWords() async {
    try {
      final words = await _syncService.download();
      return Success(words);
    } on FirebaseException catch (e) {
      return Failure(SyncError('同步失败', e));
    } catch (e) {
      return Failure(NetworkError('网络错误', e));
    }
  }
}

// ✅ UI 层处理
class WordBookScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wordBookProvider);

    return state.when(
      loading: () => const CircularProgressIndicator(),
      error: (error) => ErrorWidget(message: error.message),
      data: (words) => WordList(words: words),
    );
  }
}

// ❌ 禁止静默失败
Future<List<Word>> badFetch() async {
  try {
    return await _syncService.download();
  } catch (_) {
    return [];  // 用户不知道出错了
  }
}
```

---

## 测试规范

### 框架

- 单元测试：`flutter_test`
- Mock：`mockito` + `build_runner`
- Widget 测试：`flutter_test`

### Mock 生成

```dart
// test/mocks.dart
import 'package:mockito/annotations.dart';

@GenerateMocks([
  SyncService,
  WordRepository,
])
void main() {}

// 运行: flutter pub run build_runner build
```

### 单元测试示例

```dart
// test/services/sync_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../mocks.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFirestore;
  late SyncService syncService;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    syncService = SyncService(mockFirestore);
  });

  group('SyncService', () {
    test('upload should batch write words', () async {
      final words = [Word(text: 'hello', translation: '你好')];

      await syncService.upload(words);

      verify(mockFirestore.batch()).called(1);
    });

    test('download should return words from firestore', () async {
      // 设置 mock 返回值
      when(mockFirestore.collection('words').get())
          .thenAnswer((_) async => mockQuerySnapshot);

      final result = await syncService.download();

      expect(result, isNotEmpty);
    });
  });
}
```

### Repository 测试

```dart
// test/repositories/word_repository_test.dart
void main() {
  late MockSyncService mockSyncService;
  late WordRepository repository;

  setUp(() {
    mockSyncService = MockSyncService();
    repository = WordRepository(mockSyncService);
  });

  test('fetchWords returns Success on success', () async {
    when(mockSyncService.download())
        .thenAnswer((_) async => [Word(text: 'test', translation: '测试')]);

    final result = await repository.fetchWords();

    expect(result, isA<Success<List<Word>>>());
  });

  test('fetchWords returns Failure on error', () async {
    when(mockSyncService.download())
        .thenThrow(FirebaseException(plugin: 'firestore'));

    final result = await repository.fetchWords();

    expect(result, isA<Failure<List<Word>>>());
  });
}
```

### Widget 测试

```dart
// test/screens/word_book_screen_test.dart
void main() {
  testWidgets('displays loading indicator', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wordBookProvider.overrideWith(
            (ref) => WordBookNotifier.loading(),
          ),
        ],
        child: const MaterialApp(home: WordBookScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('displays words when loaded', (tester) async {
    final words = [Word(text: 'hello', translation: '你好')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wordBookProvider.overrideWith(
            (ref) => WordBookNotifier.loaded(words),
          ),
        ],
        child: const MaterialApp(home: WordBookScreen()),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);
  });
}
```

### 覆盖要求

| 模块 | 测试场景 | 覆盖率 |
|-----|---------|--------|
| `SyncService` | 上传、下载、监听、错误 | 100% |
| `WordRepository` | 获取、缓存、错误处理 | 100% |
| `WordBookNotifier` | 状态转换、操作 | 100% |
| `WordBookScreen` | 加载、显示、交互 | 关键路径 |

---

## 代码规范

### 分析配置

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    prefer_final_locals: true
    always_declare_return_types: true
```

### 命名规范

```dart
// ✅ 清晰
class WordBookNotifier extends StateNotifier<WordBookState> {}
Future<Result<List<Word>>> fetchAllWords() async {}
final bool isLoading;

// ❌ 模糊
class Manager {}
Future<dynamic> getData() async {}
var x = true;
```

### 状态管理规范

```dart
// ✅ 不可变状态
@freezed
class WordBookState with _$WordBookState {
  const factory WordBookState.loading() = _Loading;
  const factory WordBookState.loaded(List<Word> words) = _Loaded;
  const factory WordBookState.error(AppError error) = _Error;
}

// ✅ StateNotifier 处理状态
class WordBookNotifier extends StateNotifier<WordBookState> {
  final WordRepository _repository;

  WordBookNotifier(this._repository) : super(const WordBookState.loading()) {
    _load();
  }

  Future<void> _load() async {
    final result = await _repository.fetchWords();
    state = result.when(
      success: (words) => WordBookState.loaded(words),
      failure: (error) => WordBookState.error(error),
    );
  }
}
```

### 项目结构

```
lib/
├── core/
│   ├── errors.dart
│   └── result.dart
├── models/
│   └── word.dart
├── services/
│   └── sync_service.dart
├── repositories/
│   └── word_repository.dart
├── providers/
│   └── providers.dart
├── screens/
│   ├── word_book_screen.dart
│   └── word_detail_screen.dart
├── widgets/
│   ├── word_card.dart
│   └── search_bar.dart
└── main.dart
```

---

## 验收检查清单

### Phase 4: 单词本 + 同步

- [ ] 项目结构符合规范
- [ ] Riverpod 依赖注入配置正确
- [ ] `Word` 模型定义（含 fromJson/toJson）
- [ ] `SyncService` 实现 Firebase 同步
- [ ] `WordRepository` 实现 Result 模式
- [ ] `WordBookNotifier` 状态管理正确
- [ ] 单词列表页面显示
- [ ] 单词搜索功能
- [ ] 单词详情页面
- [ ] 下拉刷新同步
- [ ] 离线状态提示
- [ ] 离线数据本地缓存
- [ ] 在线后自动同步
- [ ] 冲突处理（以时间戳为准）
- [ ] 错误处理：同步失败有 SnackBar 提示
- [ ] 错误处理：网络错误有提示
- [ ] 单元测试：SyncService 100% 覆盖
- [ ] 单元测试：WordRepository 100% 覆盖
- [ ] Widget 测试：关键页面覆盖

### iOS 特定

- [ ] iOS 模拟器运行正常
- [ ] iOS 真机运行正常
- [ ] iOS 权限配置（如需要）

### Android 特定

- [ ] Android 模拟器运行正常
- [ ] Android 真机运行正常
- [ ] Android 权限配置（如需要）
- [ ] minSdkVersion 配置合理

### 通用检查

- [ ] 无 `print()` 遗留（使用 logger）
- [ ] 无 `dynamic` 类型滥用
- [ ] `flutter analyze` 无警告
- [ ] `flutter test` 全部通过

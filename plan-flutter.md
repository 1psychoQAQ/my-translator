# Flutter App 开发计划

## 概述

**目标**: 实现跨平台单词本App，支持iOS/Android，与macOS App通过Firebase Firestore同步

**技术栈**: Flutter 3.x + Riverpod + Firebase Firestore + freezed

**依赖关系**: 需要macOS App先完成Phase 4的SyncService，以确保数据模型和同步逻辑一致

---

## 开发阶段

### 阶段 1: 项目初始化

| 任务 | 说明 |
|-----|------|
| 创建Flutter项目 | `flutter create translator_flutter` |
| 配置分析选项 | `analysis_options.yaml` |
| 添加核心依赖 | riverpod, freezed, firebase |
| 配置Firebase | iOS/Android Firebase配置 |

**产出**:
- `translator_flutter/` 项目骨架
- Firebase配置完成
- 依赖安装完成

---

### 阶段 2: 核心模块

#### 2.1 数据模型

```
lib/models/word.dart
```

| 字段 | 类型 | 说明 |
|-----|------|------|
| id | String | UUID |
| text | String | 原文 |
| translation | String | 译文 |
| source | String | 来源(webpage/video/screenshot) |
| sourceURL | String? | 来源URL |
| tags | List<String> | 标签 |
| createdAt | DateTime | 创建时间 |
| syncedAt | DateTime? | 同步时间 |

#### 2.2 错误处理

```
lib/core/errors.dart
lib/core/result.dart
```

- `AppError` sealed class
- `Result<T>` sealed class (Success/Failure)

#### 2.3 同步服务

```
lib/services/sync_service.dart
```

| 方法 | 功能 |
|-----|------|
| `upload(List<Word>)` | 上传单词到Firestore |
| `download()` | 从Firestore下载单词 |
| `watchChanges()` | 监听Firestore变化(实时同步) |

#### 2.4 数据仓库

```
lib/repositories/word_repository.dart
```

| 方法 | 功能 |
|-----|------|
| `fetchWords()` | 获取单词列表(Result模式) |
| `addWord(Word)` | 添加单词 |
| `updateWord(Word)` | 更新单词 |
| `deleteWord(String id)` | 删除单词 |
| `searchWords(String query)` | 搜索单词 |

#### 2.5 状态管理

```
lib/providers/providers.dart
```

- `firebaseFirestoreProvider`
- `syncServiceProvider`
- `wordRepositoryProvider`
- `wordBookProvider` (StateNotifierProvider)

**产出**:
- Word模型(freezed生成)
- Result模式错误处理
- SyncService与Firebase连通
- WordRepository封装数据操作
- Riverpod Provider配置

---

### 阶段 3: UI实现

#### 3.1 单词列表页

```
lib/screens/word_book_screen.dart
```

功能:
- 单词卡片列表
- 下拉刷新同步
- 搜索栏
- 加载/错误/空状态

#### 3.2 单词详情页

```
lib/screens/word_detail_screen.dart
```

功能:
- 显示完整单词信息
- 编辑标签
- 删除单词

#### 3.3 组件

```
lib/widgets/word_card.dart
lib/widgets/search_bar.dart
```

**产出**:
- 完整UI界面
- 下拉刷新功能
- 搜索功能

---

### 阶段 4: 离线支持

| 任务 | 说明 |
|-----|------|
| 本地缓存 | 使用Hive或SQLite缓存 |
| 离线队列 | 离线操作暂存 |
| 网络状态监听 | connectivity_plus |
| 自动同步 | 网络恢复后自动上传 |
| 冲突处理 | 以syncedAt时间戳为准 |

**产出**:
- 离线可用
- 网络恢复自动同步
- 冲突自动合并

---

### 阶段 5: 测试

| 测试类型 | 覆盖范围 | 覆盖率 |
|---------|---------|--------|
| 单元测试 | SyncService | 100% |
| 单元测试 | WordRepository | 100% |
| 单元测试 | WordBookNotifier | 100% |
| Widget测试 | WordBookScreen | 关键路径 |
| Widget测试 | WordDetailScreen | 关键路径 |

**产出**:
- 全面测试覆盖
- CI通过

---

## 文件结构

```
translator_flutter/
├── lib/
│   ├── core/
│   │   ├── errors.dart          # 错误类型定义
│   │   └── result.dart          # Result模式
│   ├── models/
│   │   └── word.dart            # Word模型(freezed)
│   ├── services/
│   │   └── sync_service.dart    # Firebase同步服务
│   ├── repositories/
│   │   └── word_repository.dart # 数据仓库
│   ├── providers/
│   │   └── providers.dart       # Riverpod providers
│   ├── screens/
│   │   ├── word_book_screen.dart    # 单词列表页
│   │   └── word_detail_screen.dart  # 单词详情页
│   ├── widgets/
│   │   ├── word_card.dart       # 单词卡片组件
│   │   └── search_bar.dart      # 搜索栏组件
│   └── main.dart                # 入口
├── test/
│   ├── mocks.dart               # Mock定义
│   ├── services/
│   │   └── sync_service_test.dart
│   ├── repositories/
│   │   └── word_repository_test.dart
│   └── screens/
│       └── word_book_screen_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

---

## 依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.x
  firebase_core: ^2.x
  cloud_firestore: ^4.x
  freezed_annotation: ^2.x
  json_annotation: ^4.x
  connectivity_plus: ^5.x  # 网络状态

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.x
  build_runner: ^2.x
  freezed: ^2.x
  json_serializable: ^6.x
  mockito: ^5.x
```

---

## 验收检查清单

参考 [validate-flutter.md](./validate-flutter.md#phase-4-单词本--同步)

### 功能验收
- [ ] 单词列表显示
- [ ] 单词搜索功能
- [ ] 单词详情查看
- [ ] 下拉刷新同步
- [ ] 离线状态提示
- [ ] 离线数据缓存
- [ ] 在线后自动同步
- [ ] 冲突处理(时间戳策略)

### 技术验收
- [ ] Riverpod依赖注入配置正确
- [ ] Word模型(freezed生成)
- [ ] Result模式错误处理
- [ ] 无print()遗留
- [ ] 无dynamic类型滥用
- [ ] flutter analyze无警告
- [ ] flutter test全部通过

### 测试验收
- [ ] SyncService 100%覆盖
- [ ] WordRepository 100%覆盖
- [ ] WordBookNotifier 100%覆盖
- [ ] Widget测试关键路径覆盖

### 平台验收
- [ ] iOS模拟器运行正常
- [ ] iOS真机运行正常
- [ ] Android模拟器运行正常
- [ ] Android真机运行正常

---

## 协作要点

### 与macOS App协作

1. **数据模型一致**: Word字段定义需与macOS Swift版本一致
2. **Firestore集合**: 约定使用 `words` 集合
3. **同步策略**:
   - 使用 `syncedAt` 字段判断同步状态
   - 冲突以较新的 `syncedAt` 为准

### Firestore数据结构

```
/words/{wordId}
  - id: string
  - text: string
  - translation: string
  - source: string
  - sourceURL: string?
  - tags: array<string>
  - createdAt: timestamp
  - syncedAt: timestamp?
```

---

## 开始条件

1. macOS App Phase 1-3 完成(单词本基础功能)
2. Firebase项目已创建
3. Firestore数据结构已确定

## 当前状态

等待macOS App进展到Phase 4，或可先并行开发Flutter端基础框架

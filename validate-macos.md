# macOS App 验收规范

## 技术栈

| 组件 | 技术 |
|-----|------|
| UI | SwiftUI |
| 存储 | SwiftData |
| 翻译 | Translation Framework |
| OCR | Vision Framework |
| 截图 | ScreenCaptureKit |
| 通信 | Native Messaging Host |

---

## 模块职责

| 模块 | 职责 | 输入 | 输出 |
|-----|------|-----|------|
| `TranslationService` | 只做翻译 | String | String |
| `OCRService` | 只做 OCR | CGImage | String |
| `WordBookManager` | 只做 CRUD | Word | Result |
| `SyncService` | 只做同步 | [Word] | SyncStatus |
| `ScreenshotService` | 只做截图 | CGRect | CGImage |
| `NativeMessagingHost` | 只做消息收发 | Data | Data |

---

## 依赖注入

### 协议定义

```swift
protocol TranslationServiceProtocol {
    func translate(_ text: String) async throws -> String
}

protocol OCRServiceProtocol {
    func extractText(from image: CGImage) throws -> String
}

protocol WordBookManagerProtocol {
    func save(_ word: Word) throws
    func delete(_ word: Word) throws
    func fetchAll() throws -> [Word]
    func search(_ keyword: String) throws -> [Word]
}

protocol SyncServiceProtocol {
    func upload(_ words: [Word]) async throws
    func download() async throws -> [Word]
}
```

### 注入方式

```swift
// ✅ 构造器注入
class ScreenshotTranslateViewModel: ObservableObject {
    private let ocrService: OCRServiceProtocol
    private let translationService: TranslationServiceProtocol

    init(
        ocrService: OCRServiceProtocol,
        translationService: TranslationServiceProtocol
    ) {
        self.ocrService = ocrService
        self.translationService = translationService
    }
}

// ❌ 禁止直接实例化
class BadViewModel {
    private let ocrService = OCRService()  // 紧耦合
}
```

---

## 错误处理

### 错误类型

```swift
enum TranslatorError: LocalizedError {
    case ocrFailed(reason: String)
    case translationFailed(reason: String)
    case syncFailed(reason: String)
    case nativeMessageFailed(reason: String)
    case screenshotFailed(reason: String)
    case wordBookError(reason: String)

    var errorDescription: String? {
        switch self {
        case .ocrFailed(let reason): return "OCR 失败: \(reason)"
        case .translationFailed(let reason): return "翻译失败: \(reason)"
        case .syncFailed(let reason): return "同步失败: \(reason)"
        case .nativeMessageFailed(let reason): return "通信失败: \(reason)"
        case .screenshotFailed(let reason): return "截图失败: \(reason)"
        case .wordBookError(let reason): return "单词本错误: \(reason)"
        }
    }
}
```

### 处理规范

```swift
// ✅ 显式处理
do {
    let text = try ocrService.extractText(from: image)
    let translation = try await translationService.translate(text)
    await MainActor.run { self.result = translation }
} catch {
    await MainActor.run { self.errorMessage = error.localizedDescription }
}

// ❌ 禁止静默失败
let text = try? ocrService.extractText(from: image) ?? ""  // 错误被吞掉
```

---

## 测试规范

### 框架

- 单元测试：XCTest
- Mock：手写 Mock 或 swift-testing

### Mock 示例

```swift
class MockTranslationService: TranslationServiceProtocol {
    var mockResult = "mock"
    var shouldThrow = false
    var translateCallCount = 0

    func translate(_ text: String) async throws -> String {
        translateCallCount += 1
        if shouldThrow {
            throw TranslatorError.translationFailed(reason: "mock error")
        }
        return mockResult
    }
}

class MockOCRService: OCRServiceProtocol {
    var mockText = "Hello"
    var shouldThrow = false

    func extractText(from image: CGImage) throws -> String {
        if shouldThrow {
            throw TranslatorError.ocrFailed(reason: "mock error")
        }
        return mockText
    }
}
```

### 测试用例

```swift
final class TranslationServiceTests: XCTestCase {

    func testTranslateSuccess() async throws {
        let service = TranslationService()
        let result = try await service.translate("Hello")
        XCTAssertFalse(result.isEmpty)
    }

    func testTranslateEmptyText() async throws {
        let service = TranslationService()
        do {
            _ = try await service.translate("")
            XCTFail("Should throw error for empty text")
        } catch {
            // Expected
        }
    }
}

final class ScreenshotTranslateViewModelTests: XCTestCase {

    func testTranslateFlow() async throws {
        let mockOCR = MockOCRService()
        mockOCR.mockText = "Hello"

        let mockTranslation = MockTranslationService()
        mockTranslation.mockResult = "你好"

        let vm = ScreenshotTranslateViewModel(
            ocrService: mockOCR,
            translationService: mockTranslation
        )

        // Test flow...
    }
}
```

### 覆盖要求

| 模块 | 测试场景 | 覆盖率 |
|-----|---------|--------|
| `TranslationService` | 空文本、长文本、特殊字符 | 100% |
| `OCRService` | 清晰图、模糊图、无文字图 | 100% |
| `WordBookManager` | 增删改查、重复、搜索 | 100% |
| `SyncService` | 上传、下载、冲突、离线 | 关键路径 |
| `ScreenshotService` | 全屏、区域、权限拒绝 | 关键路径 |

---

## 代码规范

### 命名

```swift
// ✅ 清晰
func translateText(_ text: String) async throws -> String
func saveWord(_ word: Word) throws
var isTranslating: Bool

// ❌ 模糊
func process(_ input: Any) -> Any
func handle(_ data: Data)
var flag: Bool
```

### 异步处理

```swift
// ✅ 使用 async/await
func translate(_ text: String) async throws -> String {
    return try await translator.translate(from: .english, to: .chinese, text: text)
}

// ✅ UI 更新在主线程
await MainActor.run {
    self.result = translation
}
```

### SwiftUI 规范

```swift
// ✅ ViewModel 注入
struct WordBookView: View {
    @StateObject private var viewModel: WordBookViewModel

    init(viewModel: WordBookViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}

// ✅ 环境对象用于共享状态
@EnvironmentObject var appState: AppState
```

---

## 验收检查清单

### Phase 1: 截图翻译 + 单词本

- [ ] `TranslationService` 单元测试通过
- [ ] `OCRService` 单元测试通过
- [ ] `WordBookManager` 单元测试通过
- [ ] `ScreenshotService` 能正常截图
- [ ] 截图翻译集成测试：截图 → OCR → 翻译 → 显示
- [ ] 快捷键 Cmd+Shift+T 触发截图
- [ ] 翻译结果悬浮窗显示
- [ ] 单词本 CRUD 功能正常
- [ ] 错误处理：OCR 失败有 Alert 提示
- [ ] 错误处理：翻译失败有 Alert 提示
- [ ] 错误处理：截图权限拒绝有引导

### Phase 2: Native Messaging

- [ ] `NativeMessagingHost` 能接收 Chrome 消息
- [ ] `NativeMessagingHost` 能返回翻译结果
- [ ] 收藏单词写入本地 SwiftData
- [ ] 错误处理：通信异常有日志

### Phase 3: 视频字幕

- [ ] 悬浮字幕窗口能显示
- [ ] 字幕窗口可拖动
- [ ] 字幕窗口可调整透明度
- [ ] 字幕实时更新

### Phase 4: 同步

- [ ] `SyncService` 能上传到 Firebase
- [ ] `SyncService` 能从 Firebase 下载
- [ ] 离线修改能暂存
- [ ] 在线后自动同步
- [ ] 冲突合并逻辑正确（以时间戳为准）

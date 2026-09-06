import Foundation
import SwiftUI
import SwiftData
import AppKit
import Carbon

@MainActor
final class AppState: ObservableObject {

    /// 静态引用，供 CGEventTap 回调使用
    static weak var shared: AppState?

    let modelContainer: ModelContainer
    let wordBookManager: WordBookManagerProtocol
    let screenshotTranslateViewModel: ScreenshotTranslateViewModel

    private var hotKeyRef: EventHotKeyRef?
    private var aiHotKeyRef: EventHotKeyRef?
    private var blankAskHotKeyRef: EventHotKeyRef?
    private var defineHotKeyRef: EventHotKeyRef?

    nonisolated init() throws {
        // Initialize SwiftData - this is thread-safe
        let schema = Schema([Word.self])

        // Use explicit path for data storage
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = "com.translator.app"
        let storeURL = appSupportURL
            .appendingPathComponent(bundleID)
            .appendingPathComponent("default.store")

        // Ensure directory exists
        let storeDir = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let modelConfiguration = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        self.modelContainer = container

        // These will be set up on MainActor
        self.wordBookManager = PlaceholderWordBookManager()
        self.screenshotTranslateViewModel = ScreenshotTranslateViewModel.placeholder
    }

    func configure() {
        // 设置静态引用
        AppState.shared = self

        // Initialize services on MainActor
        let modelContext = modelContainer.mainContext
        let manager = WordBookManager(modelContext: modelContext)

        let screenshotService = ScreenshotService()
        let ocrService = OCRService()

        let translationService: TranslationServiceProtocol
        if #available(macOS 15.0, *) {
            translationService = TranslationService()
        } else {
            translationService = LegacyTranslationService()
        }

        // Update the view model with real dependencies
        screenshotTranslateViewModel.configure(
            screenshotService: screenshotService,
            ocrService: ocrService,
            translationService: translationService,
            wordBookManager: manager
        )

        // Store manager reference (we'll update this pattern)
        (wordBookManager as? PlaceholderWordBookManager)?.realManager = manager
    }

    func setupGlobalHotkey() {
        // 检查辅助功能权限（用于全局快捷键监听）
        let permissions = PermissionsManager.shared
        if !permissions.hasAccessibilityPermission {
            print("⚠️ 缺少辅助功能权限，快捷键可能无法正常工作")
            // 不阻止继续，让用户可以通过菜单使用
        }
        let settings = HotkeySettings.shared
        print("🔑 Setting up global hotkey (\(settings.displayString)) with Carbon API...")

        // 安装事件处理器（处理所有快捷键）
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                // 获取快捷键 ID
                var hotkeyID = EventHotKeyID()
                GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

                DispatchQueue.main.async {
                    if hotkeyID.id == 1 {
                        // 截图翻译快捷键
                        print("🎯 Screenshot hotkey triggered!")
                        Task { @MainActor in
                            await AppState.shared?.screenshotTranslateViewModel.startScreenshotTranslation()
                        }
                    } else if hotkeyID.id == 2 {
                        // 划词翻译快捷键
                        print("🎯 Translation hotkey triggered!")
                        AppDelegate.triggerTranslation()
                    } else if hotkeyID.id == 3 {
                        // 选择文本提问快捷键
                        print("🤖 AI hotkey triggered!")
                        AppDelegate.triggerAIQuestion()
                    } else if hotkeyID.id == 4 {
                        // 空白提问快捷键
                        print("🤖 Blank AI hotkey triggered!")
                        AppDelegate.triggerBlankAIQuestion()
                    } else if hotkeyID.id == 5 {
                        // 关键词释义快捷键
                        print("📖 Definition hotkey triggered!")
                        AppDelegate.triggerDefine()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        if status != noErr {
            print("❌ Failed to install event handler: \(status)")
            return
        }

        // 注册热键（从设置读取）
        registerHotkey()

        // 监听快捷键变更
        NotificationCenter.default.addObserver(
            forName: .hotkeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerHotkey()
        }
    }

    private func registerHotkey() {
        // 先注销旧的热键
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = aiHotKeyRef {
            UnregisterEventHotKey(ref)
            aiHotKeyRef = nil
        }
        if let ref = blankAskHotKeyRef {
            UnregisterEventHotKey(ref)
            blankAskHotKeyRef = nil
        }
        if let ref = defineHotKeyRef {
            UnregisterEventHotKey(ref)
            defineHotKeyRef = nil
        }

        let settings = HotkeySettings.shared
        var hotKeyID = EventHotKeyID(signature: OSType(0x54535450), id: 1) // "TSTP"

        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            settings.screenshotKeyCode,
            settings.screenshotModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if regStatus != noErr {
            print("❌ Failed to register hotkey: \(regStatus)")
        } else {
            self.hotKeyRef = ref
            print("✅ Global hotkey registered (\(settings.displayString))")
        }

        // 注册 AI 提问热键
        var aiRef: EventHotKeyRef?
        let aiHotKeyID = EventHotKeyID(signature: OSType(0x54535450), id: 3) // "TSTP"
        let aiRegStatus = RegisterEventHotKey(
            settings.aiKeyCode,
            settings.aiModifiers,
            aiHotKeyID,
            GetApplicationEventTarget(),
            0,
            &aiRef
        )

        if aiRegStatus != noErr {
            print("❌ Failed to register AI hotkey: \(aiRegStatus)")
        } else {
            self.aiHotKeyRef = aiRef
            print("✅ AI hotkey registered (\(settings.aiDisplayString))")
        }

        // 注册空白提问热键
        var blankAskRef: EventHotKeyRef?
        let blankAskHotKeyID = EventHotKeyID(signature: OSType(0x54535450), id: 4) // "TSTP"
        let blankAskRegStatus = RegisterEventHotKey(
            settings.blankAskKeyCode,
            settings.blankAskModifiers,
            blankAskHotKeyID,
            GetApplicationEventTarget(),
            0,
            &blankAskRef
        )

        if blankAskRegStatus != noErr {
            print("❌ Failed to register blank ask hotkey: \(blankAskRegStatus)")
        } else {
            self.blankAskHotKeyRef = blankAskRef
            print("✅ Blank ask hotkey registered (\(settings.blankAskDisplayString))")
        }

        // 注册关键词释义热键
        var defineRef: EventHotKeyRef?
        let defineHotKeyID = EventHotKeyID(signature: OSType(0x54535450), id: 5) // "TSTP"
        let defineRegStatus = RegisterEventHotKey(
            settings.defineKeyCode,
            settings.defineModifiers,
            defineHotKeyID,
            GetApplicationEventTarget(),
            0,
            &defineRef
        )

        if defineRegStatus != noErr {
            print("❌ Failed to register define hotkey: \(defineRegStatus)")
        } else {
            self.defineHotKeyRef = defineRef
            print("✅ Define hotkey registered (\(settings.defineDisplayString))")
        }
    }

    func removeHotkeyMonitor() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = aiHotKeyRef {
            UnregisterEventHotKey(ref)
            aiHotKeyRef = nil
        }
        if let ref = blankAskHotKeyRef {
            UnregisterEventHotKey(ref)
            blankAskHotKeyRef = nil
        }
        if let ref = defineHotKeyRef {
            UnregisterEventHotKey(ref)
            defineHotKeyRef = nil
        }
        NotificationCenter.default.removeObserver(self, name: .hotkeyChanged, object: nil)
    }

    func createWordBookViewModel() -> WordBookViewModel {
        let modelContext = modelContainer.mainContext
        let manager = WordBookManager(modelContext: modelContext)
        return WordBookViewModel(wordBookManager: manager)
    }
}

// MARK: - Placeholder for deferred initialization

private class PlaceholderWordBookManager: WordBookManagerProtocol {
    var realManager: WordBookManagerProtocol?

    func save(_ word: Word) throws {
        try realManager?.save(word)
    }

    func saveAll(_ words: [Word], skipDuplicates: Bool) throws -> Int {
        try realManager?.saveAll(words, skipDuplicates: skipDuplicates) ?? 0
    }

    func delete(_ word: Word) throws {
        try realManager?.delete(word)
    }

    func deleteAll() throws {
        try realManager?.deleteAll()
    }

    func fetchAll() throws -> [Word] {
        try realManager?.fetchAll() ?? []
    }

    func search(_ keyword: String) throws -> [Word] {
        try realManager?.search(keyword) ?? []
    }
}

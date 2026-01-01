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

    nonisolated init() throws {
        // Initialize SwiftData - this is thread-safe
        let schema = Schema([Word.self])

        // Use explicit path to share data with NativeMessagingHost
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

        // 安装事件处理器
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                print("🎯 Hotkey triggered!")
                DispatchQueue.main.async {
                    Task { @MainActor in
                        await AppState.shared?.screenshotTranslateViewModel.startScreenshotTranslation()
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
            return
        }

        self.hotKeyRef = ref
        print("✅ Global hotkey registered (\(settings.displayString))")
    }

    func removeHotkeyMonitor() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
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

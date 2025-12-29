import Foundation
import SwiftUI
import SwiftData
import AppKit
import ScreenCaptureKit
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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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

        // Request screen capture permission on startup
        Task {
            await requestScreenCapturePermission()
        }
    }

    /// Check and request screen capture permission
    private func requestScreenCapturePermission() async {
        print("🔒 Checking screen capture permission...")

        // Check if permission is already granted
        let hasPermission = await checkScreenCapturePermission()

        if hasPermission {
            print("✅ Screen capture permission granted")
            // Clear the alert flag since permission is granted
            UserDefaults.standard.removeObject(forKey: "hasShownScreenCaptureAlert")
            return
        }

        print("⚠️ Screen capture permission not granted")
        print("💡 Please enable in: System Settings → Privacy & Security → Screen Recording")

        // Only show alert once per app launch session if not already shown
        let hasShownAlert = UserDefaults.standard.bool(forKey: "hasShownScreenCaptureAlert")
        if hasShownAlert {
            print("ℹ️ Permission alert already shown, skipping...")
            return
        }

        // Mark that we've shown the alert
        UserDefaults.standard.set(true, forKey: "hasShownScreenCaptureAlert")

        // Show alert to guide user
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "需要屏幕录制权限"
            alert.informativeText = "请在「系统设置  → 隐私与安全性 → 屏幕录制」中允许此应用。\n\n授权后请重启应用。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后")

            if alert.runModal() == .alertFirstButtonReturn {
                // Open System Settings to Screen Recording
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    /// Check if screen capture permission is granted without triggering request
    private func checkScreenCapturePermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }

    func setupGlobalHotkey() {
        print("🔑 Setting up global hotkey (⌘+⇧+S) with Carbon API...")

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

        // 注册热键: ⌘+⇧+S
        // S 的 keyCode = 1 (kVK_ANSI_S)
        var hotKeyID = EventHotKeyID(signature: OSType(0x54535450), id: 1) // "TSTP"
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            modifiers,
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
        print("✅ Global hotkey registered (⌘+⇧+S)")
    }

    func removeHotkeyMonitor() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
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

    func delete(_ word: Word) throws {
        try realManager?.delete(word)
    }

    func fetchAll() throws -> [Word] {
        try realManager?.fetchAll() ?? []
    }

    func search(_ keyword: String) throws -> [Word] {
        try realManager?.search(keyword) ?? []
    }
}

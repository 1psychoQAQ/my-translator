import SwiftUI
import SwiftData
import AppKit
import Carbon.HIToolbox

// Global app state - initialized once
let globalAppState: AppState = {
    do {
        return try AppState()
    } catch {
        fatalError("Failed to initialize AppState: \(error)")
    }
}()

@main
struct TranslatorAppApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 单词本窗口
        Window("单词本", id: "wordbook") {
            WordBookWindowContent()
        }
        .defaultSize(width: 500, height: 600)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.presented)  // 启动时自动打开

        Settings {
            SettingsView()
        }
    }
}

/// 存储 openWindow action 的辅助类
@MainActor
final class OpenWindowHelper {
    static let shared = OpenWindowHelper()
    var openWindow: OpenWindowAction?
    private var isOpening = false

    private init() {}

    func openWordBook() {
        // 防止重复打开
        guard !isOpening else {
            print("📬 OpenWindowHelper: 正在打开中，跳过")
            return
        }

        isOpening = true
        print("📬 OpenWindowHelper.openWordBook() called, hasAction=\(openWindow != nil)")
        openWindow?(id: "wordbook")

        // 延迟重置标记
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isOpening = false
        }
    }
}

// MARK: - 单词本窗口内容
struct WordBookWindowContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WordBookView(viewModel: globalAppState.createWordBookViewModel())
            .modelContainer(globalAppState.modelContainer)
            .onAppear {
                // 存储 openWindow action 到全局管理器
                OpenWindowHelper.shared.openWindow = openWindow
                print("✅ OpenWindowHelper.openWindow 已存储")
            }
    }
}

// MARK: - 打开单词本通知
extension Notification.Name {
    static let openWordBook = Notification.Name("openWordBook")
}

// MARK: - AppDelegate with NSStatusItem

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launching...")

        // Create status bar item with fixed width
        statusItem = NSStatusBar.system.statusItem(withLength: 40)
        statusItem.isVisible = true
        print("📍 Status item created: \(statusItem != nil), visible: \(statusItem.isVisible)")

        if let button = statusItem.button {
            button.title = "📖译"
            button.font = NSFont.systemFont(ofSize: 14)
            print("✅ Button configured with title: \(button.title)")
        } else {
            print("❌ Failed to get status item button")
        }

        // Build menu
        let menu = NSMenu()
        let screenshotItem = NSMenuItem(
            title: "截图翻译 (\(HotkeySettings.shared.displayString))",
            action: #selector(startScreenshot),
            keyEquivalent: ""
        )
        screenshotItem.tag = 1  // 用于后续更新
        menu.addItem(screenshotItem)
        menu.addItem(NSMenuItem(title: "翻译选中文本 (⌥T)", action: nil, keyEquivalent: ""))

        let aiAskItem = NSMenuItem(
            title: "选择文本提问 (\(HotkeySettings.shared.aiDisplayString))",
            action: #selector(askAI),
            keyEquivalent: ""
        )
        aiAskItem.tag = 2
        menu.addItem(aiAskItem)

        let blankAskItem = NSMenuItem(
            title: "空白提问 (\(HotkeySettings.shared.blankAskDisplayString))",
            action: #selector(askAIBlank),
            keyEquivalent: ""
        )
        blankAskItem.tag = 3
        menu.addItem(blankAskItem)

        let defineItem = NSMenuItem(
            title: "关键词释义 (\(HotkeySettings.shared.defineDisplayString))",
            action: #selector(defineWord),
            keyEquivalent: ""
        )
        defineItem.tag = 4
        menu.addItem(defineItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "打开单词本", action: #selector(openWordBook), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        print("📋 Menu attached")

        // 监听快捷键变更，更新菜单显示
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuHotkeyDisplay),
            name: .hotkeyChanged,
            object: nil
        )

        // 设置翻译快捷键 ⌥T（选中文本后按快捷键翻译）
        setupTranslationHotkey()

        // Configure app state
        Task { @MainActor in
            globalAppState.configure()
            globalAppState.setupGlobalHotkey()

            // 延迟显示权限引导（让主界面先加载完）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PermissionsWindowController.shared.showIfNeeded()
            }

            // 启动时打开单词本窗口
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.openWordBook()
            }
        }

        print("✅ TranslatorApp initialized")
    }

    @objc func updateMenuHotkeyDisplay() {
        guard let menu = statusItem.menu else { return }
        if let item = menu.item(withTag: 1) {
            item.title = "截图翻译 (\(HotkeySettings.shared.displayString))"
        }
        if let item = menu.item(withTag: 2) {
            item.title = "选择文本提问 (\(HotkeySettings.shared.aiDisplayString))"
        }
        if let item = menu.item(withTag: 3) {
            item.title = "空白提问 (\(HotkeySettings.shared.blankAskDisplayString))"
        }
        if let item = menu.item(withTag: 4) {
            item.title = "关键词释义 (\(HotkeySettings.shared.defineDisplayString))"
        }
    }

    @objc func startScreenshot() {
        Task { @MainActor in
            await globalAppState.screenshotTranslateViewModel.startScreenshotTranslation()
        }
    }

    @objc func askAI() {
        AppDelegate.triggerAIQuestion()
    }

    @objc func askAIBlank() {
        AppDelegate.triggerBlankAIQuestion()
    }

    @objc func defineWord() {
        AppDelegate.triggerDefine()
    }

    private var isOpeningWordBook = false

    @objc func openWordBook() {
        // 防止重复打开
        guard !isOpeningWordBook else {
            print("🔍 正在打开单词本，跳过")
            return
        }
        isOpeningWordBook = true

        // 延迟重置标记
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isOpeningWordBook = false
        }

        // 先激活应用
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 查找已存在的单词本窗口（包括隐藏的）
        for window in NSApplication.shared.windows {
            if window.title == "单词本" ||
               window.identifier?.rawValue.contains("wordbook") == true {
                // 确保窗口可见并置于最前
                print("✅ 找到单词本窗口，显示它")
                window.orderFront(nil)
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        // 窗口不存在时，使用 OpenWindowHelper 打开
        print("⚠️ 未找到单词本窗口，使用 OpenWindowHelper 打开")
        Task { @MainActor in
            OpenWindowHelper.shared.openWordBook()
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            globalAppState.removeHotkeyMonitor()
        }
    }

    // MARK: - 翻译快捷键 ⌥T

    private var translationHotkeyRef: EventHotKeyRef?

    /// 设置翻译快捷键
    private func setupTranslationHotkey() {
        // 注册 ⌥T 快捷键 (Option + T)
        // T 的 keyCode 是 17, Option 修饰符是 optionKey (0x0800)
        let hotkeyID = EventHotKeyID(signature: OSType(0x54524E53), id: 2)  // "TRNS"
        let status = RegisterEventHotKey(
            UInt32(17),  // T
            UInt32(optionKey),  // Option (0x0800)
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &translationHotkeyRef
        )

        if status == noErr {
            print("✅ 翻译快捷键 ⌥T 已注册")
        } else {
            print("❌ 翻译快捷键注册失败: \(status)")
        }
    }

    /// 触发翻译（从剪贴板或模拟复制）
    static func triggerTranslation() {
        print("🔄 triggerTranslation called")

        // 检查辅助功能权限（模拟键盘需要）
        let trusted = AXIsProcessTrusted()
        print("🔐 Accessibility trusted: \(trusted)")

        if !trusted {
            print("⚠️ 需要辅助功能权限才能在其他应用中复制文本")
            // 显示自定义权限引导窗口，不弹系统对话框
            PermissionsWindowController.shared.show()
            return
        }

        // 获取前台应用信息（在模拟复制之前，因为复制后焦点可能变化）
        let sourceInfo = getSourceInfo()
        print("📱 来源: \(sourceInfo.source), URL: \(sourceInfo.url ?? "无")")

        // 先模拟 Cmd+C 复制选中文本
        simulateCopy()

        // 等待剪贴板更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let text = NSPasteboard.general.string(forType: .string),
                  !text.isEmpty else {
                print("❌ 剪贴板为空或获取失败")
                return
            }

            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📋 剪贴板文本: \(trimmedText.prefix(50))...")

            guard !trimmedText.isEmpty, trimmedText.count <= 500 else {
                print("❌ 文本为空或超过500字符")
                return
            }

            // 获取鼠标位置
            let mouseLocation = NSEvent.mouseLocation
            print("📍 鼠标位置: \(mouseLocation)")

            // 显示翻译弹窗
            print("🪟 显示翻译弹窗...")
            TranslationPopupController.shared.show(text: trimmedText, at: mouseLocation) { text, translation in
                print("💾 保存到单词本: \(text) -> \(translation)")
                Task { @MainActor in
                    let word = Word(
                        text: text,
                        translation: translation,
                        source: sourceInfo.source,
                        sourceURL: sourceInfo.url
                    )
                    try? globalAppState.wordBookManager.save(word)
                    print("✅ 已保存到单词本 (来源: \(sourceInfo.source))")
                }
            }
        }
    }

    /// 触发 AI 提问（从剪贴板获取选中文本作为上下文）
    static func triggerAIQuestion() {
        print("🤖 triggerAIQuestion called")

        // 检查辅助功能权限（模拟键盘需要）
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ 需要辅助功能权限才能在其他应用中复制文本")
            PermissionsWindowController.shared.show()
            return
        }

        // 先模拟 Cmd+C 复制选中文本
        simulateCopy()

        // 等待剪贴板更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let text = NSPasteboard.general.string(forType: .string),
                  !text.isEmpty else {
                print("❌ 剪贴板为空或获取失败")
                return
            }

            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                print("❌ 文本为空")
                return
            }

            print("🤖 选中文本: \(trimmedText.prefix(50))...")
            AIChatController.shared.show(context: trimmedText)
        }
    }

    /// 触发空白提问（不复制选中文字，直接打开空白 AI 窗口）
    static func triggerBlankAIQuestion() {
        print("🤖 triggerBlankAIQuestion called")
        DispatchQueue.main.async {
            AIChatController.shared.show(context: nil)
        }
    }

    /// 触发关键词释义（选中文字后直接弹出释义弹窗）
    static func triggerDefine() {
        print("📖 triggerDefine called")

        // 检查辅助功能权限（模拟键盘需要）
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ 需要辅助功能权限才能在其他应用中复制文本")
            PermissionsWindowController.shared.show()
            return
        }

        // 模拟 Cmd+C 复制选中文字
        simulateCopy()

        // 等待剪贴板更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let text = NSPasteboard.general.string(forType: .string),
                  !text.isEmpty else {
                print("❌ 剪贴板为空或获取失败")
                return
            }

            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty, trimmedText.count <= 500 else {
                print("❌ 文本为空或超过500字符")
                return
            }

            print("📖 选中文字: \(trimmedText.prefix(50))...")

            // 未配置 API Key 时，打开 AI 提问窗口引导填写
            if !LLMSettings.shared.isConfigured {
                print("⚠️ 未配置 API Key，打开 AI 提问窗口引导填写")
                AIChatController.shared.show(context: trimmedText)
                return
            }

            // 获取鼠标位置
            let mouseLocation = NSEvent.mouseLocation

            // 显示 AI 释义弹窗
            DefinitionPopupController.shared.show(text: trimmedText, at: mouseLocation)
        }
    }

    /// 获取来源信息（应用名称和 URL）
    private static func getSourceInfo() -> (source: String, url: String?) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return ("selection", nil)
        }

        let bundleID = frontApp.bundleIdentifier ?? ""
        let appName = frontApp.localizedName ?? "Unknown"

        // 浏览器列表
        let browsers: [String: String] = [
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Google Chrome",
            "com.google.Chrome.canary": "Google Chrome Canary",
            "org.chromium.Chromium": "Chromium",
            "com.microsoft.edgemac": "Microsoft Edge",
            "com.brave.Browser": "Brave Browser",
            "company.thebrowser.Browser": "Arc",
            "org.mozilla.firefox": "Firefox",
            "com.operasoftware.Opera": "Opera",
            "com.vivaldi.Vivaldi": "Vivaldi"
        ]

        // 如果是浏览器，尝试获取 URL
        if let browserName = browsers[bundleID] {
            if let url = getBrowserURL(bundleID: bundleID, browserName: browserName) {
                return ("webpage", url)
            }
            // 获取 URL 失败，但仍然标记为 webpage
            return ("webpage", nil)
        }

        // 非浏览器应用，使用应用名称作为 source
        return (appName, nil)
    }

    /// 获取浏览器当前标签页的 URL
    private static func getBrowserURL(bundleID: String, browserName: String) -> String? {
        var script: String

        switch bundleID {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of current tab of front window
                end if
            end tell
            """
        case "org.mozilla.firefox":
            // Firefox 不支持直接获取 URL，返回 nil
            return nil
        default:
            // Chrome 系浏览器（Chrome、Edge、Brave、Arc、Vivaldi、Opera）
            script = """
            tell application "\(browserName)"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        }

        // 执行 AppleScript
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil, let url = result.stringValue, !url.isEmpty {
                return url
            }
        }

        if let error = error {
            print("⚠️ AppleScript 错误: \(error)")
        }

        return nil
    }

    /// 模拟 Cmd+C
    private static func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd + C
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // C key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // CRITICAL: Prevent app from quitting when all windows are closed
    // This is essential for menu bar / status bar apps
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Handle Dock icon click
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 打开单词本
        openWordBook()
        // 返回 false 阻止 SwiftUI 默认行为（否则会打开两个窗口）
        return false
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 420)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var hotkeySettings = HotkeySettings.shared
    @ObservedObject private var llmSettings = LLMSettings.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("截图翻译快捷键")
                    Spacer()
                    Text(hotkeySettings.displayString)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("选择文本提问")
                    Spacer()
                    KeyRecorderView(
                        keyCode: $hotkeySettings.aiKeyCode,
                        modifiers: $hotkeySettings.aiModifiers
                    )
                }
                HStack {
                    Text("空白提问")
                    Spacer()
                    KeyRecorderView(
                        keyCode: $hotkeySettings.blankAskKeyCode,
                        modifiers: $hotkeySettings.blankAskModifiers
                    )
                }
            } header: {
                Text("快捷键")
            }

            Section {
                Picker("供应商", selection: $llmSettings.provider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                HStack {
                    Text("API Key")
                    Spacer()
                    SecureField("sk-...", text: $llmSettings.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }

                Text("API Key 通过 macOS 钥匙串加密存储，仅保存在本机")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("AI 助手")
            }

            Section {
                Text("翻译使用 Apple Translation Framework")
                    .foregroundColor(.secondary)
            } header: {
                Text("翻译引擎")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Translator")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 1.0")
                .foregroundColor(.secondary)

            Text("截图翻译 & 单词本")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

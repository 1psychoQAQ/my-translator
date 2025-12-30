import SwiftUI
import SwiftData
import AppKit

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

        Settings {
            SettingsView()
        }
    }
}

// MARK: - 单词本窗口内容（支持通过通知打开）
struct WordBookWindowContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WordBookView(viewModel: globalAppState.createWordBookViewModel())
            .modelContainer(globalAppState.modelContainer)
            .onReceive(NotificationCenter.default.publisher(for: .openWordBook)) { _ in
                openWindow(id: "wordbook")
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
        menu.addItem(NSMenuItem(title: "截图翻译 (⌘+⇧+S)", action: #selector(startScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "打开单词本", action: #selector(openWordBook), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        print("📋 Menu attached")

        // Configure app state
        Task { @MainActor in
            globalAppState.configure()
            globalAppState.setupGlobalHotkey()
        }

        print("✅ TranslatorApp initialized")
    }

    @objc func startScreenshot() {
        Task { @MainActor in
            await globalAppState.screenshotTranslateViewModel.startScreenshotTranslation()
        }
    }

    @objc func openWordBook() {
        // 先激活应用
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 查找已存在的单词本窗口（包括隐藏的）
        for window in NSApplication.shared.windows {
            if window.title == "单词本" ||
               window.identifier?.rawValue.contains("wordbook") == true {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        // 窗口不存在时，发送通知让 SwiftUI 打开
        NotificationCenter.default.post(name: .openWordBook, object: nil)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            globalAppState.removeHotkeyMonitor()
        }
    }

    // CRITICAL: Prevent app from quitting when all windows are closed
    // This is essential for menu bar / status bar apps
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Handle Dock icon click
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Don't do anything special when Dock icon is clicked
        // Just return true to allow default behavior
        return true
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
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("截图翻译快捷键")
                    Spacer()
                    Text("⌘ + ⇧ + S")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("快捷键")
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

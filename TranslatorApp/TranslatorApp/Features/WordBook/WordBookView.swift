import SwiftUI
import AppKit
import Carbon

struct WordBookView: View {

    @StateObject private var viewModel: WordBookViewModel
    @State private var showingSettings = false

    init(viewModel: WordBookViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                VStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else if viewModel.words.isEmpty {
                        emptyStateView
                    } else {
                        wordListView
                    }
                }

                // 左下角设置按钮
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("设置")
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索单词")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.loadWords()
            }
            .navigationTitle("单词本")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.loadWords() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新")
                }
            }
            .sheet(isPresented: $showingSettings) {
                WordBookSettingsView()
            }
        }
        .onAppear {
            viewModel.loadWords()
        }
    }

    private var wordListView: some View {
        List {
            ForEach(viewModel.words, id: \.id) { word in
                WordRowView(word: word)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteWord(word)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }

                        Button {
                            copyToClipboard(word)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                    }
            }
            .onDelete(perform: viewModel.deleteWords)
        }
        .listStyle(.inset)
    }

    private func copyToClipboard(_ word: Word) {
        let text = "\(word.text)\n\(word.translation)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(viewModel.searchText.isEmpty ? "单词本为空" : "未找到匹配的单词")
                .font(.title3)
                .foregroundColor(.secondary)

            if viewModel.searchText.isEmpty {
                Text("使用截图翻译功能收藏单词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                viewModel.loadWords()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - WordRowView

struct WordRowView: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(word.text)
                .font(.headline)
                .lineLimit(2)

            Text(word.translation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label(word.source, systemImage: sourceIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(word.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .textSelection(.enabled)
    }

    private var sourceIcon: String {
        switch word.source {
        case "screenshot": return "camera.viewfinder"
        case "webpage": return "globe"
        case "video": return "play.rectangle"
        default: return "doc.text"
        }
    }
}

// MARK: - WordBookSettingsView

struct WordBookSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var hotkeySettings = HotkeySettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 设置内容
            Form {
                Section {
                    HStack {
                        Text("截图翻译")
                        Spacer()
                        KeyRecorderView(
                            keyCode: $hotkeySettings.screenshotKeyCode,
                            modifiers: $hotkeySettings.screenshotModifiers
                        )
                    }
                } header: {
                    Text("快捷键")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 320, height: 220)
    }
}

// MARK: - HotkeySettings

final class HotkeySettings: ObservableObject {
    static let shared = HotkeySettings()

    private let defaults = UserDefaults.standard
    private let keyCodeKey = "screenshotHotkeyKeyCode"
    private let modifiersKey = "screenshotHotkeyModifiers"

    @Published var screenshotKeyCode: UInt32 {
        didSet {
            defaults.set(screenshotKeyCode, forKey: keyCodeKey)
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }

    @Published var screenshotModifiers: UInt32 {
        didSet {
            defaults.set(screenshotModifiers, forKey: modifiersKey)
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }

    private init() {
        // 默认快捷键: ⌘+⇧+S (keyCode=1 是 S 键)
        let defaultKeyCode: UInt32 = 1  // kVK_ANSI_S
        let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

        if defaults.object(forKey: keyCodeKey) == nil {
            defaults.set(defaultKeyCode, forKey: keyCodeKey)
        }
        if defaults.object(forKey: modifiersKey) == nil {
            defaults.set(defaultModifiers, forKey: modifiersKey)
        }

        self.screenshotKeyCode = UInt32(defaults.integer(forKey: keyCodeKey))
        self.screenshotModifiers = UInt32(defaults.integer(forKey: modifiersKey))
    }

    var displayString: String {
        var parts: [String] = []

        if screenshotModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if screenshotModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if screenshotModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if screenshotModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        if let keyString = keyCodeToString(screenshotKeyCode) {
            parts.append(keyString)
        }

        return parts.joined(separator: " + ")
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            // Special keys
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        ]
        return keyMap[keyCode]
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
}

// MARK: - KeyRecorderView

struct KeyRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @State private var isRecording = false

    var body: some View {
        Button(action: { isRecording = true }) {
            Text(displayString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isRecording ? .accentColor : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .background(
            KeyRecorderHelper(
                isRecording: $isRecording,
                keyCode: $keyCode,
                modifiers: $modifiers
            )
        )
    }

    private var displayString: String {
        if isRecording {
            return "按下快捷键..."
        }

        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.isEmpty ? "点击设置" : parts.joined(separator: " + ")
    }

    private func keyCodeToString(_ code: UInt32) -> String? {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        ]
        return keyMap[code]
    }
}

// MARK: - KeyRecorderHelper (NSViewRepresentable)

struct KeyRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.onKeyRecorded = { code, mods in
            self.keyCode = code
            self.modifiers = mods
            self.isRecording = false
        }
        view.onCancel = {
            self.isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        if isRecording {
            nsView.startRecording()
        } else {
            nsView.stopRecording()
        }
    }
}

class KeyRecorderNSView: NSView {
    var onKeyRecorded: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?
    private var monitor: Any?

    func startRecording() {
        guard monitor == nil else { return }

        // 使用 local monitor 捕获按键
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // ESC 取消录制
            if event.keyCode == 53 {
                self.onCancel?()
                return nil
            }

            // 需要至少一个修饰键
            let mods = event.modifierFlags
            var carbonMods: UInt32 = 0

            if mods.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if mods.contains(.shift) { carbonMods |= UInt32(shiftKey) }
            if mods.contains(.option) { carbonMods |= UInt32(optionKey) }
            if mods.contains(.control) { carbonMods |= UInt32(controlKey) }

            // 必须有修饰键
            guard carbonMods != 0 else { return nil }

            self.onKeyRecorded?(UInt32(event.keyCode), carbonMods)
            return nil
        }

        // 激活窗口以接收按键
        window?.makeFirstResponder(self)
    }

    func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    override var acceptsFirstResponder: Bool { true }
}

import SwiftUI
import AppKit
import Carbon
import AVFoundation

struct WordBookView: View {

    @StateObject private var viewModel: WordBookViewModel
    @State private var showingSettings = false

    init(viewModel: WordBookViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 主内容区域
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

                // 底部工具栏
                Divider()
                HStack(spacing: 12) {
                    BottomBarButton(icon: "gearshape", tooltip: "设置") {
                        showingSettings = true
                    }

                    Divider()
                        .frame(height: 16)

                    BottomBarButton(icon: "square.and.arrow.down", tooltip: "导入 - 从 CSV/JSON 文件导入单词") {
                        viewModel.importWords()
                    }

                    BottomBarMenu(icon: "square.and.arrow.up", tooltip: "导出 - 将单词导出为文件备份") {
                        Button(action: { viewModel.exportWords(format: .csv) }) {
                            Label("CSV 格式", systemImage: "tablecells")
                        }
                        Button(action: { viewModel.exportWords(format: .json) }) {
                            Label("JSON 格式", systemImage: "doc.text")
                        }
                    }

                    BottomBarButton(icon: "arrow.clockwise", tooltip: "刷新 - 重新加载单词列表") {
                        viewModel.loadWords()
                    }

                    Spacer()

                    BottomBarButton(icon: "bubble.left.and.exclamationmark.bubble.right", tooltip: "反馈 - 提交问题或建议") {
                        if let url = URL(string: "https://github.com/1psychoQAQ/my-translator/issues") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar)
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索单词")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.loadWords()
            }
            .navigationTitle("单词本")
            .alert("Success", isPresented: .init(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.clearSuccessMessage() } }
            )) {
                Button("OK") { viewModel.clearSuccessMessage() }
            } message: {
                Text(viewModel.successMessage ?? "")
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
    @State private var isExpanded = false
    @State private var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(word.text)
                    .font(.headline)
                    .lineLimit(2)

                Button(action: speakWord) {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.system(size: 12))
                        .foregroundColor(isSpeaking ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("朗读单词")
            }

            Text(word.translation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // 显示句子（如果有）
            if let sentence = word.sentence, !sentence.isEmpty {
                Text(sentence)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(isExpanded ? nil : 2)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(4)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
            }

            HStack {
                Label(word.source, systemImage: sourceIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // 显示链接按钮（如果有 sourceURL）
                if let urlString = word.sourceURL {
                    Button(action: {
                        openURLWithTextFragment(urlString: urlString, text: word.text, sentence: word.sentence)
                    }) {
                        Label("打开原网页", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help(urlString)
                }

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

    /// 朗读单词
    private func speakWord() {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: word.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // 使用系统完全默认值，不做任何自定义调整

        isSpeaking = true
        synthesizer.speak(utterance)

        // 延迟重置状态（估算朗读时间）
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(word.text.count) * 0.08 + 0.3) {
            isSpeaking = false
        }
    }

    /// 使用 Text Fragment 打开 URL，跳转到指定文本位置
    /// Chrome 支持 #:~:text=prefix-,word,-suffix 语法，可以精确定位
    private func openURLWithTextFragment(urlString: String, text: String, sentence: String?) {
        // 移除已有的 fragment
        var baseURL = urlString
        if let hashIndex = urlString.firstIndex(of: "#") {
            baseURL = String(urlString[..<hashIndex])
        }

        var fragmentURL: String

        // 如果有句子，使用句子上下文来精确定位
        if let sentence = sentence, !sentence.isEmpty,
           let range = sentence.range(of: text, options: .caseInsensitive) {

            // 提取前缀（单词前的文本，最多取 30 个字符）
            let prefixEnd = range.lowerBound
            let prefixStart = sentence.index(prefixEnd, offsetBy: -min(30, sentence.distance(from: sentence.startIndex, to: prefixEnd)), limitedBy: sentence.startIndex) ?? sentence.startIndex
            var prefix = String(sentence[prefixStart..<prefixEnd]).trimmingCharacters(in: .whitespaces)

            // 提取后缀（单词后的文本，最多取 30 个字符）
            let suffixStart = range.upperBound
            let suffixEnd = sentence.index(suffixStart, offsetBy: min(30, sentence.distance(from: suffixStart, to: sentence.endIndex)), limitedBy: sentence.endIndex) ?? sentence.endIndex
            var suffix = String(sentence[suffixStart..<suffixEnd]).trimmingCharacters(in: .whitespaces)

            // URL 编码
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            prefix = prefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prefix
            suffix = suffix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? suffix

            // 构建带上下文的 Text Fragment
            // 格式: #:~:text=prefix-,word,-suffix
            if !prefix.isEmpty && !suffix.isEmpty {
                fragmentURL = "\(baseURL)#:~:text=\(prefix)-,\(encodedText),-\(suffix)"
            } else if !prefix.isEmpty {
                fragmentURL = "\(baseURL)#:~:text=\(prefix)-,\(encodedText)"
            } else if !suffix.isEmpty {
                fragmentURL = "\(baseURL)#:~:text=\(encodedText),-\(suffix)"
            } else {
                fragmentURL = "\(baseURL)#:~:text=\(encodedText)"
            }
        } else {
            // 没有句子，只用单词
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            fragmentURL = "\(baseURL)#:~:text=\(encodedText)"
        }

        if let url = URL(string: fragmentURL) {
            NSWorkspace.shared.open(url)
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

// MARK: - Bottom Bar Button

private struct BottomBarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltip)
    }
}

// MARK: - Bottom Bar Menu

private struct BottomBarMenu<Content: View>: View {
    let icon: String
    let tooltip: String
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .menuStyle(.borderlessButton)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltip)
    }
}

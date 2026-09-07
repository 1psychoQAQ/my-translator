import SwiftUI
import AppKit

// MARK: - 控制器

@MainActor
final class AIChatController {
    static let shared = AIChatController()

    private var window: AIChatWindow?

    private init() {}

    /// 打开 AI 提问弹窗
    /// - Parameter context: 可选上下文（选中文本 / OCR 文本），用户可围绕它提问
    func show(context: String?) {
        window?.close()

        let viewModel = AIChatViewModel(context: context)
        let newWindow = AIChatWindow(viewModel: viewModel) { [weak self] in
            self?.window = nil
        }
        window = newWindow

        newWindow.positionNearMouse()
        newWindow.orderFrontRegardless()
        newWindow.makeKey()
    }
}

// MARK: - 窗口

final class AIChatWindow: NSPanel {

    private let onClosed: () -> Void

    init(viewModel: AIChatViewModel, onClosed: @escaping () -> Void) {
        self.onClosed = onClosed

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 540),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.title = "AI 提问"
        // 使用 screenSaver 级别，能覆盖全屏应用
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.worksWhenModal = true

        self.contentView = NSHostingView(rootView: AIChatView(viewModel: viewModel))
    }

    override var canBecomeKey: Bool { true }

    override func close() {
        super.close()
        onClosed()
    }

    /// 在鼠标所在位置弹出，并确保窗口不越出屏幕
    func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen = screen else { return }

        let visible = screen.visibleFrame
        let size = frame.size

        var origin = NSPoint(x: mouse.x + 20, y: mouse.y - 20)

        let minX = visible.minX + 8
        let maxX = visible.maxX - size.width - 8
        let minY = visible.minY + 8
        let maxY = visible.maxY - size.height - 8

        if origin.x < minX { origin.x = minX }
        if origin.x > maxX { origin.x = maxX }
        if origin.y < minY { origin.y = minY }
        if origin.y > maxY { origin.y = maxY }

        setFrameOrigin(origin)
    }
}

// MARK: - ViewModel

@MainActor
final class AIChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading = false
    @Published var streamingText: String = ""
    @Published var errorMessage: String?

    private let context: String?

    init(context: String?) {
        self.context = context
    }

    var hasContext: Bool {
        guard let context = context else { return false }
        return !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var contextText: String {
        context ?? ""
    }

    func send() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isLoading else { return }

        guard LLMSettings.shared.isConfigured else {
            errorMessage = "尚未配置 API Key，请到「设置 → AI 助手」中填写"
            return
        }

        inputText = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: question))
        streamingText = ""
        isLoading = true

        let requestMessages = buildMessages()

        Task {
            do {
                let stream = LLMSettings.shared.makeService().chatStream(messages: requestMessages)
                var full = ""
                for try await delta in stream {
                    full += delta
                    streamingText = full
                }
                if !full.isEmpty {
                    messages.append(ChatMessage(role: .assistant, content: full))
                }
                streamingText = ""
                isLoading = false
            } catch {
                streamingText = ""
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func buildMessages() -> [ChatMessage] {
        var result: [ChatMessage] = []

        if hasContext {
            let systemPrompt = """
            你是一个智能助手。下面是用户提供的一段参考文本：

            \"\"\"
            \(contextText)
            \"\"\"

            请结合这段文本回答用户的问题。如果用户的问题与文本无关，也可以正常回答。
            """
            result.append(ChatMessage(role: .system, content: systemPrompt))
        } else {
            result.append(ChatMessage(role: .system, content: "你是一个乐于助人的 AI 助手。"))
        }

        result.append(contentsOf: messages)
        return result
    }
}

// MARK: - 视图

struct AIChatView: View {
    @ObservedObject var viewModel: AIChatViewModel
    @ObservedObject private var llmSettings = LLMSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasContext {
                contextCard
                Divider()
            }

            if !llmSettings.isConfigured {
                apiKeyConfigCard
                Divider()
            }

            messageList
            Divider()
            inputBar
        }
        .frame(minWidth: 380, minHeight: 480)
    }

    private var apiKeyConfigCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text("尚未配置 API Key")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            SecureField("sk-...", text: $llmSettings.apiKey)
                .textFieldStyle(.roundedBorder)

            Text("API Key 通过 macOS 钥匙串加密存储，仅保存在本机")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("参考文本")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView {
                Text(viewModel.contextText)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 72)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.messages.isEmpty {
                        Text("输入你的问题，按回车发送")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }

                    if !viewModel.streamingText.isEmpty {
                        MessageBubble(message: ChatMessage(role: .assistant, content: viewModel.streamingText))
                    }

                    if viewModel.isLoading && viewModel.streamingText.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("思考中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.streamingText) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isLoading) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.errorMessage) { _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("输入问题...", text: $viewModel.inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.send()
                }

            Button(action: { viewModel.send() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
            .disabled(
                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isLoading
            )
        }
        .padding(12)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - 消息气泡

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message.role == .user ? "你" : "AI")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(message.content)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(
                        message.role == .user
                            ? Color.accentColor.opacity(0.15)
                            : Color.secondary.opacity(0.12)
                    )
                    .cornerRadius(10)
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
    }
}

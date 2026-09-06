import SwiftUI
import AppKit

// MARK: - 关键词 AI 释义弹窗

class DefinitionPopupWindow: NSPanel {

    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private var originalText: String = ""
    private var baseWidth: CGFloat = 400

    static var current: DefinitionPopupWindow?

    static func show(text: String, at point: NSPoint) {
        current?.closePopup()
        let popup = DefinitionPopupWindow(text: text, at: point)
        current = popup
    }

    private init(text: String, at point: NSPoint) {
        self.originalText = text
        let initialSize = Self.contentSize(for: text)
        self.baseWidth = initialSize.width

        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 使用 screenSaver 级别，能覆盖全屏应用
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.worksWhenModal = true

        let content = DefinitionContentView(text: text) { [weak self] definition in
            self?.updateHeight(forDefinition: definition)
        }
        self.contentView = NSHostingView(rootView: content)

        // 定位到鼠标所在屏幕并确保不越出屏幕
        let mouse = point
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        var origin = NSPoint(x: mouse.x + 16, y: mouse.y - initialSize.height - 8)
        if let screen = screen {
            let visible = screen.visibleFrame
            if origin.x + initialSize.width > visible.maxX { origin.x = visible.maxX - initialSize.width - 8 }
            if origin.x < visible.minX { origin.x = visible.minX + 8 }
            if origin.y < visible.minY { origin.y = visible.minY + 8 }
            if origin.y + initialSize.height > visible.maxY { origin.y = mouse.y + 16 }
        }

        self.setFrameOrigin(origin)
        self.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupMonitors()
        }
    }

    /// 初始尺寸（loading 状态）：宽度跟随选中文字，高度取较小值
    private static func contentSize(for text: String) -> NSSize {
        let chars = CGFloat(text.count)
        let width = min(max(chars * 11 + 80, 360), 500)
        return NSSize(width: width, height: 180)
    }

    /// 根据原文 + AI 释义内容估算需要的高度
    private static func height(text: String, definition: String, width: CGFloat) -> CGFloat {
        let availableWidth = width - 28  // 左右 padding 14*2
        let charsPerLine = max(availableWidth / 11, 1)

        let textLines = max(ceil(CGFloat(text.count) / charsPerLine), 1)
        let defLines = max(ceil(CGFloat(definition.count) / charsPerLine), 1)

        let textHeight = textLines * 20   // 原文 15pt 行高
        let defHeight = defLines * 18     // 释义 13pt 行高

        // padding(28) + 原文 + spacing(8) + divider(1) + spacing(8) + 释义
        let total = 28 + textHeight + 8 + 1 + 8 + defHeight
        return min(max(total, 200), 640)
    }

    /// 释义返回后动态调整窗口高度，保持顶部对齐并确保不越屏
    private func updateHeight(forDefinition definition: String) {
        guard !definition.isEmpty else { return }
        let newHeight = Self.height(text: originalText, definition: definition, width: baseWidth)
        let newFrame = NSRect(
            x: frame.minX,
            y: frame.maxY - newHeight,
            width: baseWidth,
            height: newHeight
        )
        setFrame(newFrame, display: true, animate: false)
        keepOnScreen()
    }

    private func keepOnScreen() {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else { return }

        let visible = screen.visibleFrame
        var origin = frame.origin
        let size = frame.size

        if origin.x + size.width > visible.maxX { origin.x = visible.maxX - size.width - 8 }
        if origin.x < visible.minX { origin.x = visible.minX + 8 }
        if origin.y < visible.minY { origin.y = visible.minY + 8 }
        if origin.y + size.height > visible.maxY { origin.y = visible.maxY - size.height - 8 }

        setFrameOrigin(origin)
    }

    private func setupMonitors() {
        // 点击外部关闭
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let location = NSEvent.mouseLocation
            if !self.frame.contains(location) {
                DispatchQueue.main.async {
                    self.closePopup()
                }
            }
        }

        // ESC 关闭
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.closePopup()
                }
            }
        }
    }

    func closePopup() {
        if let m = mouseMonitor {
            NSEvent.removeMonitor(m)
            mouseMonitor = nil
        }
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }

        self.orderOut(nil)

        if DefinitionPopupWindow.current === self {
            DefinitionPopupWindow.current = nil
        }
    }
}

// MARK: - 弹窗内容

private struct DefinitionContentView: View {
    let text: String
    let onDefinitionLoaded: (String) -> Void

    @State private var definition = ""
    @State private var isLoading = true
    @State private var errorMsg: String?

    private static let systemPrompt = """
    你是一个释义助手。用户是一个1-3年的golang后端开发工程师本科知识背景，会选中一个词、短语等，请给出具体释义：

    要求：用中文回答，分点清晰，控制在 150 字以内，重点说明具体含义。
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 原文
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // AI 释义
            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("AI 释义中...").font(.caption).foregroundColor(.secondary)
                }
            } else if let err = errorMsg {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    Text(definition)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await performDefinition()
        }
    }

    private func performDefinition() async {
        guard LLMSettings.shared.isConfigured else {
            errorMsg = "尚未配置 API Key，请在「设置 → AI 助手」中填写"
            isLoading = false
            return
        }

        do {
            let service = LLMSettings.shared.makeService()
            let messages = [
                ChatMessage(role: .system, content: Self.systemPrompt),
                ChatMessage(role: .user, content: text)
            ]
            let result = try await service.chat(messages: messages)
            await MainActor.run {
                definition = result
                isLoading = false
                onDefinitionLoaded(result)
            }
        } catch {
            await MainActor.run {
                errorMsg = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - 控制器

@MainActor
final class DefinitionPopupController {
    static let shared = DefinitionPopupController()
    private init() {}

    func show(text: String, at point: NSPoint) {
        DefinitionPopupWindow.show(text: text, at: point)
    }
}

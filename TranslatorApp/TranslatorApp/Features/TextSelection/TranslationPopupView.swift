import SwiftUI
import AppKit
import Translation
import AVFoundation

// MARK: - 翻译弹窗

@available(macOS 15.0, *)
class TranslationPopupWindow: NSPanel {

    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private var onSaveCallback: ((String, String) -> Void)?
    private var originalText: String = ""

    static var current: TranslationPopupWindow?

    static func show(text: String, at point: NSPoint, onSave: @escaping (String, String) -> Void) {
        // 关闭已存在的弹窗
        current?.closePopup()

        let popup = TranslationPopupWindow(text: text, at: point, onSave: onSave)
        current = popup
    }

    private init(text: String, at point: NSPoint, onSave: @escaping (String, String) -> Void) {
        self.originalText = text
        self.onSaveCallback = onSave

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 使用 screenSaver 级别，能覆盖全屏应用
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        // 关键设置：允许显示在全屏应用上
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Panel 特有设置：即使应用不活跃也能接收事件
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.worksWhenModal = true

        // 设置内容
        let view = PopupContentView(
            text: text,
            onSave: { [weak self] original, translated in
                self?.onSaveCallback?(original, translated)
                self?.closePopup()
            },
            onClose: { [weak self] in
                self?.closePopup()
            }
        )
        self.contentView = NSHostingView(rootView: view)

        // 计算位置
        var origin = point
        origin.y -= 210

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            if origin.x + 320 > frame.maxX { origin.x = frame.maxX - 330 }
            if origin.x < frame.minX { origin.x = frame.minX + 10 }
            if origin.y < frame.minY { origin.y = point.y + 20 }
        }

        self.setFrameOrigin(origin)
        self.orderFrontRegardless()

        // 延迟添加监听器，避免立即触发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupMonitors()
        }
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
        // 移除监听器
        if let m = mouseMonitor {
            NSEvent.removeMonitor(m)
            mouseMonitor = nil
        }
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }

        // 关闭窗口
        self.orderOut(nil)

        // 清除引用
        if TranslationPopupWindow.current === self {
            TranslationPopupWindow.current = nil
        }
    }
}

// MARK: - 弹窗内容

@available(macOS 15.0, *)
private struct PopupContentView: View {
    let text: String
    let onSave: (String, String) -> Void
    let onClose: () -> Void

    @State private var translated = ""
    @State private var isLoading = true
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("翻译中...").foregroundColor(.secondary)
                }
                .frame(height: 80)
            } else if let err = errorMsg {
                VStack(spacing: 8) {
                    Text("翻译失败").font(.headline)
                    Text(err).font(.caption).foregroundColor(.secondary)
                    Button("关闭", action: onClose)
                }
                .padding()
            } else {
                resultView
            }
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await performTranslation()
        }
    }

    private func performTranslation() async {
        do {
            // 使用已有的 TranslationService 进行翻译
            let service = TranslationService()
            let result = try await service.translate(text, from: "en", to: "zh-Hans")

            await MainActor.run {
                translated = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMsg = error.localizedDescription
                isLoading = false
            }
        }
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 原文
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("原文").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button(action: speakText) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(IconButtonStyle())
                }
                Text(text)
                    .font(.system(size: 13))
                    .lineLimit(3)
            }

            Divider()

            // 译文
            VStack(alignment: .leading, spacing: 4) {
                Text("译文").font(.caption).foregroundColor(.secondary)
                Text(translated)
                    .font(.system(size: 13))
                    .lineLimit(3)
            }

            // 按钮
            HStack(spacing: 8) {
                Button(action: { onSave(text, translated) }) {
                    Label("收藏", systemImage: "bookmark")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("关闭", action: onClose)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding(12)
    }

    // 静态 synthesizer 避免每次创建
    private static let synthesizer = AVSpeechSynthesizer()

    private func speakText() {
        if Self.synthesizer.isSpeaking {
            Self.synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        Self.synthesizer.speak(utterance)
    }
}

// MARK: - 自定义按钮样式

/// 主按钮样式（收藏按钮）
private struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.7) : (isHovering ? Color.accentColor.opacity(0.85) : Color.accentColor))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// 次要按钮样式（关闭按钮）
private struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isHovering ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.3) : (isHovering ? Color.gray.opacity(0.15) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovering ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// 图标按钮样式（发音按钮）
private struct IconButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .accentColor : (isHovering ? .primary : .secondary))
            .padding(4)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.2) : (isHovering ? Color.gray.opacity(0.15) : Color.clear))
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// MARK: - 控制器（兼容旧接口）

@MainActor
final class TranslationPopupController {
    static let shared = TranslationPopupController()
    private init() {}

    func show(text: String, at point: NSPoint, onSave: @escaping (String, String) -> Void) {
        guard #available(macOS 15.0, *) else { return }
        TranslationPopupWindow.show(text: text, at: point, onSave: onSave)
    }

    func close() {
        if #available(macOS 15.0, *) {
            TranslationPopupWindow.current?.closePopup()
        }
    }
}

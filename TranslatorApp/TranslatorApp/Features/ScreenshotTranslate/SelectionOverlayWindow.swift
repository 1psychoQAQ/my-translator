import AppKit
import SwiftUI
import ScreenCaptureKit

// MARK: - 用户操作结果

enum SelectionAction {
    case saveToWordBook(String, String)  // 保存到单词本 (原文, 译文)
    case copied                           // 已复制到剪贴板
    case cancelled                        // 取消
}

// MARK: - 选区窗口

final class SelectionOverlayWindow: NSWindow {

    private let completion: (SelectionAction) -> Void
    private let onTranslate: (CGRect) async throws -> (original: String, translated: String)
    private var globalKeyboardMonitor: Any?
    private var localKeyboardMonitor: Any?
    private var hasCompleted = false
    private var hasHiddenWindow = false
    private var overlayView: OverlayView?

    init(
        onTranslate: @escaping (CGRect) async throws -> (original: String, translated: String),
        completion: @escaping (SelectionAction) -> Void
    ) {
        self.onTranslate = onTranslate
        self.completion = completion

        let screenFrame = NSScreen.main?.frame ?? .zero

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false  // 防止 close() 自动释放，由 ARC 管理

        setupOverlayView()
        setupKeyboardMonitor()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    deinit {
        // 如果 finishWith 没有被调用（如 app 被强制退出），需要在这里清理
        // cleanupKeyboardMonitor 会检查 nil，所以重复调用是安全的
        if globalKeyboardMonitor != nil || localKeyboardMonitor != nil {
            cleanupKeyboardMonitor()
        }
        print("SelectionOverlayWindow deinit")
    }

    private func setupOverlayView() {
        let view = OverlayView(
            frame: self.frame,
            onTranslate: { [weak self] rect in
                await self?.performTranslation(rect: rect)
            },
            onCopy: { [weak self] rect in
                self?.performCopy(rect: rect)
            },
            onSaveToWordBook: { [weak self] original, translated in
                self?.finishWith(.saveToWordBook(original, translated))
            },
            onCancel: { [weak self] in
                self?.finishWith(.cancelled)
            }
        )
        self.contentView = view
        self.overlayView = view
    }

    private func setupKeyboardMonitor() {
        // Global monitor: 监听其他应用激活时的按键
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.finishWith(.cancelled)
            }
        }

        // Local monitor: 监听本应用的按键
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.finishWith(.cancelled)
                return nil // 消费事件
            }
            return event
        }
    }

    private func cleanupKeyboardMonitor() {
        if let monitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyboardMonitor = nil
        }
        if let monitor = localKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyboardMonitor = nil
        }
    }

    func show() {
        orderFront(nil)
        NSCursor.crosshair.push()
    }

    private func performTranslation(rect: CGRect) async {
        do {
            let result = try await onTranslate(rect)
            overlayView?.showTranslationResult(original: result.original, translated: result.translated)
        } catch {
            overlayView?.showError(error.localizedDescription)
        }
    }

    private func performCopy(rect: CGRect) {
        // 防止重复调用
        guard !hasCompleted else { return }

        // 先隐藏窗口，避免截图时包含选区 UI
        if !hasHiddenWindow {
            orderOut(nil)
            hasHiddenWindow = true
        }

        Task { [weak self] in
            // 等待窗口完全隐藏
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            do {
                // 截取指定区域
                let image = try await self?.captureRegion(rect)

                if let image = image {
                    // 复制到剪贴板
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()

                    // 将 CGImage 转换为 NSImage
                    let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    pasteboard.writeObjects([nsImage])

                    print("✅ 截图已复制到剪贴板")
                }
            } catch {
                print("❌ 复制截图失败: \(error.localizedDescription)")
            }

            await MainActor.run { [weak self] in
                self?.finishWith(.copied)
            }
        }
    }

    /// 截取指定区域的截图
    private func captureRegion(_ rect: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取显示器"])
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width * 2)  // Retina
        config.height = Int(rect.height * 2)
        config.scalesToFit = false
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        return image
    }

    private func finishWith(_ action: SelectionAction) {
        guard !hasCompleted else { return }
        hasCompleted = true

        NSCursor.pop()
        cleanupKeyboardMonitor()

        // 隐藏并关闭窗口
        if !hasHiddenWindow {
            orderOut(nil)
            hasHiddenWindow = true
        }
        close()  // releasedWhenClosed = false，所以不会立即释放

        // 调用 completion，恢复 async 流程
        // completion 中会设置 currentSelectionWindow = nil，届时 ARC 会释放窗口
        completion(action)
    }
}

// MARK: - Overlay View

private class OverlayView: NSView {

    enum State {
        case selecting
        case showingToolbar
        case translating
        case showingResult(original: String, translated: String)
        case showingError(String)
    }

    private var state: State = .selecting
    private var startPoint: NSPoint?
    private var currentRect: CGRect = .zero
    private var currentHostingView: NSHostingView<AnyView>?

    private let onTranslate: (CGRect) async -> Void
    private let onCopy: (CGRect) -> Void
    private let onSaveToWordBook: (String, String) -> Void
    private let onCancel: () -> Void

    private let selectionLayer = CAShapeLayer()
    private let dimLayer = CALayer()

    init(frame: NSRect,
         onTranslate: @escaping (CGRect) async -> Void,
         onCopy: @escaping (CGRect) -> Void,
         onSaveToWordBook: @escaping (String, String) -> Void,
         onCancel: @escaping () -> Void) {
        self.onTranslate = onTranslate
        self.onCopy = onCopy
        self.onSaveToWordBook = onSaveToWordBook
        self.onCancel = onCancel
        super.init(frame: frame)

        wantsLayer = true

        // 半透明遮罩层
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        dimLayer.frame = bounds
        layer?.addSublayer(dimLayer)

        // 选区边框
        selectionLayer.strokeColor = NSColor.systemBlue.cgColor
        selectionLayer.fillColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        selectionLayer.lineWidth = 2
        selectionLayer.lineDashPattern = [5, 3]
        layer?.addSublayer(selectionLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard case .selecting = state else { return }
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        removeCurrentHostingView()
        updateSelectionLayer()
    }

    override func mouseDragged(with event: NSEvent) {
        guard case .selecting = state, let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)

        currentRect = CGRect(x: minX, y: minY, width: width, height: height)
        updateSelectionLayer()
    }

    override func mouseUp(with event: NSEvent) {
        guard case .selecting = state else { return }
        guard currentRect.width > 10, currentRect.height > 10 else { return }

        state = .showingToolbar
        // Cursor will be popped in SelectionOverlayWindow.finishWith
        showToolbar()
    }

    private func updateSelectionLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionLayer.path = CGPath(rect: currentRect, transform: nil)
        CATransaction.commit()
    }

    // MARK: - UI Updates

    private func removeCurrentHostingView() {
        currentHostingView?.removeFromSuperview()
        currentHostingView = nil
    }

    private func showToolbar() {
        removeCurrentHostingView()

        let rect = currentRect
        let toolbarView = ToolbarView(
            onTranslate: { [weak self] in
                guard let self = self else { return }
                self.state = .translating
                self.showLoading()
                let screenRect = self.convertToScreenCoordinates(rect)
                Task {
                    await self.onTranslate(screenRect)
                }
            },
            onCopy: { [weak self] in
                guard let self = self else { return }
                let screenRect = self.convertToScreenCoordinates(rect)
                self.copyScreenshot(rect: screenRect)
                self.onCopy(screenRect)
            },
            onCancel: { [weak self] in
                self?.onCancel()
            }
        )

        let hostingView = NSHostingView(rootView: AnyView(toolbarView))
        positionView(hostingView, below: currentRect, preferredWidth: 180, preferredHeight: 44)
        addSubview(hostingView)
        currentHostingView = hostingView
    }

    private func showLoading() {
        removeCurrentHostingView()

        let loadingView = LoadingView()
        let hostingView = NSHostingView(rootView: AnyView(loadingView))
        positionView(hostingView, below: currentRect, preferredWidth: 120, preferredHeight: 40)
        addSubview(hostingView)
        currentHostingView = hostingView
    }

    func showTranslationResult(original: String, translated: String) {
        state = .showingResult(original: original, translated: translated)
        removeCurrentHostingView()

        let resultView = OverlayResultView(
            original: original,
            translated: translated,
            onSave: { [weak self] in
                self?.onSaveToWordBook(original, translated)
            },
            onCancel: { [weak self] in
                self?.onCancel()
            }
        )

        let hostingView = NSHostingView(rootView: AnyView(resultView))
        positionView(hostingView, below: currentRect, preferredWidth: 350, preferredHeight: 200)
        addSubview(hostingView)
        currentHostingView = hostingView
    }

    func showError(_ message: String) {
        state = .showingError(message)
        removeCurrentHostingView()

        let errorView = ErrorView(message: message) { [weak self] in
            self?.onCancel()
        }

        let hostingView = NSHostingView(rootView: AnyView(errorView))
        positionView(hostingView, below: currentRect, preferredWidth: 250, preferredHeight: 80)
        addSubview(hostingView)
        currentHostingView = hostingView
    }

    private func positionView(_ view: NSView, below rect: CGRect, preferredWidth: CGFloat, preferredHeight: CGFloat) {
        var x = rect.origin.x
        var y = rect.origin.y - preferredHeight - 8

        // 确保不超出屏幕
        if y < 0 {
            y = rect.maxY + 8
        }
        if x + preferredWidth > bounds.width {
            x = bounds.width - preferredWidth - 8
        }
        if x < 0 {
            x = 8
        }

        view.frame = CGRect(x: x, y: y, width: preferredWidth, height: preferredHeight)
    }

    private func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
        guard let screen = NSScreen.main else { return rect }
        let screenHeight = screen.frame.height
        return CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private func copyScreenshot(rect: CGRect) {
        // 使用 ScreenCaptureKit 截图会在 ScreenshotService 中处理
        // 这里只是触发复制操作
    }
}

// MARK: - SwiftUI Views

private struct ToolbarView: View {
    let onTranslate: () -> Void
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTranslate) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("翻译")
                }
            }
            .buttonStyle(ToolbarButtonStyle(bgColor: .blue))

            Button(action: onCopy) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("复制")
                }
            }
            .buttonStyle(ToolbarButtonStyle(bgColor: .green))

            Button(action: onCancel) {
                Image(systemName: "xmark")
            }
            .buttonStyle(ToolbarButtonStyle(bgColor: .gray))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
        )
    }
}

private struct LoadingView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("翻译中...")
                .font(.system(size: 13))
                .foregroundColor(.white)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.85))
        )
    }
}

private struct OverlayResultView: View {
    let original: String
    let translated: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 原文
            VStack(alignment: .leading, spacing: 4) {
                Text("原文")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                ScrollView {
                    Text(original)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 50)
            }

            Divider()

            // 译文
            VStack(alignment: .leading, spacing: 4) {
                Text("译文")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                ScrollView {
                    Text(translated)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 50)
            }

            // 按钮
            HStack {
                Button("收藏到单词本", action: onSave)
                    .buttonStyle(ToolbarButtonStyle(bgColor: .blue))

                Spacer()

                Text("ESC 退出")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.9))
        )
    }
}

private struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("❌ \(message)")
                .font(.system(size: 13))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Button("关闭", action: onDismiss)
                .buttonStyle(ToolbarButtonStyle(bgColor: .gray))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.9))
        )
    }
}

private struct ToolbarButtonStyle: ButtonStyle {
    let bgColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? bgColor.opacity(0.7) : bgColor)
            )
    }
}

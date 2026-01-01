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
    private let frozenScreenImage: CGImage?
    private var globalKeyboardMonitor: Any?
    private var localKeyboardMonitor: Any?
    private var hasCompleted = false
    private var hasHiddenWindow = false
    private var overlayView: OverlayView?

    init(
        frozenScreenImage: CGImage?,
        onTranslate: @escaping (CGRect) async throws -> (original: String, translated: String),
        completion: @escaping (SelectionAction) -> Void
    ) {
        self.frozenScreenImage = frozenScreenImage
        self.onTranslate = onTranslate
        self.completion = completion

        let screenFrame = NSScreen.main?.frame ?? .zero

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // 使用较高的窗口层级，确保在所有普通窗口（包括 SwiftUI Window）之上
        // 但避免使用 .screenSaver（会导致系统死锁）
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) - 1)
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
            frozenScreenImage: frozenScreenImage,
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

    private let backgroundLayer = CALayer()       // 固定屏幕背景
    private let dimLayer = CAShapeLayer()         // 暗色遮罩层（带选区镂空）
    private let selectionLayer = CAShapeLayer()   // 选区边框

    init(frame: NSRect,
         frozenScreenImage: CGImage?,
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

        // 固定屏幕背景层
        if let image = frozenScreenImage {
            backgroundLayer.contents = image
            backgroundLayer.frame = bounds
            backgroundLayer.contentsGravity = .resizeAspectFill
            layer?.addSublayer(backgroundLayer)
        }

        // 暗色遮罩层 - 使用 even-odd 规则实现镂空效果
        dimLayer.fillColor = NSColor.black.withAlphaComponent(0.4).cgColor
        dimLayer.fillRule = .evenOdd
        dimLayer.frame = bounds
        // 初始时全屏暗色显示
        dimLayer.path = CGPath(rect: bounds, transform: nil)
        layer?.addSublayer(dimLayer)

        // 选区边框：荧光笔高亮风格
        selectionLayer.strokeColor = NSColor.systemYellow.withAlphaComponent(0.8).cgColor
        selectionLayer.fillColor = NSColor.systemYellow.withAlphaComponent(0.15).cgColor
        selectionLayer.lineWidth = 2
        selectionLayer.cornerRadius = 4
        selectionLayer.shadowColor = NSColor.systemYellow.cgColor
        selectionLayer.shadowOffset = .zero
        selectionLayer.shadowRadius = 6
        selectionLayer.shadowOpacity = 0.4
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

        let cornerRadius: CGFloat = 4

        // 选区边框：圆角矩形
        selectionLayer.path = CGPath(
            roundedRect: currentRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        // 暗色遮罩 - 使用 even-odd 规则实现镂空效果
        let maskPath = CGMutablePath()
        maskPath.addRect(bounds)  // 全屏区域
        maskPath.addRoundedRect(
            in: currentRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius
        )
        dimLayer.path = maskPath

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
        positionToolbar(hostingView, attachedTo: currentRect)
        addSubview(hostingView)
        currentHostingView = hostingView
    }

    private func showLoading() {
        removeCurrentHostingView()

        let loadingView = LoadingView()
        let hostingView = NSHostingView(rootView: AnyView(loadingView))
        positionToolbar(hostingView, attachedTo: currentRect)
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
        positionResultView(hostingView, below: currentRect, preferredWidth: 320, preferredHeight: 180)
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
        positionToolbar(hostingView, attachedTo: currentRect)
        addSubview(hostingView)
        currentHostingView = hostingView
    }

    /// 定位悬浮工具条 - 贴着选区底部居中
    private func positionToolbar(_ view: NSView, attachedTo rect: CGRect) {
        // 让 SwiftUI 自动计算尺寸
        view.setFrameSize(view.fittingSize)
        let size = view.frame.size

        // 居中于选区底部，紧贴选区
        var x = rect.midX - size.width / 2
        var y = rect.origin.y - size.height - 6

        // 如果下方空间不足，放到选区上方
        if y < 8 {
            y = rect.maxY + 6
        }

        // 确保不超出屏幕左右边界
        if x < 8 {
            x = 8
        }
        if x + size.width > bounds.width - 8 {
            x = bounds.width - size.width - 8
        }

        view.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// 定位结果视图 - 选区下方
    private func positionResultView(_ view: NSView, below rect: CGRect, preferredWidth: CGFloat, preferredHeight: CGFloat) {
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

/// 系统级悬浮操作条 - 图标按钮组
private struct ToolbarView: View {
    let onTranslate: () -> Void
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            // 翻译按钮
            FloatingActionButton(
                icon: "character.book.closed",
                tooltip: "翻译",
                action: onTranslate
            )

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.3))

            // 复制按钮
            FloatingActionButton(
                icon: "doc.on.doc",
                tooltip: "复制",
                action: onCopy
            )

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.3))

            // 取消按钮
            FloatingActionButton(
                icon: "xmark",
                tooltip: "取消",
                action: onCancel
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(FloatingBarBackground())
    }
}

/// 悬浮操作条图标按钮
private struct FloatingActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltip)
    }
}

/// 毛玻璃背景
private struct FloatingBarBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
    }
}

private struct LoadingView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .colorInvert()
            Text("识别中...")
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FloatingBarBackground())
    }
}

private struct OverlayResultView: View {
    let original: String
    let translated: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var showCopiedOriginal = false
    @State private var showCopiedTranslation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 原文
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("原文")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    // 复制原文按钮
                    Button(action: copyOriginal) {
                        Image(systemName: showCopiedOriginal ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: showCopiedOriginal ? .semibold : .regular))
                            .foregroundColor(.white.opacity(showCopiedOriginal ? 0.9 : 0.5))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: showCopiedOriginal)
                }
                ScrollView {
                    Text(original)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 40)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // 译文
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("译文")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    // 复制译文按钮
                    Button(action: copyTranslation) {
                        Image(systemName: showCopiedTranslation ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: showCopiedTranslation ? .semibold : .regular))
                            .foregroundColor(.white.opacity(showCopiedTranslation ? 0.9 : 0.5))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: showCopiedTranslation)
                }
                ScrollView {
                    Text(translated)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 40)
            }

            // 操作按钮
            HStack(spacing: 8) {
                Button(action: onSave) {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 11))
                        Text("收藏")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("关闭")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Text("ESC")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(FloatingBarBackground())
    }

    private func copyOriginal() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(original, forType: .string)
        showCopiedOriginal = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedOriginal = false
        }
    }

    private func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translated, forType: .string)
        showCopiedTranslation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedTranslation = false
        }
    }
}

private struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(2)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FloatingBarBackground())
    }
}

import AppKit
import SwiftUI
import ScreenCaptureKit
import AVFoundation

// MARK: - 用户操作结果

enum SelectionAction {
    case saveToWordBook(String, String)  // 保存到单词本 (原文, 译文)
    case copied                           // 已复制到剪贴板
    case cancelled                        // 取消
}

// MARK: - 选区窗口

final class SelectionOverlayWindow: NSPanel {

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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 使用 screenSaver 级别，这是最高的窗口层级，能覆盖全屏应用
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        // 关键设置：
        // - canJoinAllSpaces: 让窗口出现在所有 Space
        // - fullScreenAuxiliary: 允许显示在全屏应用上
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        // Panel 特有设置：即使应用不活跃也能接收事件
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.worksWhenModal = true

        setupOverlayView()
        setupKeyboardMonitor()
    }

    override var canBecomeKey: Bool { true }
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
        // 使用 orderFrontRegardless 在不激活应用的情况下显示窗口
        // 这样不会触发 Space 切换，配合 nonactivatingPanel 使用
        orderFrontRegardless()
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

        // 从画板裁剪选区（包含马赛克效果）
        guard let image = overlayView?.getSelectionImage() else {
            print("❌ 无法获取选区图像")
            finishWith(.cancelled)
            return
        }

        // 隐藏窗口
        if !hasHiddenWindow {
            orderOut(nil)
            hasHiddenWindow = true
        }

        // 保存到临时文件
        let tempURL = Self.saveImageToTemp(image)

        // 复制到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        let pngData = bitmapRep.representation(using: .png, properties: [:])
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        let item = NSPasteboardItem()

        // PNG 图片数据
        if let pngData = pngData {
            item.setData(pngData, forType: .png)
        }

        // TIFF 数据（兼容性）
        if let tiffData = nsImage.tiffRepresentation {
            item.setData(tiffData, forType: .tiff)
        }

        if let tempURL = tempURL {
            item.setString(tempURL.absoluteString, forType: .fileURL)
            item.setString(tempURL.path, forType: .string)
            print("✅ 截图已复制到剪贴板（图片 + 路径: \(tempURL.path)）")
        } else {
            print("✅ 截图已复制到剪贴板（仅图片）")
        }

        pasteboard.writeObjects([item])
        finishWith(.copied)
    }

    /// 保存图片到临时目录
    private static func saveImageToTemp(_ cgImage: CGImage) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ 保存临时图片失败: \(error.localizedDescription)")
            return nil
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
        case mosaic  // 马赛克模式
    }

    private var state: State = .selecting
    private var startPoint: NSPoint?
    private var currentRect: CGRect = .zero
    private var currentHostingView: NSHostingView<AnyView>?

    // 马赛克相关
    private var mosaicRects: [CGRect] = []  // 已打码区域列表
    private var currentMosaicRect: CGRect = .zero  // 当前正在绘制的马赛克区域
    private var mosaicStartPoint: NSPoint?

    private let onTranslate: (CGRect) async -> Void
    private let onCopy: (CGRect) -> Void
    private let onSaveToWordBook: (String, String) -> Void
    private let onCancel: () -> Void

    private let backgroundLayer = CALayer()       // 固定屏幕背景
    private let dimLayer = CAShapeLayer()         // 暗色遮罩层（带选区镂空）
    private let selectionLayer = CAShapeLayer()   // 选区边框
    private let mosaicPreviewLayer = CAShapeLayer()  // 马赛克预览层

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

        // 马赛克预览层
        mosaicPreviewLayer.strokeColor = NSColor.systemRed.withAlphaComponent(0.8).cgColor
        mosaicPreviewLayer.fillColor = NSColor.systemRed.withAlphaComponent(0.2).cgColor
        mosaicPreviewLayer.lineWidth = 2
        mosaicPreviewLayer.lineDashPattern = [4, 4]
        layer?.addSublayer(mosaicPreviewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch state {
        case .selecting:
            startPoint = point
            currentRect = .zero
            removeCurrentHostingView()
            updateSelectionLayer()
        case .mosaic:
            // 检查点击是否在选区内
            if currentRect.contains(point) {
                mosaicStartPoint = point
                currentMosaicRect = .zero
            }
        default:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)

        switch state {
        case .selecting:
            guard let start = startPoint else { return }
            let minX = min(start.x, current.x)
            let minY = min(start.y, current.y)
            let width = abs(current.x - start.x)
            let height = abs(current.y - start.y)
            currentRect = CGRect(x: minX, y: minY, width: width, height: height)
            updateSelectionLayer()

        case .mosaic:
            guard let start = mosaicStartPoint else { return }
            // 限制在选区内
            let clampedX = max(currentRect.minX, min(currentRect.maxX, current.x))
            let clampedY = max(currentRect.minY, min(currentRect.maxY, current.y))

            let minX = max(currentRect.minX, min(start.x, clampedX))
            let minY = max(currentRect.minY, min(start.y, clampedY))
            let maxX = min(currentRect.maxX, max(start.x, clampedX))
            let maxY = min(currentRect.maxY, max(start.y, clampedY))

            currentMosaicRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            updateMosaicPreviewLayer()

        default:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch state {
        case .selecting:
            guard currentRect.width > 10, currentRect.height > 10 else { return }
            state = .showingToolbar
            showToolbar()

        case .mosaic:
            // 添加马赛克区域
            if currentMosaicRect.width > 5, currentMosaicRect.height > 5 {
                mosaicRects.append(currentMosaicRect)
                applyMosaicToBackground()
            }
            currentMosaicRect = .zero
            mosaicStartPoint = nil
            updateMosaicPreviewLayer()

        default:
            break
        }
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

    private func updateMosaicPreviewLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if currentMosaicRect.width > 0 && currentMosaicRect.height > 0 {
            mosaicPreviewLayer.path = CGPath(rect: currentMosaicRect, transform: nil)
        } else {
            mosaicPreviewLayer.path = nil
        }
        CATransaction.commit()
    }

    /// 对背景图像应用马赛克效果
    private func applyMosaicToBackground() {
        guard let contents = backgroundLayer.contents else { return }
        let cgImage = contents as! CGImage

        // 转换坐标：视图坐标 -> 图像坐标
        let scale = CGFloat(cgImage.width) / bounds.width
        let imageRect = CGRect(
            x: currentMosaicRect.origin.x * scale,
            y: (bounds.height - currentMosaicRect.origin.y - currentMosaicRect.height) * scale,
            width: currentMosaicRect.width * scale,
            height: currentMosaicRect.height * scale
        )

        // 应用像素化马赛克
        if let newImage = Self.applyPixelation(to: cgImage, in: imageRect, blockSize: 12) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            backgroundLayer.contents = newImage
            CATransaction.commit()
        }
    }

    /// 对图像指定区域应用纯黑色覆盖（绝对不可恢复）
    static func applyPixelation(to image: CGImage, in rect: CGRect, blockSize: Int) -> CGImage? {
        let width = image.width
        let height = image.height

        // 创建位图上下文
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 绘制原始图像
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 获取像素数据
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // 纯黑色覆盖：直接将指定区域所有像素设为黑色
        let startX = max(0, Int(rect.origin.x))
        let startY = max(0, Int(rect.origin.y))
        let endX = min(width, Int(rect.origin.x + rect.width))
        let endY = min(height, Int(rect.origin.y + rect.height))

        for y in startY..<endY {
            for x in startX..<endX {
                let offset = (y * width + x) * 4
                pixels[offset] = 0      // R
                pixels[offset + 1] = 0  // G
                pixels[offset + 2] = 0  // B
                pixels[offset + 3] = 255 // A (不透明)
            }
        }

        return context.makeImage()
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
            onMosaic: { [weak self] in
                guard let self = self else { return }
                self.state = .mosaic
                self.removeCurrentHostingView()
                self.showMosaicToolbar()
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

    private func showMosaicToolbar() {
        removeCurrentHostingView()

        let toolbarView = MosaicToolbarView(
            onDone: { [weak self] in
                guard let self = self else { return }
                self.state = .showingToolbar
                self.showToolbar()
            },
            onUndo: { [weak self] in
                self?.undoLastMosaic()
            }
        )

        let hostingView = NSHostingView(rootView: AnyView(toolbarView))
        positionToolbar(hostingView, attachedTo: currentRect)
        addSubview(hostingView)
        currentHostingView = hostingView
    }

    private func undoLastMosaic() {
        // 撤销功能需要保存历史图像，暂不实现
        // 因为像素化是不可恢复的，这里只是移除记录
        if !mosaicRects.isEmpty {
            mosaicRects.removeLast()
        }
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

    /// 定位悬浮工具条 - 智能选择空间最大的方向
    private func positionToolbar(_ view: NSView, attachedTo rect: CGRect) {
        // 让 SwiftUI 自动计算尺寸
        view.setFrameSize(view.fittingSize)
        let size = view.frame.size
        let margin: CGFloat = 8

        // 计算选区四周的可用空间
        let spaceBelow = rect.origin.y  // 选区下方空间（坐标系原点在左下）
        let spaceAbove = bounds.height - rect.maxY  // 选区上方空间
        let spaceLeft = rect.origin.x  // 选区左侧空间
        let spaceRight = bounds.width - rect.maxX  // 选区右侧空间

        var x: CGFloat
        var y: CGFloat

        // 优先选择上下方向（更自然），选空间大的一边
        if spaceBelow >= size.height + margin || spaceBelow >= spaceAbove {
            // 放在选区下方
            x = rect.midX - size.width / 2
            y = rect.origin.y - size.height - 6
            // 如果下方空间真的不够，尝试上方
            if y < margin {
                y = rect.maxY + 6
            }
        } else {
            // 放在选区上方
            x = rect.midX - size.width / 2
            y = rect.maxY + 6
        }

        // 确保不超出屏幕左右边界
        if x < margin {
            x = margin
        }
        if x + size.width > bounds.width - margin {
            x = bounds.width - size.width - margin
        }

        // 确保不超出屏幕上下边界
        if y < margin {
            y = margin
        }
        if y + size.height > bounds.height - margin {
            y = bounds.height - size.height - margin
        }

        view.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// 定位结果视图 - 智能选择空间最大的方向
    private func positionResultView(_ view: NSView, below rect: CGRect, preferredWidth: CGFloat, preferredHeight: CGFloat) {
        let margin: CGFloat = 8

        // 计算选区上下的可用空间
        let spaceBelow = rect.origin.y
        let spaceAbove = bounds.height - rect.maxY

        var x = rect.origin.x
        var y: CGFloat

        // 选择空间大的一边
        if spaceBelow >= preferredHeight + margin || spaceBelow >= spaceAbove {
            y = rect.origin.y - preferredHeight - margin
            if y < margin {
                y = rect.maxY + margin
            }
        } else {
            y = rect.maxY + margin
        }

        // 确保不超出屏幕边界
        if x + preferredWidth > bounds.width - margin {
            x = bounds.width - preferredWidth - margin
        }
        if x < margin {
            x = margin
        }
        if y + preferredHeight > bounds.height - margin {
            y = bounds.height - preferredHeight - margin
        }
        if y < margin {
            y = margin
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

    /// 从画板裁剪选区部分（包含马赛克效果）
    func getSelectionImage() -> CGImage? {
        guard let contents = backgroundLayer.contents else { return nil }
        let cgImage = contents as! CGImage

        // 转换坐标：视图坐标（原点左下） -> 图像坐标（原点左上）
        let scale = CGFloat(cgImage.width) / bounds.width

        let imageRect = CGRect(
            x: currentRect.origin.x * scale,
            y: (bounds.height - currentRect.origin.y - currentRect.height) * scale,
            width: currentRect.width * scale,
            height: currentRect.height * scale
        )

        return cgImage.cropping(to: imageRect)
    }
}

// MARK: - SwiftUI Views

/// 系统级悬浮操作条 - 图标按钮组
private struct ToolbarView: View {
    let onTranslate: () -> Void
    let onCopy: () -> Void
    let onMosaic: () -> Void
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

            // 马赛克按钮
            FloatingActionButton(
                icon: "square.grid.3x3",
                tooltip: "马赛克",
                action: onMosaic
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

/// 马赛克模式工具栏
private struct MosaicToolbarView: View {
    let onDone: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            // 提示文字
            Text("框选打码区域")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.3))

            // 完成按钮
            FloatingActionButton(
                icon: "checkmark",
                tooltip: "完成",
                action: onDone
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(FloatingBarBackground())
    }
}

/// 悬浮操作条图标按钮（带自定义 tooltip）
private struct FloatingActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var showTooltip = false

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
        .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
            Text(tooltip)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isHovered {
                        showTooltip = true
                    }
                }
            } else {
                showTooltip = false
            }
        }
    }
}

/// 毛玻璃背景 - 使用共享组件的别名
private typealias FloatingBarBackground = FloatingPanelBackground

/// 截图翻译加载视图 - 使用共享组件
private struct LoadingView: View {
    var body: some View {
        TranslationLoadingView()
    }
}

/// 截图翻译结果视图 - 使用共享组件
private struct OverlayResultView: View {
    let original: String
    let translated: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        TranslationResultView(
            original: original,
            translated: translated,
            onSave: onSave,
            onClose: onCancel
        )
    }
}

/// 截图翻译错误视图 - 使用共享组件
private struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        TranslationErrorView(message: message, onDismiss: onDismiss)
    }
}

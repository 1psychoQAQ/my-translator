import Foundation
import ScreenCaptureKit
import AppKit

final class ScreenshotService: ScreenshotServiceProtocol {

    private var currentSelectionWindow: SelectionOverlayWindow?
    private var isCapturing = false

    /// 显示选区窗口，返回用户的操作
    /// - Parameter onTranslate: 翻译回调，接收选区坐标，返回原文和译文
    @MainActor
    func showSelectionAndCapture(
        onTranslate: @escaping (CGRect) async throws -> (original: String, translated: String)
    ) async -> SelectionAction {
        // 防止重复调用
        guard !isCapturing else {
            return .cancelled
        }
        isCapturing = true

        // 清理之前的窗口（如果有）
        if let oldWindow = currentSelectionWindow {
            oldWindow.orderOut(nil)
            currentSelectionWindow = nil
        }

        // 隐藏所有其他应用窗口（避免遮挡截图选区）
        hideOtherWindows()

        // 先截取全屏作为固定背景
        let frozenImage = await captureFullScreen()

        let action = await withCheckedContinuation { (continuation: CheckedContinuation<SelectionAction, Never>) in
            let window = SelectionOverlayWindow(
                frozenScreenImage: frozenImage,
                onTranslate: onTranslate,
                completion: { [weak self] action in
                    self?.currentSelectionWindow = nil
                    self?.isCapturing = false
                    // 不自动恢复窗口，保持截图前的状态
                    continuation.resume(returning: action)
                }
            )
            self.currentSelectionWindow = window
            window.show()
        }

        return action
    }

    /// 截取全屏作为固定背景
    private func captureFullScreen() async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])

            let config = SCStreamConfiguration()
            config.width = Int(display.width * 2)  // Retina
            config.height = Int(display.height * 2)
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            return image
        } catch {
            print("❌ 截取全屏失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 隐藏所有其他应用窗口（截图时避免遮挡）
    private func hideOtherWindows() {
        for window in NSApplication.shared.windows {
            // 跳过截图选区窗口本身
            if window === currentSelectionWindow { continue }
            // 跳过已经隐藏的窗口
            if !window.isVisible { continue }
            // 跳过状态栏菜单等系统窗口
            if window.level.rawValue < 0 { continue }

            window.orderOut(nil)
        }
    }

    /// 根据选区截图
    func captureRegion(_ rect: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw TranslatorError.screenshotFailed(reason: "无法获取显示器")
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
}

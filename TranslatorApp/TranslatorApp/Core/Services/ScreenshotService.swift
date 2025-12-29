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

        let action = await withCheckedContinuation { (continuation: CheckedContinuation<SelectionAction, Never>) in
            let window = SelectionOverlayWindow(
                onTranslate: onTranslate,
                completion: { [weak self] action in
                    self?.currentSelectionWindow = nil
                    self?.isCapturing = false
                    continuation.resume(returning: action)
                }
            )
            self.currentSelectionWindow = window
            window.show()
        }

        return action
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

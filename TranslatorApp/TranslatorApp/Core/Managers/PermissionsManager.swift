import AppKit
import ScreenCaptureKit

/// 权限管理器 - 检查并请求必要的系统权限
final class PermissionsManager {

    static let shared = PermissionsManager()

    private init() {}

    // MARK: - 屏幕录制权限（用于截图翻译）

    /// 缓存的屏幕录制权限状态
    private var cachedScreenCapturePermission: Bool?

    /// 检查是否有屏幕录制权限
    var hasScreenCapturePermission: Bool {
        // 优先使用缓存（避免重复检测）
        if let cached = cachedScreenCapturePermission {
            return cached
        }

        // CGPreflightScreenCaptureAccess 可能不准确，但作为快速检查
        let preflight = CGPreflightScreenCaptureAccess()
        if preflight {
            cachedScreenCapturePermission = true
            return true
        }

        // 如果 preflight 返回 false，不一定没权限
        // 返回 false 让引导界面显示，但不会强制重新授权
        return false
    }

    /// 异步检查屏幕录制权限（更准确）
    func checkScreenCapturePermissionAsync() async -> Bool {
        do {
            // 尝试获取可共享内容，如果成功说明有权限
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            cachedScreenCapturePermission = true
            return true
        } catch {
            cachedScreenCapturePermission = false
            return false
        }
    }

    /// 请求屏幕录制权限
    /// - 首次请求会弹出系统权限对话框，应用自动添加到列表
    /// - 如果已被拒绝，则打开系统设置让用户手动开启
    func requestScreenCapturePermission() {
        if hasScreenCapturePermission {
            return
        }

        // CGRequestScreenCaptureAccess() 会触发系统权限弹窗
        // 应用会自动添加到「屏幕录制」列表中
        // 用户只需勾选即可
        let _ = CGRequestScreenCaptureAccess()
    }

    /// 打开系统设置 - 屏幕录制
    func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 辅助功能权限（用于全局键盘监听）

    /// 检查是否有辅助功能权限
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// 请求辅助功能权限
    /// - 会弹出系统权限对话框，应用自动添加到列表
    /// - 用户只需在系统设置中勾选即可
    func requestAccessibilityPermission() {
        if hasAccessibilityPermission {
            return
        }

        // 使用 kAXTrustedCheckOptionPrompt 触发系统权限弹窗
        // 应用会自动添加到「辅助功能」列表中
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// 打开系统设置 - 辅助功能
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 检查所有权限

    /// 检查所有必要权限，返回缺失的权限列表
    func checkAllPermissions() -> [MissingPermission] {
        var missing: [MissingPermission] = []

        if !hasScreenCapturePermission {
            missing.append(.screenCapture)
        }

        if !hasAccessibilityPermission {
            missing.append(.accessibility)
        }

        return missing
    }

    /// 请求所有缺失的权限
    func requestAllMissingPermissions() {
        let missing = checkAllPermissions()

        for permission in missing {
            switch permission {
            case .screenCapture:
                requestScreenCapturePermission()
            case .accessibility:
                requestAccessibilityPermission()
            }
        }
    }
}

// MARK: - 缺失权限类型

enum MissingPermission: String, CaseIterable {
    case screenCapture = "屏幕录制"
    case accessibility = "辅助功能"

    var description: String {
        switch self {
        case .screenCapture:
            return "需要屏幕录制权限来进行截图翻译"
        case .accessibility:
            return "需要辅助功能权限来使用全局快捷键"
        }
    }

    var systemSettingsAction: () -> Void {
        switch self {
        case .screenCapture:
            return { PermissionsManager.shared.openScreenCaptureSettings() }
        case .accessibility:
            return { PermissionsManager.shared.openAccessibilitySettings() }
        }
    }
}

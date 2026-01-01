import AppKit
import ScreenCaptureKit

/// 权限管理器 - 检查并请求必要的系统权限
final class PermissionsManager {

    static let shared = PermissionsManager()

    private init() {}

    // MARK: - 屏幕录制权限（用于截图翻译）

    /// 检查是否有屏幕录制权限
    var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 请求屏幕录制权限，如果没有则跳转到系统设置
    func requestScreenCapturePermission() {
        if hasScreenCapturePermission {
            return
        }

        // 尝试请求权限（会弹出系统提示）
        let granted = CGRequestScreenCaptureAccess()

        if !granted {
            // 如果用户拒绝或需要手动授权，打开系统设置
            openScreenCaptureSettings()
        }
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

    /// 请求辅助功能权限，如果没有则跳转到系统设置
    func requestAccessibilityPermission() {
        if hasAccessibilityPermission {
            return
        }

        // 打开系统设置并提示用户授权
        openAccessibilitySettings()
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

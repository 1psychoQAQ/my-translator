import SwiftUI
import AppKit

/// 权限引导视图 - 系统风格
struct PermissionsOnboardingView: View {
    var onClose: () -> Void = {}
    var onMoveToCorner: () -> Void = {}  // 移动窗口到角落

    @State private var screenCaptureGranted = false
    @State private var accessibilityGranted = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// 当前步骤：1=辅助功能，2=屏幕录制，3=完成
    private var currentStep: Int {
        if !accessibilityGranted { return 1 }
        if !screenCaptureGranted { return 2 }
        return 3
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("需要授权")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(stepDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal)

            // 权限列表
            VStack(spacing: 0) {
                // 第一步：辅助功能
                PermissionRow(
                    icon: "keyboard",
                    title: "第一步：辅助功能",
                    description: "用于监听全局快捷键",
                    isGranted: accessibilityGranted,
                    showButton: currentStep == 1,
                    buttonTitle: "去授权",
                    action: authorizeAccessibility
                )

                Divider()
                    .padding(.leading, 56)

                // 第二步：屏幕录制
                PermissionRow(
                    icon: "rectangle.dashed.badge.record",
                    title: "第二步：屏幕录制",
                    description: "用于截取屏幕内容进行 OCR 识别",
                    isGranted: screenCaptureGranted,
                    showButton: currentStep == 2,
                    buttonTitle: "去授权",
                    action: authorizeScreenCapture
                )
            }
            .padding(.vertical, 8)

            Divider()
                .padding(.horizontal)

            // 底部按钮
            VStack(spacing: 12) {
                // 重启提示（权限已授予但需要重启）
                if allPermissionsGranted {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("权限已授予，需要重启应用生效")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button(action: restartApp) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("立即重启")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }

                HStack {
                    Button("稍后设置") {
                        onClose()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Spacer()

                    if !allPermissionsGranted {
                        Button("跳过") {
                            onClose()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 400)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            updatePermissionStatus()
        }
        .onReceive(timer) { _ in
            updatePermissionStatus()
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case 1: return "第一步：请先授权辅助功能权限"
        case 2: return "第二步：请授权屏幕录制权限"
        default: return "所有权限已授予！"
        }
    }

    private var allPermissionsGranted: Bool {
        screenCaptureGranted && accessibilityGranted
    }

    private func updatePermissionStatus() {
        let manager = PermissionsManager.shared
        screenCaptureGranted = manager.hasScreenCapturePermission
        accessibilityGranted = manager.hasAccessibilityPermission
    }

    /// 授权辅助功能
    private func authorizeAccessibility() {
        onMoveToCorner()  // 移动窗口避免遮挡
        PermissionsManager.shared.openAccessibilitySettings()
    }

    /// 授权屏幕录制
    private func authorizeScreenCapture() {
        onMoveToCorner()  // 降低窗口层级避免遮挡
        // 先请求权限，让应用添加到系统设置列表中
        PermissionsManager.shared.requestScreenCapturePermission()
        PermissionsManager.shared.openScreenCaptureSettings()
    }

    /// 重启应用
    private func restartApp() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundlePath]

        do {
            try task.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
        } catch {
            print("重启失败: \(error)")
        }
    }
}

/// 权限行
private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    var showButton: Bool = false
    var buttonTitle: String = "授权"
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isGranted ? .green : .blue)
                .frame(width: 32, height: 32)

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isGranted ? .secondary : .primary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 状态/按钮
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            } else if showButton {
                Button(buttonTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 权限窗口控制器

final class PermissionsWindowController {
    static let shared = PermissionsWindowController()

    private var window: NSWindow?
    private var windowObserver: NSObjectProtocol?

    private init() {}

    /// 显示权限引导窗口（如果有未授权的权限）
    func showIfNeeded() {
        let manager = PermissionsManager.shared

        // 先用同步方法快速检查
        if manager.hasScreenCapturePermission && manager.hasAccessibilityPermission {
            print("✅ 所有权限已授予，跳过引导")
            return
        }

        // 异步更准确地检测屏幕录制权限
        Task {
            let hasScreenCapture = await manager.checkScreenCapturePermissionAsync()
            let hasAccessibility = manager.hasAccessibilityPermission

            await MainActor.run {
                if hasScreenCapture && hasAccessibility {
                    print("✅ 所有权限已授予（异步检测），跳过引导")
                    return
                }

                // 检查是否已经显示过
                if self.window != nil {
                    self.window?.makeKeyAndOrderFront(nil)
                    return
                }

                self.show()
            }
        }
    }

    /// 强制显示权限引导窗口
    func show() {
        let contentView = PermissionsOnboardingView(
            onClose: { [weak self] in
                self?.close()
            },
            onMoveToCorner: { [weak self] in
                self?.moveToCorner()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.level = .floating
        window.backgroundColor = .clear

        // 监听窗口关闭（保存 observer 以便后续移除）
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.cleanup()
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 降低窗口层级，让系统设置显示在前面
    func moveToCorner() {
        guard let window = window else { return }
        // 降低窗口层级，放在系统设置后面
        window.level = .normal
    }

    func close() {
        window?.close()
        // cleanup() 会在 willCloseNotification 中被调用
    }

    /// 清理资源
    private func cleanup() {
        // 移除观察者
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
            windowObserver = nil
        }
        window = nil
    }
}

import SwiftUI
import AppKit

/// 权限引导视图 - 系统风格
struct PermissionsOnboardingView: View {
    var onClose: () -> Void = {}

    @State private var screenCaptureGranted = false
    @State private var accessibilityGranted = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                Text("为了正常使用截图翻译功能，请授予以下权限")
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
                PermissionRow(
                    icon: "rectangle.dashed.badge.record",
                    title: "屏幕录制",
                    description: "用于截取屏幕内容进行 OCR 识别",
                    isGranted: screenCaptureGranted,
                    action: {
                        // 触发系统权限弹窗，应用自动添加到列表
                        PermissionsManager.shared.requestScreenCapturePermission()
                    }
                )

                Divider()
                    .padding(.leading, 56)

                PermissionRow(
                    icon: "keyboard",
                    title: "辅助功能",
                    description: "用于监听全局快捷键",
                    isGranted: accessibilityGranted,
                    action: {
                        // 触发系统权限弹窗，应用自动添加到列表
                        PermissionsManager.shared.requestAccessibilityPermission()
                    }
                )
            }
            .padding(.vertical, 8)

            Divider()
                .padding(.horizontal)

            // 底部按钮
            HStack {
                Button("稍后设置") {
                    onClose()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    onClose()
                }) {
                    Text(allPermissionsGranted ? "完成" : "继续")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
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

    private var allPermissionsGranted: Bool {
        screenCaptureGranted && accessibilityGranted
    }

    private func updatePermissionStatus() {
        let manager = PermissionsManager.shared
        screenCaptureGranted = manager.hasScreenCapturePermission
        accessibilityGranted = manager.hasAccessibilityPermission

        // 如果所有权限都已授予，自动关闭
        if allPermissionsGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onClose()
            }
        }
    }
}

/// 权限行
private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

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
            } else {
                Button("授权") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 权限窗口控制器

final class PermissionsWindowController {
    static let shared = PermissionsWindowController()

    private var window: NSWindow?

    private init() {}

    /// 显示权限引导窗口（如果有未授权的权限）
    func showIfNeeded() {
        let manager = PermissionsManager.shared

        // 如果所有权限都已授予，不显示
        if manager.hasScreenCapturePermission && manager.hasAccessibilityPermission {
            print("✅ 所有权限已授予，跳过引导")
            return
        }

        // 检查是否已经显示过（本次启动只显示一次）
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        show()
    }

    /// 强制显示权限引导窗口
    func show() {
        let contentView = PermissionsOnboardingView(onClose: { [weak self] in
            self?.close()
        })

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

        // 监听窗口关闭
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }
}

import SwiftUI
import AVFoundation

// MARK: - 翻译结果视图（共享组件）

/// 翻译结果弹窗 - 毛玻璃风格
/// 用于截图翻译和文本选择翻译
struct TranslationResultView: View {
    let original: String
    let translated: String
    let onSave: () -> Void
    let onClose: () -> Void

    @State private var showCopiedOriginal = false
    @State private var showCopiedTranslation = false

    // 保持 synthesizer 引用，避免被释放导致发音中断
    private static let speechSynthesizer = AVSpeechSynthesizer()

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
                    }
                    .buttonStyle(OverlayIconButtonStyle(isActive: showCopiedOriginal))
                    .animation(.easeInOut(duration: 0.15), value: showCopiedOriginal)
                    // 朗读原文按钮
                    Button(action: speakOriginal) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(OverlayIconButtonStyle())
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
                    }
                    .buttonStyle(OverlayIconButtonStyle(isActive: showCopiedTranslation))
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
                }
                .buttonStyle(OverlayPrimaryButtonStyle())

                Button(action: onClose) {
                    Text("关闭")
                        .font(.system(size: 11))
                }
                .buttonStyle(OverlaySecondaryButtonStyle())

                Spacer()

                Text("ESC")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(FloatingPanelBackground())
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

    private func speakOriginal() {
        // 如果正在朗读，先停止
        if Self.speechSynthesizer.isSpeaking {
            Self.speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: original)
        // 根据文本内容自动选择语音
        if original.range(of: "\\p{Han}", options: .regularExpression) != nil {
            // 包含中文，使用中文语音
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        } else {
            // 默认使用英文语音
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        Self.speechSynthesizer.speak(utterance)
    }
}

// MARK: - 毛玻璃背景

/// 悬浮面板毛玻璃背景
struct FloatingPanelBackground: View {
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

// MARK: - 加载中视图

struct TranslationLoadingView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .colorInvert()
            Text("翻译中...")
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FloatingPanelBackground())
    }
}

// MARK: - 错误视图

struct TranslationErrorView: View {
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
            }
            .buttonStyle(OverlayIconButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FloatingPanelBackground())
    }
}

// MARK: - Overlay 按钮样式（深色背景用）

/// 主按钮样式（收藏按钮）- 深色背景用
struct OverlayPrimaryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.6) : (isHovering ? Color.blue.opacity(0.8) : Color.blue))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// 次要按钮样式（关闭按钮）- 深色背景用
struct OverlaySecondaryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovering ? .white : .white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.white.opacity(0.25) : (isHovering ? Color.white.opacity(0.2) : Color.white.opacity(0.15)))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// 图标按钮样式（复制、发音按钮）- 深色背景用
struct OverlayIconButtonStyle: ButtonStyle {
    var isActive: Bool = false
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .white.opacity(0.9) : (configuration.isPressed ? .white : (isHovering ? .white.opacity(0.8) : .white.opacity(0.5))))
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.white.opacity(0.25) : (isHovering ? Color.white.opacity(0.15) : Color.clear))
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

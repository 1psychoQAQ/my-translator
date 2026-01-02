/**
 * Web Speech API - 浏览器原生发音，零延迟
 */

export function speak(text: string, language?: string): void {
  // 取消之前的发音
  speechSynthesis.cancel();

  const utterance = new SpeechSynthesisUtterance(text);

  // 根据语言选择合适的语音
  utterance.lang = language || detectLanguage(text);
  utterance.rate = 1.0;
  utterance.pitch = 1.0;
  utterance.volume = 1.0;

  speechSynthesis.speak(utterance);
}

/**
 * 简单的语言检测（基于字符范围）
 */
function detectLanguage(text: string): string {
  // 检查是否包含中文字符
  if (/[\u4e00-\u9fa5]/.test(text)) {
    return 'zh-CN';
  }
  // 检查是否包含日文字符
  if (/[\u3040-\u309f\u30a0-\u30ff]/.test(text)) {
    return 'ja-JP';
  }
  // 检查是否包含韩文字符
  if (/[\uac00-\ud7af]/.test(text)) {
    return 'ko-KR';
  }
  // 默认英语
  return 'en-US';
}

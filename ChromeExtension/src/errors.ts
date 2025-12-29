export enum ErrorCode {
  NATIVE_MESSAGE_FAILED = 'NATIVE_MESSAGE_FAILED',
  NATIVE_HOST_NOT_FOUND = 'NATIVE_HOST_NOT_FOUND',
  TRANSLATION_FAILED = 'TRANSLATION_FAILED',
  TRANSLATION_EMPTY = 'TRANSLATION_EMPTY',
  SAVE_WORD_FAILED = 'SAVE_WORD_FAILED',
  WORD_ALREADY_EXISTS = 'WORD_ALREADY_EXISTS',
  INVALID_RESPONSE = 'INVALID_RESPONSE',
  TIMEOUT = 'TIMEOUT',
}

export class TranslatorError extends Error {
  constructor(
    public readonly code: ErrorCode,
    message: string,
    public readonly cause?: unknown
  ) {
    super(message);
    this.name = 'TranslatorError';
  }
}

export function createError(
  code: ErrorCode,
  message: string,
  cause?: unknown
): TranslatorError {
  return new TranslatorError(code, message, cause);
}

// User-friendly error messages (Chinese)
const ERROR_MESSAGES: Record<ErrorCode, string> = {
  [ErrorCode.NATIVE_MESSAGE_FAILED]: '与翻译应用通信失败，请确保应用已启动',
  [ErrorCode.NATIVE_HOST_NOT_FOUND]: '未找到翻译应用，请先安装 TranslatorApp',
  [ErrorCode.TRANSLATION_FAILED]: '翻译失败，请稍后重试',
  [ErrorCode.TRANSLATION_EMPTY]: '翻译结果为空',
  [ErrorCode.SAVE_WORD_FAILED]: '保存单词失败',
  [ErrorCode.WORD_ALREADY_EXISTS]: '单词已存在于单词本中',
  [ErrorCode.INVALID_RESPONSE]: '收到无效响应',
  [ErrorCode.TIMEOUT]: '请求超时，请重试',
};

export function getUserMessage(code: ErrorCode): string {
  return ERROR_MESSAGES[code] || '未知错误';
}

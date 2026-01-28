/**
 * Translator 下载服务 - Cloudflare Worker
 *
 * 路由：
 * - /mac         → 最新版 macOS（推荐）
 * - /latest/mac  → 最新版 macOS
 * - /latest      → 最新版 macOS（兼容旧链接）
 * - /v1.2.1/mac  → 指定版本
 * - /            → 下载页面
 * - /version     → 版本信息 API
 */

const GITHUB_REPO = '1psychoQAQ/my-translator';
const GITHUB_API = `https://api.github.com/repos/${GITHUB_REPO}/releases`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // /version - 返回最新版本信息
    if (path === '/version') {
      try {
        const release = await getRelease('latest', env);
        if (release) {
          return jsonResponse({ version: release.tag_name });
        }
        return jsonResponse({ version: '', error: 'no release' });
      } catch (e) {
        return jsonResponse({ version: '', error: e.message });
      }
    }

    // 根路径：显示下载页面
    if (path === '/' || path === '') {
      return new Response(downloadPage(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
    }

    // 解析路径：/mac, /latest/mac, /v1.2.1/mac, /latest, /v1.2.1
    const parts = path.split('/').filter(Boolean);
    let version = 'latest';

    if (parts.length === 1) {
      // /mac -> latest, /latest -> latest, /v1.2.1 -> v1.2.1
      if (parts[0] === 'mac') {
        version = 'latest';
      } else {
        version = parts[0];
      }
    } else if (parts.length >= 2) {
      // /latest/mac -> latest, /v1.2.1/mac -> v1.2.1
      version = parts[0];
    }

    try {
      const release = await getRelease(version, env);
      if (!release) {
        return new Response('版本不存在', { status: 404 });
      }

      // 查找 DMG 文件
      const asset = release.assets.find(a => a.name.endsWith('.dmg'));
      if (!asset) {
        return new Response('该版本没有 DMG 文件', { status: 404 });
      }

      // 代理下载
      const fileResponse = await fetch(asset.browser_download_url, {
        headers: { 'User-Agent': 'Translator-Download-Worker' },
      });

      if (!fileResponse.ok) {
        return new Response('下载失败', { status: 502 });
      }

      return new Response(fileResponse.body, {
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': `attachment; filename="${asset.name}"`,
          'Content-Length': asset.size,
        },
      });
    } catch (error) {
      return new Response(`错误: ${error.message}`, { status: 500 });
    }
  },
};

async function getRelease(version, env) {
  let apiUrl;
  if (version === 'latest') {
    apiUrl = `${GITHUB_API}/latest`;
  } else {
    apiUrl = `${GITHUB_API}/tags/${version}`;
  }

  const headers = {
    'User-Agent': 'Download-Worker',
    'Accept': 'application/vnd.github.v3+json',
  };
  if (env?.GITHUB_TOKEN) {
    headers['Authorization'] = `token ${env.GITHUB_TOKEN}`;
  }

  const response = await fetch(apiUrl, { headers });

  if (!response.ok) {
    if (response.status === 404) return null;
    throw new Error(`GitHub API 错误: ${response.status}`);
  }

  return response.json();
}

function downloadPage() {
  return `<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Translator - 下载</title>
  <style>
    @property --angle {
      syntax: '<angle>';
      initial-value: 0deg;
      inherits: false;
    }
    @property --glow {
      syntax: '<number>';
      initial-value: 0.5;
      inherits: false;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0a0a0f;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card-wrapper {
      position: relative;
      max-width: 500px;
      width: 100%;
    }
    /* 流光边框 - 外层发光 */
    .card-wrapper::before {
      content: '';
      position: absolute;
      inset: -3px;
      border-radius: 19px;
      background: conic-gradient(
        from var(--angle),
        #34d399, #10b981, #059669, #047857, #34d399
      );
      animation: rotate 3s linear infinite, glow 2s ease-in-out infinite;
      filter: blur(15px);
      opacity: var(--glow);
      z-index: -2;
    }
    /* 流光边框 - 主边框 */
    .card-wrapper::after {
      content: '';
      position: absolute;
      inset: -2px;
      border-radius: 18px;
      background: conic-gradient(
        from var(--angle),
        #34d399, #10b981, #059669, #047857, #34d399
      );
      animation: rotate 3s linear infinite;
      z-index: -1;
    }
    @keyframes rotate {
      to { --angle: 360deg; }
    }
    @keyframes glow {
      0%, 100% { --glow: 0.4; }
      50% { --glow: 0.8; }
    }
    .card-wrapper::before, .card-wrapper::after {
      transition: filter 0.2s ease-out, opacity 0.2s ease-out;
    }
    .card-wrapper:hover::before {
      filter: blur(18px);
      opacity: 0.7;
    }
    .card-wrapper:hover::after {
      filter: brightness(1.08);
    }
    .container {
      background: #12121a;
      border-radius: 16px;
      padding: 40px;
      text-align: center;
      position: relative;
      z-index: 1;
    }
    h1 {
      font-size: 28px;
      margin-bottom: 10px;
      color: #fff;
    }
    .subtitle {
      color: #888;
      margin-bottom: 30px;
    }
    /* 下载区域 */
    .download-section {
      margin: 20px 0;
    }
    .download-btn {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 16px 20px;
      border-radius: 12px;
      text-decoration: none;
      color: white;
      transition: transform 0.1s ease-out, box-shadow 0.15s ease-out, filter 0.15s ease-out;
      background: linear-gradient(135deg, #34d399 0%, #059669 100%);
      box-shadow: 0 4px 15px rgba(52,211,153,0.3);
    }
    .download-btn:hover {
      transform: translateY(-1px);
      filter: brightness(1.1);
      box-shadow: 0 6px 20px rgba(52,211,153,0.4);
    }
    .download-btn:active {
      transform: translateY(0);
    }
    .os-icon {
      width: 32px;
      height: 32px;
      flex-shrink: 0;
    }
    .download-info {
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      flex: 1;
    }
    .download-label {
      font-size: 16px;
      font-weight: 600;
    }
    .download-size {
      font-size: 12px;
      opacity: 0.7;
    }
    .download-arrow {
      width: 20px;
      height: 20px;
      opacity: 0.5;
    }
    .download-hint {
      color: #666;
      font-size: 11px;
      margin-top: 8px;
    }
    /* 折叠帮助 */
    .help-details {
      margin-top: 12px;
      text-align: left;
    }
    .help-details summary {
      color: #34d399;
      font-size: 12px;
      cursor: pointer;
      transition: color 0.1s ease-out;
    }
    .help-details summary:hover {
      color: #6ee7b7;
    }
    .help-details[open] summary {
      margin-bottom: 8px;
    }
    .help-content {
      background: rgba(255,255,255,0.03);
      border-radius: 6px;
      padding: 12px;
      font-size: 12px;
      color: #888;
    }
    .help-content p {
      margin: 8px 0;
    }
    .help-content strong {
      color: #aaa;
    }
    .help-content ol {
      margin: 10px 0;
      padding-left: 20px;
    }
    .help-content li {
      margin: 6px 0;
    }
    .features {
      margin-top: 30px;
      text-align: left;
      color: #aaa;
      font-size: 14px;
      list-style: none;
    }
    .features li {
      margin: 10px 0;
      padding-left: 24px;
      position: relative;
    }
    .features li::before {
      content: "✓";
      position: absolute;
      left: 0;
      color: #34d399;
      font-weight: bold;
    }
    .footer {
      margin-top: 30px;
      font-size: 12px;
      color: #666;
    }
    .footer a {
      color: #34d399;
      text-decoration: none;
      transition: color 0.1s ease-out, opacity 0.1s ease-out;
    }
    .footer a:hover {
      color: #6ee7b7;
      opacity: 0.9;
    }
    /* 版本标签 */
    .version-badge {
      display: inline-block;
      background: linear-gradient(135deg, #34d399 0%, #059669 100%);
      color: white;
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
      margin-bottom: 20px;
      letter-spacing: 0.5px;
    }
    /* 小终端 */
    .terminal {
      background: #1e1e1e;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
      margin-top: 10px;
    }
    .terminal-header {
      background: #323232;
      padding: 8px 12px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .terminal-dot {
      width: 12px;
      height: 12px;
      border-radius: 50%;
    }
    .terminal-dot.red { background: #ff5f56; }
    .terminal-dot.yellow { background: #ffbd2e; }
    .terminal-dot.green { background: #27ca40; }
    .terminal-title {
      color: #888;
      font-size: 12px;
      margin-left: 8px;
    }
    .terminal-code {
      display: block;
      padding: 12px;
      font-family: 'SF Mono', Monaco, 'Courier New', monospace;
      font-size: 11px;
      color: #f8f8f2;
      cursor: pointer;
      transition: background 0.08s ease-out;
      word-break: break-all;
    }
    .terminal-code:hover {
      background: #252525;
    }
    .terminal-code .prompt {
      color: #50fa7b;
      margin-right: 8px;
    }
    .terminal-code.copied {
      background: rgba(80,250,123,0.1);
    }
    .terminal-code.copied::after {
      content: '  ✓ 已复制';
      color: #50fa7b;
      font-size: 11px;
    }
    .copy-hint {
      color: #555;
      font-size: 10px;
      margin-top: 6px;
      text-align: right;
    }
    /* 步骤列表 */
    .steps {
      text-align: left;
      margin: 15px 0;
    }
    .step {
      display: flex;
      align-items: flex-start;
      gap: 10px;
      margin: 12px 0;
      color: #aaa;
      font-size: 13px;
    }
    .step-num {
      background: #34d399;
      color: #000;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      font-weight: 600;
      flex-shrink: 0;
    }
    .step-text {
      padding-top: 1px;
    }
    .step-text code {
      background: rgba(52,211,153,0.15);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'SF Mono', Monaco, monospace;
      font-size: 11px;
      color: #34d399;
    }
  </style>
</head>
<body>
  <div class="card-wrapper">
    <div class="container">
      <span class="version-badge" id="version-badge">加载中...</span>
      <h1>Translator</h1>
      <p class="subtitle">划词翻译 + 截图翻译，macOS 原生体验</p>

      <div class="download-section">
        <a href="/mac" class="download-btn">
          <svg class="os-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
          <div class="download-info">
            <span class="download-label">macOS 版本</span>
            <span class="download-size">DMG 安装包 · 791 KB</span>
          </div>
          <svg class="download-arrow" viewBox="0 0 24 24" fill="currentColor"><path d="M12 16l-6-6h12z"/></svg>
        </a>
        <p class="download-hint">需要 macOS 15.0 (Sequoia) 或更高版本</p>

        <details class="help-details">
          <summary>🔐 需要授权哪些权限？</summary>
          <div class="help-content">
            <p>首次使用时，系统会请求以下权限：</p>

            <div class="steps">
              <div class="step">
                <span class="step-num">1</span>
                <span class="step-text"><strong>辅助功能</strong> — 用于获取选中的文本，实现划词翻译</span>
              </div>
              <div class="step">
                <span class="step-num">2</span>
                <span class="step-text"><strong>屏幕录制</strong> — 用于截取屏幕区域，实现截图翻译</span>
              </div>
            </div>

            <p style="margin-top: 12px; font-size: 11px; color: #666;">所有数据均在本地处理，不会上传到任何服务器。</p>
          </div>
        </details>
      </div>

      <ul class="features">
        <li>划词翻译：选中文本 + <code>⌥T</code> 即时翻译</li>
        <li>截图翻译：<code>⌘⇧S</code> 截取区域 OCR 翻译</li>
        <li>智能粘贴：截图复制自动适配图片/路径</li>
        <li>单词本：收藏单词，支持导出 CSV/JSON</li>
        <li>完全本地：使用 Apple 翻译引擎，隐私安全</li>
      </ul>

      <p class="footer">
        <a href="https://github.com/${GITHUB_REPO}" target="_blank">GitHub</a>
        &nbsp;·&nbsp;
        <a href="https://github.com/${GITHUB_REPO}/releases" target="_blank">所有版本</a>
      </p>
    </div>
  </div>
  <script>
    fetch('/version')
      .then(r => r.json())
      .then(d => {
        if (d.version) document.getElementById('version-badge').textContent = d.version;
      })
      .catch(() => {
        document.getElementById('version-badge').textContent = '最新版';
      });
  </script>
</body>
</html>`;
}

function jsonResponse(data) {
  return new Response(JSON.stringify(data), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

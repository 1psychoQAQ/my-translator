/**
 * Translator 下载服务 - Cloudflare Worker
 *
 * 路由：
 * - /latest      → 最新版 macOS
 * - /v1.1.5      → 指定版本
 * - /            → 下载页面
 * - /version     → 版本信息 API
 */

const GITHUB_REPO = '1psychoQAQ/my-translator';
const GITHUB_API = `https://api.github.com/repos/${GITHUB_REPO}/releases`;

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    // /version - 返回最新版本信息
    if (path === '/version') {
      try {
        const release = await getRelease('latest');
        if (release) {
          return jsonResponse({ version: release.tag_name });
        }
      } catch (e) {}
      return jsonResponse({ version: '' });
    }

    // 根路径：显示下载页面
    if (path === '/' || path === '') {
      return new Response(downloadPage(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
    }

    // 解析版本：/latest 或 /v1.1.5
    const version = path.split('/').filter(Boolean)[0] || 'latest';

    try {
      const release = await getRelease(version);
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

async function getRelease(version) {
  let apiUrl;
  if (version === 'latest') {
    apiUrl = `${GITHUB_API}/latest`;
  } else {
    apiUrl = `${GITHUB_API}/tags/${version}`;
  }

  const response = await fetch(apiUrl, {
    headers: {
      'User-Agent': 'Translator-Download-Worker',
      'Accept': 'application/vnd.github.v3+json',
    },
  });

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
    .container {
      background: #12121a;
      border-radius: 16px;
      padding: 40px;
      text-align: center;
      max-width: 420px;
      border: 1px solid #2a2a3a;
    }
    h1 {
      font-size: 28px;
      margin-bottom: 10px;
      color: #fff;
    }
    .subtitle {
      color: #888;
      margin-bottom: 30px;
      font-size: 14px;
    }
    .download-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      padding: 16px 32px;
      border-radius: 12px;
      text-decoration: none;
      color: white;
      background: linear-gradient(135deg, #555 0%, #333 100%);
      box-shadow: 0 4px 15px rgba(0,0,0,0.3);
      transition: transform 0.1s, box-shadow 0.15s;
      margin: 20px auto;
    }
    .download-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(0,0,0,0.4);
    }
    .download-btn svg {
      width: 24px;
      height: 24px;
    }
    .features {
      margin-top: 30px;
      text-align: left;
      color: #aaa;
      font-size: 14px;
      list-style: none;
    }
    .features li {
      margin: 12px 0;
      padding-left: 28px;
      position: relative;
    }
    .features li::before {
      content: "✓";
      position: absolute;
      left: 0;
      color: #00c853;
      font-weight: bold;
    }
    .note {
      margin-top: 25px;
      padding: 15px;
      background: rgba(255,243,205,0.08);
      border: 1px solid rgba(255,243,205,0.15);
      border-radius: 8px;
      font-size: 12px;
      color: #999;
      text-align: left;
    }
    .note code {
      background: rgba(255,255,255,0.1);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'SF Mono', Monaco, monospace;
      font-size: 11px;
    }
    .footer {
      margin-top: 25px;
      font-size: 12px;
      color: #666;
    }
    .footer a {
      color: #888;
      text-decoration: none;
    }
    .footer a:hover {
      color: #fff;
    }
    .version {
      display: inline-block;
      background: #1a1a2e;
      color: #888;
      padding: 4px 10px;
      border-radius: 12px;
      font-size: 12px;
      margin-bottom: 20px;
    }
    .req {
      color: #666;
      font-size: 11px;
      margin-top: 8px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Translator</h1>
    <p class="subtitle">划词翻译 + 截图翻译，macOS 原生体验</p>
    <span class="version">macOS 15.0+</span>

    <a href="/latest" class="download-btn">
      <svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
      下载 macOS 版
    </a>
    <p class="req">DMG 安装包 · 约 800KB</p>

    <ul class="features">
      <li>划词翻译 <code>⌥T</code></li>
      <li>截图翻译 + OCR <code>⌘⇧S</code></li>
      <li>智能剪贴板（图片/文件路径）</li>
      <li>生词本导出 CSV/JSON</li>
      <li>Apple 本地翻译引擎，隐私安全</li>
    </ul>

    <div class="note">
      <strong>首次打开提示"无法验证开发者"？</strong><br><br>
      右键点击应用 → 选择「打开」→ 再次点击「打开」<br>
      或终端执行：<code>xattr -cr /Applications/Translator.app</code>
    </div>

    <p class="footer">
      <a href="https://github.com/${GITHUB_REPO}" target="_blank">GitHub</a> ·
      <a href="https://github.com/${GITHUB_REPO}/releases" target="_blank">所有版本</a>
    </p>
  </div>
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

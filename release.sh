#!/bin/bash
#
# 一键打包并发布到 GitHub Releases
#
# 用法: ./release.sh <版本号>
# 例如: ./release.sh 1.0.0
#

set -e

if [ -z "$1" ]; then
    echo "用法: ./release.sh <版本号>"
    echo "例如: ./release.sh 1.0.0"
    exit 1
fi

VERSION="$1"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$PROJECT_ROOT/release"

echo "================================================"
echo "  Translator Release v$VERSION"
echo "================================================"
echo ""

# 清除可能干扰 gh 的环境变量
unset GITHUB_TOKEN

# 检查 gh 是否已登录
if ! gh auth status &>/dev/null; then
    echo "❌ GitHub CLI 未登录"
    echo "请先运行: gh auth login"
    exit 1
fi

# 清理旧的发布目录
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# ==================== macOS App ====================
echo "[1/5] Building macOS App..."

cd "$PROJECT_ROOT/TranslatorApp"

xcodebuild -project TranslatorApp.xcodeproj \
    -scheme TranslatorApp \
    -configuration Release \
    -derivedDataPath "$RELEASE_DIR/build" \
    CONFIGURATION_BUILD_DIR="$RELEASE_DIR/app" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

echo "    ✓ TranslatorApp.app"

# ==================== Native Messaging Host ====================
echo "[2/5] Building Native Messaging Host..."

cd "$PROJECT_ROOT/TranslatorApp/NativeMessagingHost"
swift build -c release --quiet

cp .build/release/NativeMessagingHost "$RELEASE_DIR/app/TranslatorApp.app/Contents/MacOS/"
echo "    ✓ NativeMessagingHost"

# ==================== 创建 DMG ====================
echo "[3/5] Creating DMG..."

DMG_NAME="TranslatorApp-$VERSION.dmg"
TEMP_DIR=$(mktemp -d)

cp -R "$RELEASE_DIR/app/TranslatorApp.app" "$TEMP_DIR/"
ln -s /Applications "$TEMP_DIR/Applications"

hdiutil create -volname "TranslatorApp" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$RELEASE_DIR/$DMG_NAME" \
    -quiet

rm -rf "$TEMP_DIR"
echo "    ✓ $DMG_NAME"

# ==================== Chrome Extension ====================
echo "[4/5] Building Chrome Extension..."

cd "$PROJECT_ROOT/ChromeExtension"
npm run build --silent

cd dist
zip -rq "$RELEASE_DIR/TranslatorExtension-$VERSION.zip" .
echo "    ✓ TranslatorExtension-$VERSION.zip"

# ==================== 清理临时文件 ====================
rm -rf "$RELEASE_DIR/build"
rm -rf "$RELEASE_DIR/app"

# ==================== 上传到 GitHub ====================
echo "[5/5] Uploading to GitHub..."

cd "$PROJECT_ROOT"

# 创建 Release 并上传文件
gh release create "v$VERSION" \
    "$RELEASE_DIR/$DMG_NAME" \
    "$RELEASE_DIR/TranslatorExtension-$VERSION.zip" \
    --title "v$VERSION" \
    --notes "## Downloads

- **macOS App**: \`$DMG_NAME\` - 拖入 Applications 安装
- **Chrome Extension**: \`TranslatorExtension-$VERSION.zip\` - 在 chrome://extensions 开发者模式加载

## Installation

See [INSTALLATION.md](docs/INSTALLATION.md) for detailed instructions."

echo ""
echo "================================================"
echo "  ✓ Released v$VERSION to GitHub!"
echo "================================================"
echo ""
gh release view "v$VERSION" --web

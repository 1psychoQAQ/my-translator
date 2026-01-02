#!/bin/bash
#
# 一键打包发布脚本
# 生成 GitHub Release 所需的所有文件
#
# 用法: ./release.sh [版本号]
# 例如: ./release.sh 1.0.0
#

set -e

VERSION="${1:-1.0.0}"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$PROJECT_ROOT/release"

echo "================================================"
echo "  Translator Release Builder v$VERSION"
echo "================================================"
echo ""

# 清理旧的发布目录
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# ==================== macOS App ====================
echo "[1/4] Building macOS App..."

cd "$PROJECT_ROOT/TranslatorApp"

# 使用 xcodebuild 构建 Release 版本
xcodebuild -project TranslatorApp.xcodeproj \
    -scheme TranslatorApp \
    -configuration Release \
    -derivedDataPath "$RELEASE_DIR/build" \
    CONFIGURATION_BUILD_DIR="$RELEASE_DIR/app" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

echo "    ✓ TranslatorApp.app built"

# ==================== Native Messaging Host ====================
echo "[2/4] Building Native Messaging Host..."

cd "$PROJECT_ROOT/TranslatorApp/NativeMessagingHost"
swift build -c release --quiet

# 复制到 App 包内
cp .build/release/NativeMessagingHost "$RELEASE_DIR/app/TranslatorApp.app/Contents/MacOS/"
echo "    ✓ NativeMessagingHost built and bundled"

# ==================== 创建 DMG ====================
echo "[3/4] Creating DMG..."

DMG_NAME="TranslatorApp-$VERSION.dmg"
TEMP_DIR=$(mktemp -d)

# 准备 DMG 内容
cp -R "$RELEASE_DIR/app/TranslatorApp.app" "$TEMP_DIR/"
ln -s /Applications "$TEMP_DIR/Applications"

# 创建 DMG
hdiutil create -volname "TranslatorApp" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "$RELEASE_DIR/$DMG_NAME" \
    -quiet

rm -rf "$TEMP_DIR"
echo "    ✓ $DMG_NAME created"

# ==================== Chrome Extension ====================
echo "[4/4] Building Chrome Extension..."

cd "$PROJECT_ROOT/ChromeExtension"
npm run build --silent

# 打包成 zip
cd dist
zip -rq "$RELEASE_DIR/TranslatorExtension-$VERSION.zip" .
echo "    ✓ TranslatorExtension-$VERSION.zip created"

# ==================== 清理临时文件 ====================
rm -rf "$RELEASE_DIR/build"
rm -rf "$RELEASE_DIR/app"

# ==================== 完成 ====================
echo ""
echo "================================================"
echo "  Release files ready!"
echo "================================================"
echo ""
echo "Files in $RELEASE_DIR:"
ls -lh "$RELEASE_DIR"
echo ""
echo "Upload to GitHub:"
echo "  1. Go to: https://github.com/YOUR_USERNAME/my-translator/releases/new"
echo "  2. Tag: v$VERSION"
echo "  3. Upload these files"
echo ""

# Translator - Makefile

.PHONY: build release sign notarize dmg deploy deploy-page deploy-worker status help

# 版本号从 git tag 获取
VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
APP_PATH := TranslatorApp/build/Release/TranslatorApp.app
DMG_PATH := TranslatorApp/TranslatorApp-$(VERSION).dmg

# 检查 tag
check-tag:
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ 当前没有 tag，请先创建: git tag v1.x.x"; \
		exit 1; \
	fi

# 检查签名环境变量
check-signing:
	@if [ -z "$$APPLE_SIGNING_IDENTITY" ]; then \
		echo "❌ 未设置 APPLE_SIGNING_IDENTITY 环境变量"; \
		exit 1; \
	fi

# 构建 Debug 版本
build:
	@echo "🔨 构建 Debug 版本..."
	cd TranslatorApp && xcodebuild -project TranslatorApp.xcodeproj \
		-scheme TranslatorApp -configuration Debug build

# 构建 Release 版本
release: check-tag
	@echo "🚀 构建 Release 版本 (v$(VERSION))..."
	cd TranslatorApp && rm -rf build && xcodebuild -project TranslatorApp.xcodeproj \
		-scheme TranslatorApp -configuration Release build SYMROOT=./build
	@echo "✅ 构建完成: $(APP_PATH)"

# 签名 .app
sign: release check-signing
	@echo "🔐 签名 .app..."
	codesign --deep --force --options runtime \
		--sign "$$APPLE_SIGNING_IDENTITY" \
		"$(APP_PATH)"
	@echo "✅ 签名完成"

# 公证
notarize: sign
	@echo "📤 提交公证..."
	cd TranslatorApp && ditto -c -k --keepParent "build/Release/TranslatorApp.app" "TranslatorApp.zip"
	xcrun notarytool submit "TranslatorApp/TranslatorApp.zip" \
		--keychain-profile "notary" --wait
	@echo "📎 Staple 公证票据..."
	xcrun stapler staple "$(APP_PATH)"
	rm -f TranslatorApp/TranslatorApp.zip
	@echo "✅ 公证完成"

# 创建 DMG（专业版，带拖拽安装界面）
dmg: notarize check-signing
	@echo "📦 创建 DMG..."
	cd TranslatorApp && rm -f TranslatorApp-$(VERSION).dmg && \
	create-dmg \
		--volname "TranslatorApp" \
		--background "dmg-background.png" \
		--window-pos 200 120 \
		--window-size 540 380 \
		--icon-size 100 \
		--icon "TranslatorApp.app" 130 190 \
		--app-drop-link 410 190 \
		TranslatorApp-$(VERSION).dmg \
		build/Release/TranslatorApp.app
	@echo "🔐 签名 DMG..."
	codesign --force --sign "$$APPLE_SIGNING_IDENTITY" "$(DMG_PATH)"
	@echo "✅ DMG 创建完成: $(DMG_PATH)"

# 上线新版本（构建 + 签名 + 公证 + DMG + 上传）
deploy: dmg
	@echo "📤 推送 tag 到远程..."
	@git push origin "v$(VERSION)" 2>/dev/null || true
	@echo "📤 上传到 GitHub Release..."
	@if [ -f "$(DMG_PATH)" ]; then \
		gh release create "v$(VERSION)" "$(DMG_PATH)" --title "v$(VERSION)" --notes "版本 $(VERSION)" 2>/dev/null || \
		gh release upload "v$(VERSION)" "$(DMG_PATH)" --clobber; \
		echo "✅ 已上传: v$(VERSION)"; \
	else \
		echo "❌ DMG 文件不存在: $(DMG_PATH)"; exit 1; \
	fi
	@echo "✅ 上线完成: v$(VERSION)"
	@echo "📍 下载页: https://translator.makestuff.top"

# 部署下载页面（通过 Worker）
deploy-page: deploy-worker

# 部署 Cloudflare Worker
deploy-worker:
	@echo "📤 部署 Cloudflare Worker..."
	cd download-worker && npx wrangler deploy
	@echo "✅ Worker 部署完成"

# 查看当前状态
status:
	@echo "Translator 状态"
	@echo "────────────────────────────────"
	@echo "本地版本: v$(VERSION)"
	@echo ""
	@echo "GitHub Release:"
	@gh release list --limit 3 2>/dev/null || echo "  (无法获取)"
	@echo ""
	@echo "Worker 版本 (自动获取最新):"
	@curl -s https://translator.makestuff.top/version 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "  (无法获取)"

# 帮助
help:
	@echo "Translator - 可用命令"
	@echo "────────────────────────────────"
	@echo "构建:"
	@echo "  make build         构建 Debug 版本"
	@echo "  make release       构建 Release 版本"
	@echo "  make sign          签名 .app"
	@echo "  make notarize      公证"
	@echo "  make dmg           创建签名 DMG"
	@echo ""
	@echo "部署:"
	@echo "  make deploy        上线新版本（一键完成全部流程）"
	@echo "  make deploy-worker 部署下载代理 Worker"
	@echo ""
	@echo "发版流程:"
	@echo "  git tag v1.x.x && make deploy"
	@echo ""
	@echo "其他:"
	@echo "  make status        查看当前状态"
	@echo "────────────────────────────────"

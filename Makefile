# Translator - Makefile

.PHONY: build release deploy deploy-page deploy-worker status help

# 版本号从 git tag 获取
VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')

# 检查 tag
check-tag:
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ 当前没有 tag，请先创建: git tag v1.x.x"; \
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
	@echo "✅ 构建完成: TranslatorApp/build/Release/TranslatorApp.app"

# 创建 DMG (需要先 make release)
dmg: release
	@echo "📦 创建 DMG..."
	cd TranslatorApp && rm -f TranslatorApp-$(VERSION).dmg && \
	hdiutil create -volname "TranslatorApp" -srcfolder build/Release/TranslatorApp.app \
		-ov -format UDZO TranslatorApp-$(VERSION).dmg
	@echo "✅ DMG 创建完成: TranslatorApp/TranslatorApp-$(VERSION).dmg"

# 上线新版本（构建 DMG + 上传 GitHub Release）
# Worker 会自动获取最新版本，无需手动更新下载页
deploy: dmg
	@echo "📤 上传到 GitHub Release..."
	@DMG_FILE="TranslatorApp/TranslatorApp-$(VERSION).dmg"; \
	if [ -f "$$DMG_FILE" ]; then \
		gh release create "v$(VERSION)" "$$DMG_FILE" --title "v$(VERSION)" --notes "版本 $(VERSION)" 2>/dev/null || \
		gh release upload "v$(VERSION)" "$$DMG_FILE" --clobber; \
		echo "✅ 已上传: v$(VERSION)"; \
	else \
		echo "❌ DMG 文件不存在: $$DMG_FILE"; exit 1; \
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
	@echo "  make dmg           创建 DMG 安装包"
	@echo ""
	@echo "部署:"
	@echo "  make deploy        上线新版本（DMG+GitHub Release）"
	@echo "  make deploy-worker 部署下载代理 Worker"
	@echo ""
	@echo "发版流程:"
	@echo "  git tag v1.x.x && make deploy"
	@echo ""
	@echo "其他:"
	@echo "  make status        查看当前状态"
	@echo "────────────────────────────────"

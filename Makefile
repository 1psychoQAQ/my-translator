# Translator - Makefile
# 环境变量: DEPLOY_HOST, DEPLOY_KEY, DEPLOY_PATH (在 ~/.zshrc 中配置)

.PHONY: build release deploy deploy-page deploy-worker status logs help

# 检查环境变量
check-env:
	@test -n "$(DEPLOY_HOST)" || (echo "❌ 请设置 DEPLOY_HOST 环境变量" && exit 1)
	@test -n "$(DEPLOY_KEY)" || (echo "❌ 请设置 DEPLOY_KEY 环境变量" && exit 1)
	@test -n "$(DEPLOY_PATH)" || (echo "❌ 请设置 DEPLOY_PATH 环境变量" && exit 1)

# 构建 Debug 版本
build:
	@echo "🔨 构建 Debug 版本..."
	cd TranslatorApp && xcodebuild -project TranslatorApp.xcodeproj \
		-scheme TranslatorApp -configuration Debug build

# 构建 Release 版本
release:
	@echo "🚀 构建 Release 版本..."
	cd TranslatorApp && rm -rf build && xcodebuild -project TranslatorApp.xcodeproj \
		-scheme TranslatorApp -configuration Release build SYMROOT=./build
	@echo "✅ 构建完成: TranslatorApp/build/Release/TranslatorApp.app"

# 创建 DMG (需要先 make release)
dmg: release
	@echo "📦 创建 DMG..."
	@VERSION=$$(grep -A1 'MARKETING_VERSION' TranslatorApp/TranslatorApp.xcodeproj/project.pbxproj | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "1.0.0"); \
	cd TranslatorApp && rm -f TranslatorApp-$$VERSION.dmg && \
	hdiutil create -volname "TranslatorApp" -srcfolder build/Release/TranslatorApp.app \
		-ov -format UDZO TranslatorApp-$$VERSION.dmg && \
	echo "✅ DMG 创建完成: TranslatorApp/TranslatorApp-$$VERSION.dmg"

# 上线新版本（构建 DMG + 上传 GitHub Release + 更新下载页 + 推送代码）
deploy: dmg check-env
	@VERSION=$$(grep -A1 'MARKETING_VERSION' TranslatorApp/TranslatorApp.xcodeproj/project.pbxproj | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "1.0.0"); \
	DMG_FILE="TranslatorApp/TranslatorApp-$$VERSION.dmg"; \
	echo "📤 上传到 GitHub Release..."; \
	if [ -f "$$DMG_FILE" ]; then \
		gh release create "v$$VERSION" "$$DMG_FILE" --title "v$$VERSION" --notes "版本 $$VERSION" 2>/dev/null || \
		gh release upload "v$$VERSION" "$$DMG_FILE" --clobber; \
		echo "✅ 已上传: v$$VERSION"; \
	else \
		echo "❌ DMG 文件不存在: $$DMG_FILE"; exit 1; \
	fi; \
	echo "📤 更新下载页面..."; \
	sed -i '' "s/version-badge\">v[0-9.]*</version-badge\">v$$VERSION</g" download-page/index.html; \
	sed -i '' "s/download\/v[0-9.]*\/TranslatorApp-[0-9.]*.dmg/download\/v$$VERSION\/TranslatorApp-$$VERSION.dmg/g" download-page/index.html; \
	scp -i $(DEPLOY_KEY) download-page/index.html root@$(DEPLOY_HOST):$(DEPLOY_PATH)/static/translator/; \
	echo "✅ 下载页已更新: v$$VERSION"
	@echo "📤 推送代码..."
	git push || echo "⚠️ 推送失败，请手动 git push"
	@echo "✅ 上线完成"

# 部署下载页面到服务器
deploy-page: check-env
	@echo "📤 部署下载页面..."
	scp -i $(DEPLOY_KEY) download-page/index.html root@$(DEPLOY_HOST):$(DEPLOY_PATH)/static/translator/
	@echo "✅ 部署完成: https://translator.makestuff.top"

# 部署 Cloudflare Worker
deploy-worker:
	@echo "📤 部署 Cloudflare Worker..."
	cd download-worker && npx wrangler deploy
	@echo "✅ Worker 部署完成"

# 查看当前状态
status: check-env
	@echo "Translator 状态"
	@echo "────────────────────────────────"
	@VERSION=$$(grep -A1 'MARKETING_VERSION' TranslatorApp/TranslatorApp.xcodeproj/project.pbxproj | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown"); \
	echo "本地版本: v$$VERSION"
	@echo ""
	@echo "GitHub Release:"
	@gh release list --limit 3 2>/dev/null || echo "  (无法获取)"
	@echo ""
	@echo "下载页版本:"
	@ssh -i $(DEPLOY_KEY) root@$(DEPLOY_HOST) "grep -o 'v[0-9.]*' $(DEPLOY_PATH)/static/translator/index.html | head -1" 2>/dev/null || echo "  (无法获取)"

# 查看服务器日志
logs: check-env
	ssh -i $(DEPLOY_KEY) root@$(DEPLOY_HOST) "tail -f /var/log/nginx/access.log | grep translator"

# SSH 到服务器
ssh: check-env
	ssh -i $(DEPLOY_KEY) root@$(DEPLOY_HOST)

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
	@echo "  make deploy        上线新版本（DMG+GitHub Release+下载页）"
	@echo "  make deploy-page   只部署下载页面"
	@echo "  make deploy-worker 部署下载代理 Worker"
	@echo ""
	@echo "其他:"
	@echo "  make status        查看当前状态"
	@echo "  make logs          查看服务器日志"
	@echo "  make ssh           SSH 到服务器"
	@echo "────────────────────────────────"

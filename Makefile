APP     := Revvy
SCHEME  := IssueShot
DERIVED := build
ARCH    := $(shell uname -m)
APP_PATH := $(DERIVED)/Build/Products/Debug/$(APP).app

.PHONY: generate open build run test clean dist notary-setup appstore appstore-upload appstore-check

generate: ## project.yml から .xcodeproj を生成
	xcodegen generate

open: generate ## Xcode で開く
	open $(APP).xcodeproj

build: generate ## Debug ビルド
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(ARCH)' -quiet build

run: build ## ビルドして起動
	open $(APP_PATH)

test: generate ## テスト実行
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(ARCH)' -quiet test

clean: ## ビルド成果物を削除
	rm -rf $(DERIVED) $(APP).xcodeproj

# --- 配布 ---------------------------------------------------------------

TEAM_ID ?=
NOTARY_PROFILE ?= Revvy-notary
APPLE_ID ?=

notary-setup: ## 公証用の資格情報を Keychain に保存（App 用パスワードを対話で聞かれる）
	@test -n "$(TEAM_ID)" || { echo "TEAM_ID is required"; exit 1; }
	@test -n "$(APPLE_ID)" || { echo "使い方: make notary-setup APPLE_ID=you@example.com"; exit 1; }
	xcrun notarytool store-credentials "$(NOTARY_PROFILE)" --apple-id "$(APPLE_ID)" --team-id "$(TEAM_ID)"

dist: ## Developer ID で署名 → 公証 → DMG（dist/Revvy-<ver>.dmg）
	TEAM_ID="$(TEAM_ID)" NOTARY_PROFILE="$(NOTARY_PROFILE)" ./scripts/dist.sh

# --- Mac App Store ---------------------------------------------------------

appstore: ## App Store 提出用 .pkg を作る（送信しない）: dist/appstore/export/Revvy.pkg
	TEAM_ID="$(TEAM_ID)" ./scripts/appstore.sh

appstore-upload: ## App Store 提出用ビルドを作って App Store Connect に送信する
	TEAM_ID="$(TEAM_ID)" ./scripts/appstore.sh --upload

appstore-check: generate ## サンドボックス版をアドホック署名でビルドする（アカウント不要。動作確認用）
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration AppStore \
		-derivedDataPath $(DERIVED)/appstore-check -destination 'platform=macOS,arch=$(ARCH)' -quiet build \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=

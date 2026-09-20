#!/bin/zsh
# Mac App Store 提出用のビルドを作る: AppStore 構成でアーカイブ → App Store Connect 向けにエクスポート（.pkg）。
#
# 事前準備（1 回だけ）:
#   - project.yml の AppStore 構成の Bundle ID を自分のものに変える
#   - Xcode > Settings > Accounts に、自分のチームで Admin か App Manager の Apple ID を追加する
#   - App Store Connect でその Bundle ID のアプリを作成する（docs/APP_STORE.md）
#
# 使い方:  make appstore TEAM_ID=YOUR_TEAM_ID            → .pkg を作るだけ（送信しない）
#          make appstore-upload TEAM_ID=YOUR_TEAM_ID     → 作ったうえで App Store Connect に送信する
#
# 署名は自動管理。初回は Apple Distribution 証明書とプロビジョニングプロファイルを Xcode が作成・登録する。
set -euo pipefail

UPLOAD=0
[[ "${1:-}" == "--upload" ]] && UPLOAD=1

APP=Revvy
TEAM_ID=${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/dist/appstore"
ARCHIVE="$OUT/$APP.xcarchive"

cd "$ROOT"
rm -rf "$OUT"
mkdir -p "$OUT"

echo "▶ プロジェクト生成"
xcodegen generate >/dev/null

echo "▶ アーカイブ（AppStore 構成・Apple Silicon と Intel の両対応）"
xcodebuild -project "$APP.xcodeproj" -scheme IssueShot -configuration AppStore \
  -destination "generic/platform=macOS" -archivePath "$ARCHIVE" -quiet archive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID"

APP_PATH="$ARCHIVE/Products/Applications/$APP.app"
echo "▶ 提出前チェック"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP_PATH/Contents/Info.plist")
echo "  Bundle ID: $BUNDLE_ID / バージョン $VERSION ($BUILD)"
codesign -d --entitlements - --xml "$APP_PATH" 2>/dev/null | grep -q "com.apple.security.app-sandbox" \
  || { echo "✗ App Sandbox が有効になっていません" >&2; exit 1; }
[[ -f "$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy" ]] || { echo "✗ PrivacyInfo.xcprivacy が入っていません" >&2; exit 1; }
lipo -archs "$APP_PATH/Contents/MacOS/$APP"

EXPORT_OPTIONS="$OUT/ExportOptions.plist"
cp scripts/ExportOptions-AppStore.plist "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$EXPORT_OPTIONS"
if (( UPLOAD )); then
  /usr/libexec/PlistBuddy -c "Set :destination upload" "$EXPORT_OPTIONS"
  echo "▶ App Store Connect へ送信（Xcode に登録したアカウントを使います）"
else
  echo "▶ エクスポート（送信はしない）"
fi
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
  -exportOptionsPlist "$EXPORT_OPTIONS" -allowProvisioningUpdates -quiet

echo
if (( UPLOAD )); then
  echo "✅ 送信しました。App Store Connect の「TestFlight」にビルド $VERSION ($BUILD) が処理後に表示されます。"
  echo "   次に提出するときは project.yml の CURRENT_PROJECT_VERSION を上げてください。"
else
  echo "✅ 完成: $(ls "$OUT"/export/*.pkg)"
fi

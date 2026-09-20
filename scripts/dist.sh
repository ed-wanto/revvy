#!/bin/zsh
# Revvy を Developer ID で署名 → Apple に公証 → ステープル → DMG 化する。
#
# 事前準備（1 回だけ）:
#   1. Developer ID Application 証明書を Keychain に入れる（Xcode > Settings > Accounts > Manage Certificates）
#   2. 公証用の資格情報を保存する:  make notary-setup
#
# 使い方:  make dist   →  dist/Revvy-<version>.dmg
#          ./scripts/dist.sh --no-notarize  （署名と DMG だけ。動作確認用）
set -euo pipefail

NOTARIZE=1
[[ "${1:-}" == "--no-notarize" ]] && NOTARIZE=0

APP=Revvy
TEAM_ID=${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}
NOTARY_PROFILE=${NOTARY_PROFILE:-Revvy-notary}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIST="$ROOT/dist"
ARCHIVE="$DIST/$APP.xcarchive"
EXPORT="$DIST/export"

cd "$ROOT"

echo "▶ 前提チェック"
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "✗ Developer ID Application 証明書が Keychain にありません。" >&2
  echo "  Xcode > Settings > Accounts > (チーム) > Manage Certificates > + > Developer ID Application" >&2
  exit 1
fi
if (( NOTARIZE )) && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "✗ 公証用の資格情報 '$NOTARY_PROFILE' がありません。先に make notary-setup を実行してください。" >&2
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$DIST"

echo "▶ プロジェクト生成"
xcodegen generate >/dev/null

echo "▶ アーカイブ（Release・Apple Silicon と Intel の両対応）"
xcodebuild -project "$APP.xcodeproj" -scheme IssueShot -configuration Release \
  -destination "generic/platform=macOS" -archivePath "$ARCHIVE" -quiet archive \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

echo "▶ エクスポート（Developer ID）"
EXPORT_OPTIONS="$DIST/ExportOptions.plist"
cp scripts/ExportOptions.plist "$EXPORT_OPTIONS"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$EXPORT_OPTIONS"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$EXPORT_OPTIONS" -quiet

APP_PATH="$EXPORT/$APP.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
DMG="$DIST/$APP-$VERSION.dmg"

echo "▶ 署名の検証"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv "$APP_PATH" 2>&1 | grep -E "Authority=Developer ID|TeamIdentifier"

echo "▶ DMG 作成（インストール画面つき）"
# 背景とボリュームアイコンを作り直してから、dmgbuild でレイアウトごと組み立てる。
# dmgbuild が無い環境では、素の DMG にフォールバックする。
python3 scripts/make-dmg-background.py
DMGBUILD=$(command -v dmgbuild || echo "$HOME/Library/Python/3.9/bin/dmgbuild")
if [[ -x "$DMGBUILD" ]]; then
  REVVY_ROOT="$ROOT" REVVY_APP="$APP_PATH" "$DMGBUILD" -s scripts/dmg-settings.py "$APP" "$DMG"
else
  echo "  ! dmgbuild が無いので素の DMG を作ります（pip3 install --user dmgbuild で導入）" >&2
  STAGE="$DIST/dmg-root"
  mkdir -p "$STAGE"
  cp -R "$APP_PATH" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
fi
codesign --sign "Developer ID Application" --timestamp "$DMG"

if (( NOTARIZE )); then
  echo "▶ 公証（Apple に送信して待機。数分かかります）"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

  echo "▶ ステープル"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"

  echo "▶ Gatekeeper 検証"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
else
  echo "▶ 公証はスキップ（--no-notarize）。配布前に make dist を実行すること"
fi

rm -rf "${STAGE:-}" "$EXPORT" "$ARCHIVE"
echo
echo "✅ 完成: $DMG"

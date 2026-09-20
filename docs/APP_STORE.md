# Mac App Store build (optional)

**English** · [日本語](#日本語)

Revvy is distributed as a signed and notarized DMG. The repository also contains an optional `AppStore` build configuration for anyone who wants to ship a sandboxed build through the Mac App Store. It has not been submitted for review.

## What the `AppStore` configuration changes

| Setting | Value |
| --- | --- |
| Bundle ID | `com.wanto.revvy` — change it to your own in `project.yml` |
| App Sandbox | Enabled, with only `network.client` and `files.user-selected.read-write` (`Config/Revvy-AppStore.entitlements`) |
| Signing | Automatic (`Config/AppStore.xcconfig`); pass `TEAM_ID` on the command line |
| Compilation condition | `APP_STORE` — removes the developer option that runs the `gh` CLI |
| Privacy manifest | `IssueShot/Resources/PrivacyInfo.xcprivacy` (no tracking, no collected data, `UserDefaults` reason `CA92.1`) |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` (only system HTTPS) |

In the sandboxed build, history and settings live in the app container (`~/Library/Containers/<bundle id>/`), so they are not shared with a direct-download build. Screen Recording permission and the GitHub sign-in must be granted again.

## Commands

```bash
make appstore-check                        # sandboxed build with ad-hoc signing (no account needed)
make appstore TEAM_ID=YOUR_TEAM_ID         # archive and export an App Store .pkg (does not upload)
make appstore-upload TEAM_ID=YOUR_TEAM_ID  # archive, export and upload to App Store Connect
```

`make appstore` and `make appstore-upload` use automatic signing with `-allowProvisioningUpdates`, so the first run may register the bundle ID and create an Apple Distribution certificate in your developer account. Add an Apple ID with the Admin or App Manager role in **Xcode → Settings → Accounts** first.

## Checklist before submitting

- [ ] Change the bundle ID and GitHub OAuth App Client ID to your own
- [ ] Verify under the sandbox: region/full-screen capture and permission denial, global shortcuts, on-screen ruler, drag and drop (Finder, browsers, Photos), image import and PNG export, GitHub sign-in, issue creation and link sharing
- [ ] Publish a privacy policy URL (you can adapt [PRIVACY.md](../PRIVACY.md)) and a support URL
- [ ] Prepare screenshots (16:10, at least 1280×800) without personal information
- [ ] Provide App Review with a test GitHub account and repository for the GitHub features
- [ ] Declare App Privacy as appropriate (the app itself sends nothing to the developer)
- [ ] Increase `CURRENT_PROJECT_VERSION` in `project.yml` for every upload

References:
- [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

## 日本語

Revvy は署名・公証済みの DMG で配布しています。このリポジトリには、Mac App Store でサンドボックス版を出したい人向けの `AppStore` 構成も含まれていますが、審査には提出していません。

- `AppStore` 構成では App Sandbox を有効にし、許可はネットワーク（クライアント）とユーザーが選んだファイルの読み書きだけに絞っています。Bundle ID は `project.yml` で自分のものに変更してください。
- `APP_STORE` フラグで、`gh` CLI を実行する開発者向けの機能を外します。
- プライバシーマニフェスト（`PrivacyInfo.xcprivacy`）と輸出コンプライアンスの設定（`ITSAppUsesNonExemptEncryption = NO`）を含みます。
- サンドボックス版の履歴と設定はアプリのコンテナに保存され、直接配布版とは共有されません。

```bash
make appstore-check                        # アカウント不要。アドホック署名でサンドボックス版をビルド
make appstore TEAM_ID=YOUR_TEAM_ID         # App Store 用 .pkg を作る（送信しない）
make appstore-upload TEAM_ID=YOUR_TEAM_ID  # 作って App Store Connect に送信する
```

`make appstore` 系は自動署名のため、初回は開発者アカウントに Bundle ID の登録と Apple Distribution 証明書の作成が行われます。提出前には上のチェックリスト（サンドボックス下での動作確認、プライバシーポリシーとサポートの URL、スクリーンショット、審査用の GitHub テストアカウントなど）を確認してください。

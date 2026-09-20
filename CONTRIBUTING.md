# Contributing to Revvy

**English** · [日本語](#日本語) · [简体中文](#简体中文) · [한국어](#한국어)

Thanks for your interest in Revvy! Bug reports, ideas, translations and pull requests are all welcome.

## Reporting bugs and requesting features

- Search [existing issues](../../issues) first.
- Use the issue templates. For bugs, include your macOS version, Mac model, Revvy version (Revvy → About Revvy), steps to reproduce, and what you expected.
- **Do not attach screenshots that contain personal or confidential information.**
- Security problems: follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Development setup

1. Install macOS 15+, Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. `make run` to generate the project, build and launch. `make test` runs the test suite.
3. Optional: copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your team ID to sign with your own certificate (keeps Screen Recording permission stable between builds).

The Xcode project is generated from `project.yml`. Edit `project.yml`, not the `.xcodeproj`.

## Pull requests

1. Create a branch from `main`.
2. Keep changes focused; match the surrounding code style.
3. Add or update tests for logic changes (`IssueShotTests/`, Swift Testing).
4. Run `make test` and check the change in the running app — especially capture permissions, multi-display selection, drag and drop, zoom and saving.
5. If you add or change UI text, update all languages in `IssueShot/Resources/Localizable.xcstrings`. If you change behavior described in the README, update every `README.*.md`.
6. In the PR description, explain the problem, the new behavior and how you verified it.

Never commit certificates, tokens, personal screenshots, `Config/Local.xcconfig` or build output.

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE) and that you have the right to license it.

## Translations

Translations are welcome. Open `IssueShot/Resources/Localizable.xcstrings` in Xcode, add or fix translations, and add a matching `README.<language>.md` and `PRIVACY.<language>.md` if you can.

---

## 日本語

不具合の報告、アイデア、翻訳、Pull Request を歓迎します。

- 報告の前に [既存の Issue](../../issues) を検索し、テンプレートを使ってください。不具合には macOS のバージョン、Mac の機種、Revvy のバージョン、再現手順、期待する動作を書いてください。
- **個人情報や機密情報が写ったスクリーンショットは添付しないでください。**
- 脆弱性は公開の Issue ではなく [SECURITY.md](SECURITY.md) の手順で報告してください。
- 開発には macOS 15 以降、Xcode 26 以降、XcodeGen が必要です。`make run` でビルドして起動、`make test` でテストを実行します。プロジェクトは `project.yml` から生成されるので、`.xcodeproj` ではなく `project.yml` を編集してください。
- Pull Request では、変更を小さく保ち、ロジックの変更にはテストを追加し、実際のアプリで動作を確認してください（撮影の許可、マルチディスプレイでの範囲選択、ドラッグ＆ドロップ、ズーム、保存など）。
- UI の文言を追加・変更したら `Localizable.xcstrings` のすべての言語を、README に書かれた動作を変えたらすべての `README.*.md` を更新してください。
- 証明書、トークン、個人のスクリーンショット、`Config/Local.xcconfig`、ビルド成果物はコミットしないでください。
- 貢献したコードは [MIT License](LICENSE) で提供されます。提供する権利のあるものだけを送ってください。

## 简体中文

欢迎提交错误报告、想法、翻译和 Pull Request。

- 提交前请先搜索[现有 Issue](../../issues)，并使用模板。报告错误时请写明 macOS 版本、Mac 型号、Revvy 版本、重现步骤和预期行为。
- **请不要附加包含个人信息或机密信息的截图。**
- 安全问题请按照 [SECURITY.md](SECURITY.md) 报告，不要公开提交 Issue。
- 开发需要 macOS 15+、Xcode 26+ 和 XcodeGen。`make run` 构建并启动，`make test` 运行测试。请编辑 `project.yml`，而不是 `.xcodeproj`。
- 修改 UI 文字时，请更新 `Localizable.xcstrings` 中的所有语言；修改 README 中描述的行为时，请更新所有 `README.*.md`。
- 你的贡献将以 [MIT License](LICENSE) 授权。

## 한국어

버그 보고, 아이디어, 번역, Pull Request를 환영합니다.

- 먼저 [기존 Issue](../../issues)를 검색하고 템플릿을 사용해 주세요. 버그에는 macOS 버전, Mac 모델, Revvy 버전, 재현 단계, 기대한 동작을 적어 주세요.
- **개인정보나 기밀 정보가 담긴 스크린샷은 첨부하지 마세요.**
- 보안 문제는 공개 Issue 대신 [SECURITY.md](SECURITY.md)의 안내에 따라 보고해 주세요.
- 개발에는 macOS 15 이상, Xcode 26 이상, XcodeGen이 필요합니다. `make run`으로 빌드 및 실행, `make test`로 테스트를 실행합니다. `.xcodeproj`가 아닌 `project.yml`을 수정하세요.
- UI 문구를 바꾸면 `Localizable.xcstrings`의 모든 언어를, README에 설명된 동작을 바꾸면 모든 `README.*.md`를 업데이트해 주세요.
- 기여한 내용은 [MIT License](LICENSE)로 제공됩니다.

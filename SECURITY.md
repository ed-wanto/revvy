# Security Policy

**English** · [日本語](#日本語) · [简体中文](#简体中文) · [한국어](#한국어)

## Reporting a vulnerability

Please **do not** report security vulnerabilities in public issues, discussions or pull requests.

Use GitHub's private vulnerability reporting: open the repository's **Security** tab and choose **Report a vulnerability**. If that option is not available, open a public issue that only asks for a private contact method — without any details of the vulnerability.

Please include:

- A description of the issue and its impact
- Steps to reproduce, or a proof of concept
- The Revvy version and macOS version

Never include real access tokens, private screenshots or other personal data in a report. Use dummy data.

## Scope

Examples of issues we want to hear about:

- Leaks of the GitHub access token (Keychain handling, logs, issue text)
- Data sent anywhere other than the user-selected GitHub repository
- Unexpected screen capture, or capture of content the user did not select
- Bypasses of the text masking that exposes secrets in created issues

## Supported versions

Revvy is in early development. Security fixes are made on the latest release and the `main` branch only. There is no formal response-time commitment yet, but we will acknowledge reports as soon as we can.

---

## 日本語

脆弱性は公開の Issue、Discussion、Pull Request に**投稿しないでください**。リポジトリの **Security** タブの **Report a vulnerability**（非公開の報告）を使ってください。使えない場合は、脆弱性の内容を書かずに、非公開の連絡方法を尋ねる Issue だけを立ててください。報告には内容と影響、再現手順、Revvy と macOS のバージョンを含め、本物のトークンや個人のスクリーンショットは含めないでください。修正は最新リリースと `main` ブランチにのみ行います。

## 简体中文

请**不要**在公开的 Issue、Discussion 或 Pull Request 中报告安全漏洞。请使用仓库 **Security** 标签页中的 **Report a vulnerability**（私密报告）。如该选项不可用，请仅提交一个询问私密联系方式的 Issue，不要包含漏洞细节。报告中请勿包含真实令牌或私人截图。安全修复仅针对最新版本和 `main` 分支。

## 한국어

보안 취약점은 공개 Issue, Discussion, Pull Request에 **올리지 마세요**. 저장소의 **Security** 탭에서 **Report a vulnerability**(비공개 보고)를 사용해 주세요. 이 옵션을 사용할 수 없다면 취약점 내용 없이 비공개 연락 방법만 묻는 Issue를 열어 주세요. 보고서에 실제 토큰이나 개인 스크린샷을 포함하지 마세요. 보안 수정은 최신 릴리스와 `main` 브랜치에만 적용됩니다.

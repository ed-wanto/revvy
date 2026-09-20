# Privacy

**English** · [日本語](PRIVACY.ja.md) · [简体中文](PRIVACY.zh-Hans.md) · [한국어](PRIVACY.ko.md)

This document describes how Revvy handles your data in the current source code.

## Summary

- Revvy does **not** send any data to its developers. It has no analytics, advertising or crash-reporting SDKs.
- Everything you capture stays on your Mac unless you use a GitHub feature.
- GitHub features send data only to the GitHub repository you choose.

## Data stored on your Mac

| Data | Where |
| --- | --- |
| Captured images, annotations, notes, recognized text | `~/Library/Application Support/Revvy/Captures` (inside the app container for sandboxed builds) |
| Settings (shortcuts, ruler unit, panel state, selected repository, etc.) | The app's preferences (`UserDefaults`) |
| GitHub access token | macOS Keychain |

Text recognition (OCR) runs on your Mac with Apple Vision. Images are not uploaded for recognition.

Deleting a capture from the history removes it from your Mac only.

## Screen Recording permission

Revvy asks for Screen Recording permission so it can take screenshots. It captures the screen only when you start a capture (shortcut, floating panel, menu or button). The on-screen ruler does not capture the screen.

## Data sent to GitHub

Revvy talks to GitHub (`github.com`, `api.github.com`) only in these cases:

| When | What is sent |
| --- | --- |
| Connecting GitHub | The device-flow request with the app's public Client ID. You approve access in your browser. |
| Loading repositories, labels, assignees | Requests authenticated with your token. |
| **Create and Copy Link** / **Create Issue** | The annotated image is committed to a branch (default `feedback-assets`) of the repository you selected. For issues, the title, comment, labels, assignees and environment details (app version, macOS version, Mac model, display size, capture time, your GitHub username) are sent as well. |

- Images sent to a **public** repository are public. In a **private** repository, GitHub's access permissions apply.
- Revvy masks some sensitive text (tokens, JWTs, `Authorization`/`Cookie` headers, email addresses) in issue text, but it **does not** remove sensitive information from images. Check the image and text before sharing.
- Deleting local history does not delete images, commits or issues on GitHub. Manage that data on GitHub.
- You can revoke Revvy's access at any time in GitHub under **Settings → Applications → Authorized OAuth Apps**, and sign out in Revvy from the account menu in the sidebar.

GitHub's handling of that data is governed by the [GitHub General Privacy Statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement).

## Developer option (direct builds only)

Builds distributed outside the Mac App Store include a developer option that, when you explicitly choose it, reads the token of a logged-in `gh` CLI. Sandboxed builds do not include this option.

## Changes

Changes to this document are tracked in the Git history of this repository.

## Contact

Questions about privacy: open an issue in this repository. For anything sensitive, follow [SECURITY.md](SECURITY.md) instead.

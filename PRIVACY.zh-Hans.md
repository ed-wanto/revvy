# 隐私

[English](PRIVACY.md) · [日本語](PRIVACY.ja.md) · **简体中文** · [한국어](PRIVACY.ko.md)

本文说明当前源代码中 Revvy 如何处理你的数据。如与英文版有出入，以[英文版](PRIVACY.md)为准。

## 概要

- Revvy **不会**向开发者发送任何数据，也不包含分析、广告或崩溃收集 SDK。
- 除非使用 GitHub 功能，你截取的内容只保存在你的 Mac 上。
- 使用 GitHub 功能时，数据只会发送到你选择的 GitHub 仓库。

## 保存在 Mac 上的数据

| 数据 | 位置 |
| --- | --- |
| 截图、标注、备注、识别出的文字 | `~/Library/Application Support/Revvy/Captures`（沙盒版本位于 App 容器内） |
| 设置（快捷键、标尺单位、面板状态、所选仓库等） | App 的偏好设置（`UserDefaults`） |
| GitHub 访问令牌 | macOS 钥匙串 |

文字识别（OCR）使用 Apple Vision 在 Mac 本地进行，不会为识别而上传图像。

从历史记录中删除截图只会将其从你的 Mac 上删除。

## 屏幕录制权限

Revvy 需要屏幕录制权限来截取屏幕。只有在你开始截屏时（快捷键、浮动面板、菜单或按钮）才会截取屏幕。屏幕标尺不会截取屏幕。

## 发送到 GitHub 的数据

Revvy 仅在以下情况下与 GitHub（`github.com`、`api.github.com`）通信：

| 时机 | 发送的内容 |
| --- | --- |
| 连接 GitHub | 使用 App 公开 Client ID 的设备流请求。你在浏览器中批准访问。 |
| 加载仓库、标签、负责人 | 使用你的令牌进行身份验证的请求。 |
| **创建并拷贝链接**／**创建 Issue** | 标注后的图像会提交到所选仓库的分支（默认 `feedback-assets`）。创建 Issue 时还会发送标题、评论、标签、负责人以及环境信息（App 版本、macOS 版本、Mac 型号、显示器尺寸、截图时间、你的 GitHub 用户名）。 |

- 发送到**公开**仓库的图像是公开的；在**私有**仓库中，遵循 GitHub 的访问权限。
- Revvy 会在 Issue 文本中遮盖部分敏感内容（令牌、JWT、`Authorization`／`Cookie` 请求头、电子邮件地址），但**不会**移除图像中的敏感信息。分享前请检查图像和文字。
- 删除本地历史记录不会删除 GitHub 上的图像、提交或 Issue，请在 GitHub 上管理这些数据。
- 你可以随时在 GitHub 的 **Settings → Applications → Authorized OAuth Apps** 中撤销 Revvy 的访问权限，并在 Revvy 侧边栏的账户菜单中退出登录。

GitHub 对这些数据的处理适用 [GitHub General Privacy Statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)。

## 开发者选项（仅限直接分发版本）

在 Mac App Store 之外分发的版本包含一个开发者选项：仅当你明确选择时，才会读取已登录的 `gh` CLI 的令牌。沙盒版本不包含此选项。

## 变更

本文的变更记录可在本仓库的 Git 历史中查看。

## 联系方式

隐私相关问题请在本仓库提交 Issue。涉及敏感内容时，请按照 [SECURITY.md](SECURITY.md) 的说明处理。

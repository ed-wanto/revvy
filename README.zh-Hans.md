<p align="center">
  <img src="IssueShot/Assets.xcassets/AppIcon.appiconset/icon-256.png" width="128" height="128" alt="Revvy 应用图标">
</p>

<h1 align="center">Revvy</h1>

<p align="center">
  在 Mac 上截屏、标注、测量并分享——然后直接变成 GitHub Issue。
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a> ·
  <b>简体中文</b> ·
  <a href="README.ko.md">한국어</a>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green"></a>
  <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-blue">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-orange">
</p>

---

Revvy 是一款原生 macOS 应用，用来“展示”而不只是“描述”需要修改的地方。在任何 App 中截屏，用矩形、箭头、文本和像素级标尺进行标注，再以 GitHub Issue 或链接的形式分享。截屏、标注、拷贝和存储无需任何账户。

> **状态：** 早期开发阶段（0.x）。可能存在不完善之处和不兼容的变更。

本文由[英文版 README](README.md) 翻译而来，如有出入以英文版为准。

## 目录

- [功能](#功能)
- [系统要求](#系统要求)
- [安装](#安装)
- [使用方法](#使用方法)
- [键盘快捷键](#键盘快捷键)
- [设置](#设置)
- [隐私](#隐私)
- [从源代码构建](#从源代码构建)
- [分发派生版本](#分发派生版本)
- [本地化](#本地化)
- [项目结构](#项目结构)
- [已知限制](#已知限制)
- [参与贡献](#参与贡献) · [安全](#安全) · [许可证](#许可证)

## 功能

**随处截屏**
- 使用 ScreenCaptureKit 截取区域或全屏
- 在任何 App 中都有效的全局快捷键（默认区域 <kbd>⌃⇧4</kbd>、全屏 <kbd>⌃⇧3</kbd>），可在设置中更改
- 始终浮在所有 App 之上的小型截屏面板，可收起为一个按钮，还可更改大小（4 档）和颜色
- 启动时只显示截屏面板，截屏后才会打开编辑窗口
- 通过菜单栏菜单截屏、使用标尺和打开设置
- 支持多显示器：选区遮罩显示在所有显示器上，在哪个显示器上拖移就截取哪个
- 支持拖放（访达、浏览器、照片、macOS 截屏缩略图）、剪贴板和文件导入

**标注**
- 矩形、箭头、笔、文本工具，共 4 种颜色
- 选择、移动和调整形状大小；绘制时也可以直接抓取附近的形状（按住 <kbd>⌥</kbd> 则叠加绘制）
- 用方向键微调 1 px（按住 <kbd>⇧</kbd> 为 10 px），支持复制、删除、撤销和重做
- 基于原始图像像素的距离标尺（px、em 或两者）
- 不会导出的坐标标尺和中心参考线
- 10%–400% 缩放、双指缩放、抓手工具平移（100% 表示图像的 1 像素对应屏幕的 1 点）

**屏幕标尺**
- 无需截屏，即可在任何 App 之上测量尺寸
- 拖移以移动，拖移边缘以调整大小，方向键移动，<kbd>⌥</kbd>＋方向键调整大小
- 每 10 px 一个刻度、中心参考线、复制、可同时显示多个标尺
- 贯穿整个显示器的垂直和水平参考线，显示位置以及与最近平行线的间距
- 一个按钮即可清除所有标尺和参考线
- 标尺和参考线会包含在截图中，可以直接分享测量结果

**保存与查找**
- 侧边栏中的截屏历史记录和备注
- 本地文字识别（Apple Vision），可按图像中的文字搜索截屏
- 拷贝识别出的文字、拷贝标注后的图像或存储为 PNG

**分享到 GitHub**
- 通过 GitHub 设备流登录（不需要 Client Secret，令牌保存在钥匙串中）
- 创建附带标注截图、标签和负责人的 Issue；自动附加环境信息（App 版本、macOS、机型、显示器）
- 一键上传标注后的图像并拷贝链接
- Issue 文本中的令牌、JWT、`Authorization`／`Cookie` 请求头和电子邮件地址会被自动遮盖

## 系统要求

- macOS 15 Sequoia 或更高版本
- 屏幕录制权限（首次截屏时请求）
- 仅在使用 GitHub 功能时需要 GitHub 账户

## 安装

### 下载

已签名并经过公证的版本将发布在 [Releases](../../releases) 页面。下载 `.dmg`，将 **Revvy** 拖到“应用程序”文件夹并打开。

### 自行构建

请参阅[从源代码构建](#从源代码构建)。

### 首次启动

1. 打开 Revvy。截屏面板会出现在屏幕右上角附近。启动时只显示此面板（和菜单栏图标），截屏后才会打开编辑窗口。
2. 进行第一次截屏。macOS 会请求**屏幕录制**权限，请在**系统设置 → 隐私与安全性 → 录屏与系统录音**中允许 Revvy。
3. 如果仍无法截屏，请退出并重新打开 Revvy（macOS 有时需要重启 App 才会应用权限）。

## 使用方法

### 截屏

| 操作 | 结果 |
| --- | --- |
| <kbd>⌃⇧4</kbd>（全局）或截屏面板中的区域按钮 | 拖移以选择区域。遮罩覆盖所有显示器，按 <kbd>Esc</kbd> 取消 |
| <kbd>⌃⇧3</kbd>（全局）或显示器按钮 | 截取指针所在的整个显示器 |
| <kbd>⌘⇧V</kbd>，或工具栏中的**截屏 ▾ → 从剪贴板粘贴** | 使用剪贴板中的图像 |
| 拖放 | 将图像拖到 Revvy 窗口或截屏面板上 |
| 工具栏中的**截屏 ▾ → 打开图像文件…** | 打开图像文件 |

截屏（或粘贴、拖放图像）后会打开编辑窗口。也可以通过截屏面板的**打开 Revvy**按钮、菜单栏菜单或程序坞图标打开。

Revvy 的窗口和截屏面板不会出现在截图中。屏幕标尺和参考线会被截取，以便保留测量结果（仅在鼠标悬停时显示的按钮不会被截取）。截屏完成后，所有标尺和参考线都会从屏幕上移除；按 <kbd>Esc</kbd> 取消截屏时会保留。

点按截屏面板右端的 **»** 会将其收起为一个按钮，点按 **«** 即可展开。右键点按面板可以更改大小（小、中、大、特大）和颜色，也可以在设置中更改。要完全隐藏面板，请使用菜单栏菜单、设置或快捷键。隐藏面板期间，启动时会打开编辑窗口。

### 标注

从画布底部的工具栏中选择工具：

- **选择与移动** — 点按形状以选择，拖移以移动；拖移端点以调整箭头和标尺
- **标尺（测量距离）** — 拖移以测量。按住 <kbd>⇧</kbd> 可保持水平或垂直
- **矩形**、**箭头**、**笔** — 拖移以绘制。在已有形状附近拖移会移动它，按住 <kbd>⌥</kbd> 则叠加绘制
- **文本** — 点按以放置文字，输入后按 <kbd>↩</kbd> 确认（<kbd>⌥↩</kbd> 换行）。使用文本工具点按已放置的文字，或用其他工具连按两次即可编辑
- **抓手** — 放大时拖移以平移

使用工具栏中的分享菜单可以**拷贝图像**或**存储为 PNG…**。拷贝、存储和分享的都是标注后的图像。参考线、坐标标尺和选择控点不会被导出。

### 屏幕标尺

点按截屏面板中的标尺按钮、在菜单栏菜单中选择**添加屏幕标尺**，或按 <kbd>⌃⌘R</kbd>，指针处会出现一个 320 × 200 的标尺。

- 在内部拖移以移动；拖移边缘或角落以调整大小
- 方向键移动 1 px（<kbd>⇧</kbd> 为 10 px）；<kbd>⌥</kbd>＋方向键调整大小
- <kbd>⌘D</kbd> 复制，<kbd>⌘;</kbd> 切换中心参考线，<kbd>Esc</kbd> 或 <kbd>⌘W</kbd> 关闭
- 鼠标悬停时显示参考线、复制和关闭按钮；右键点按也可执行相同操作
- <kbd>⌃⌘T</kbd> 隐藏或显示所有标尺和参考线

**参考线** — 点按截屏面板中的垂直或水平参考线按钮（也可以使用菜单栏菜单或标尺的右键菜单），即可在指针处画出贯穿整个显示器的线。拖移或使用方向键（<kbd>⇧</kbd> 为 10 px）移动。标签显示与显示器左边缘或上边缘的距离，如有其他平行线还会显示间距。<kbd>⌘D</kbd> 复制，<kbd>Esc</kbd> 或 <kbd>⌫</kbd> 删除。可以在设置中分配全局快捷键。

**全部清除** — 点按截屏面板中的橡皮擦按钮，或在菜单栏菜单、标尺或参考线的右键菜单中选择**清除所有标尺和参考线**，即可一次移除所有标尺和参考线。可以在设置中分配全局快捷键。

尺寸以点为单位，与 CSS 像素一致。单位（px／em）遵循标尺设置。

### 分享到 GitHub

1. 点按**连接 GitHub**，在浏览器中批准代码（设备流）。
2. 在检查器中选择仓库。
3. **创建并拷贝链接**会上传标注后的图像并拷贝其 URL。
4. **创建 Issue** 会创建包含标题（留空时使用正文第一行）、评论、截图、标签、负责人和环境信息的 Issue。

图像不会嵌入 Issue 正文，而是提交到专用分支（默认 `feedback-assets`）的 `screenshots/` 下。在公开仓库中图像是公开的；在私有仓库中只有有权限的人才能查看。删除本地历史记录不会删除 GitHub 上的任何内容。

组织仓库可能需要组织批准 OAuth App。

## 键盘快捷键

| 快捷键 | 操作 | 作用范围 |
| --- | --- | --- |
| <kbd>⌃⇧4</kbd> | 截取区域 | 全局（可自定义） |
| <kbd>⌃⇧3</kbd> | 截取全屏 | 全局（可自定义） |
| <kbd>⌃⌘R</kbd> | 添加屏幕标尺 | 全局（可自定义） |
| <kbd>⌃⌘T</kbd> | 显示／隐藏标尺 | 全局（可自定义） |
| — | 显示／隐藏浮动面板 | 全局（在设置中分配） |
| — | 添加垂直／水平参考线 | 全局（在设置中分配） |
| — | 清除所有标尺和参考线 | 全局（在设置中分配） |
| <kbd>⌘⇧V</kbd> | 使用剪贴板图像 | App 内 |
| <kbd>⌘Z</kbd> / <kbd>⇧⌘Z</kbd> | 撤销／重做（输入时针对文字，否则针对标注） | App 内 |
| <kbd>⌘D</kbd> | 复制所选标注或标尺 | App 内／标尺 |
| <kbd>⌫</kbd> | 删除所选标注 | 画布 |
| 方向键 | 移动 1 px（<kbd>⇧</kbd> 为 10 px） | 画布／标尺 |
| <kbd>⌘+</kbd> <kbd>⌘-</kbd> <kbd>⌘1</kbd> <kbd>⌘0</kbd> | 放大、缩小、实际大小、缩放以适合 | 画布 |
| <kbd>⌘;</kbd> | 中心参考线 | 画布／标尺 |
| <kbd>⌘↩</kbd> | 创建 Issue | 检查器 |

<kbd>⌘⇧3</kbd>、<kbd>⌘⇧4</kbd>、<kbd>⌘⇧5</kbd> 由 macOS 自带截屏功能使用，因此不能设为全局快捷键。

## 设置

通过 **Revvy → 设置…**（<kbd>⌘,</kbd>）或菜单栏菜单中的**设置…**打开。

- **浮动面板** — 显示或隐藏截屏面板，以及面板的大小（小、中、大、特大）和颜色
- **快捷键** — 录制全局快捷键（点按后按下按键；<kbd>Esc</kbd> 取消，<kbd>⌫</kbd> 清除）、恢复默认。如果其他 App 已占用某个组合键，Revvy 会发出警告
- **标尺** — 显示单位（px、em 或两者）以及计算 em 所用的根 `font-size`
- **Issue** — 自动添加的标签（默认 `app-feedback`）和存放截图的分支（默认 `feedback-assets`）
- **GitHub 连接** — 供派生版本覆盖 OAuth App 的 Client ID

## 隐私

- 截图、标注、备注和识别出的文字只保存在你的 Mac 上（`~/Library/Application Support/Revvy/Captures`）
- 文字识别使用 Apple Vision 在本地进行
- GitHub 令牌保存在 macOS 钥匙串中
- 不包含分析、广告或崩溃报告 SDK，不会向开发者发送任何数据
- 只有在使用 GitHub 功能时，数据才会离开你的 Mac，并且只发送到你选择的仓库

详情请参阅 [PRIVACY.zh-Hans.md](PRIVACY.zh-Hans.md)。

## 从源代码构建

需要：macOS 15+、Xcode 26+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
git clone https://github.com/<owner>/revvy.git
cd revvy
make run    # 生成 Xcode 项目、构建并启动
```

其他命令：

```bash
make open   # 生成项目并在 Xcode 中打开
make build  # 在 build/ 中进行 Debug 构建
make test   # 运行 Swift Testing 测试
make clean  # 删除构建产物和生成的项目
```

Xcode 项目由 `project.yml` 生成，不会提交到仓库。

### 代码签名

默认使用临时（ad-hoc）签名，因此不需要 Apple Developer 账户。由于临时签名每次构建都会变化，macOS 可能会再次请求屏幕录制权限或钥匙串访问。日常开发时建议使用自己的证书签名：

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
# 将 DEVELOPMENT_TEAM 设置为你的团队 ID
make build
```

`Config/Local.xcconfig` 已被 Git 忽略。

## 分发派生版本

1. **Bundle ID** — 修改 `project.yml` 中的 `PRODUCT_BUNDLE_IDENTIFIER`（由于历史原因，内部模块名仍为 `IssueShot`）。
2. **GitHub OAuth App** — 在 <https://github.com/settings/applications/new> 创建你自己的 OAuth App，启用 **Device Flow**，并将 Client ID 写入 `IssueShot/OAuthConfig.swift`。设备流不使用 Client Secret，因此 Client ID 可以公开。
3. **Developer ID 构建** — 准备 Developer ID Application 证书和公证凭据后：

   ```bash
   make notary-setup TEAM_ID=YOUR_TEAM_ID APPLE_ID=you@example.com
   make dist TEAM_ID=YOUR_TEAM_ID              # 签名、公证、装订 → dist/Revvy-<version>.dmg
   TEAM_ID=YOUR_TEAM_ID ./scripts/dist.sh --no-notarize   # 仅签名和打包
   ```

   DMG 带有定制的安装窗口（背景图和图标布局），需要 `pip3 install --user dmgbuild pillow`；若未安装则会生成普通磁盘映像。更换 App 图标后，请运行 `python3 scripts/make-dmg-background.py` 重新生成背景。

4. **Mac App Store（可选）** — 仓库包含启用 App Sandbox 的 `AppStore` 构建配置、隐私清单和导出脚本。请参阅 [docs/APP_STORE.md](docs/APP_STORE.md)。

## 本地化

App 和文档支持以下语言：

| 语言 | App | README |
| --- | --- | --- |
| 日语（开发语言） | ✅ | [README.ja.md](README.ja.md) |
| 英语 | ✅ | [README.md](README.md) |
| 简体中文 | ✅ | [README.zh-Hans.md](README.zh-Hans.md) |
| 韩语 | ✅ | [README.ko.md](README.ko.md) |

界面文字位于 String Catalog `IssueShot/Resources/Localizable.xcstrings` 中。要添加或改进某种语言，请在 Xcode 中打开该目录，添加翻译并提交 Pull Request。Revvy 遵循**系统设置 → 通用 → 语言与地区**中的语言顺序，你也可以在那里为单个 App 设置语言。

## 项目结构

```
IssueShot/
  IssueShotApp.swift        App 入口、菜单、菜单栏
  AppModel.swift            截屏、标注、历史记录和 GitHub 状态
  CaptureControls.swift     全局快捷键、浮动面板、截屏入口
  Models/                   标注、几何计算、视图缩放、GitHub 模型
  Services/                 截屏、图像拖放、热键、GitHub 客户端／认证、历史记录与文字识别、遮盖
  Views/                    SwiftUI／AppKit 视图（编辑器、侧边栏、检查器、面板、屏幕标尺、设置）
  Resources/                String Catalog、隐私清单、图标
IssueShotTests/             Swift Testing 测试
Config/                     签名与构建配置
scripts/                    分发脚本
docs/                       其他文档
```

## 已知限制

- 不支持录制视频或 GIF
- 分享使用 GitHub 仓库中的分支，没有独立的图像托管服务，因此没有仓库访问权限的人无法打开私有仓库的链接
- 更改屏幕录制权限后可能需要重新启动 App
- 官方版本内置的 GitHub OAuth App 的注册名称仍为“IssueShot”

## 参与贡献

欢迎提交错误报告、想法和 Pull Request，请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 安全

请不要在公开 Issue 中报告漏洞，请参阅 [SECURITY.md](SECURITY.md)。

## 许可证

[MIT](LICENSE) © Revvy contributors

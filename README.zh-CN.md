<p align="center">
  <img src="Clipbara/Resources/Assets.xcassets/AppIcon.appiconset/256.png" width="128" height="128" alt="Clipbara 图标">
</p>

<h1 align="center">Clipbara</h1>

<p align="center">
  <strong>免费开源的 macOS 原生剪贴板管理器</strong>
  <br>
  卡片式界面类似付费应用 Paste，数据完全本地存储。
</p>

<p align="center">
  <a href="README.md">English</a> | 简体中文
</p>

> **Clipbara 原名 PasteClip**，因 Mac App Store 上已有同名应用，于 2026 年 8 月改名。v1.1.11 及更早版本仍使用 PasteClip 名称，旧链接会自动跳转。

<p align="center">
  <a href="https://github.com/mobrava/Clipbara/releases/latest"><img src="https://img.shields.io/github/v/release/mobrava/Clipbara?style=flat-square" alt="最新版本"></a>
  <a href="https://github.com/mobrava/Clipbara/releases"><img src="https://img.shields.io/github/downloads/mobrava/Clipbara/total?style=flat-square" alt="下载量"></a>
  <a href="https://github.com/mobrava/Clipbara/stargazers"><img src="https://img.shields.io/github/stars/mobrava/Clipbara?style=flat-square" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/mobrava/Clipbara?style=flat-square" alt="许可证"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square" alt="macOS 14+">
  <a href="https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&amp;ct=github_readme_zh&amp;mt=8"><img src="https://img.shields.io/badge/Mac%20App%20Store-7--day%20free%20trial-0D96F6?style=flat-square&logo=apple&logoColor=white" alt="Mac App Store 上的 Clipbara"></a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&amp;ct=github_readme_zh&amp;mt=8"><strong>从 Mac App Store 下载</strong></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/mobrava/Clipbara/releases/latest"><strong>下载 DMG</strong></a>
</p>

<p align="center">
  <img src="docs/assets/pasteclip-demo.gif" width="800" alt="Clipbara 演示：按 ⌘⇧V 打开面板，单击卡片即复制，随后 ⌘V 粘贴">
</p>

## 简介

Clipbara 是一款免费开源（GPL-3.0）的 macOS 剪贴板管理器，用原生 Swift 6 + SwiftUI 编写，卡片式界面类似付费应用 Paste。数据完全本地存储，无账号、无服务器、无遥测。

## 主要功能

- **卡片式剪贴板历史**：支持文本、富文本、HTML、图片、链接、文件、颜色和代码片段
- **不打断工作流**：`⌘⇧V` 唤出非激活面板，当前应用保持焦点；单击卡片即复制到剪贴板并自动收起面板，回到当前应用直接 `⌘V` 粘贴。也可以在 **设置 → 通用** 中开启「直接粘贴到当前应用」，省去 `⌘V`（需要辅助功能权限）
- **剪贴队列**：连续复制多项内容，再按 `⌘V` 依次粘贴（需要辅助功能权限）
- **Pinboards 收藏夹**：把常用内容整理成命名收藏夹，卡片和标签都支持拖拽排序，卡片可在收藏夹之间移动
- **快速预览与编辑**：按 `空格` 进行 Quick Look 预览，按 `⌘E` 直接编辑纯文本内容；`Delete` 删除后可用 `⌘Z` 撤销
- **快捷链接**：可在 Raycast、Alfred、快捷指令等工具中通过 `clipbara://open`、`clipbara://toggle`、`clipbara://queue` 调用
- **界面语言**：英文、韩文、简体中文
- **隐私控制**：可排除指定应用（如密码管理器），历史上限可配置、自动清理
- **对终端友好**：图片以 PNG + file URL 方式写入剪贴板，可以可靠地粘贴到 Ghostty / iTerm2（详见下方[终端中的图片剪贴](#终端中的图片剪贴)）
- **完全本地**：基于 SwiftData 本地存储，DMG 版唯一的网络请求是 Sparkle 检查更新，App Store 版本不包含更新组件

## 截图

<p align="center">
  <img src="docs/assets/screenshot-history-panel.png" width="900" alt="Clipbara 历史面板">
</p>

## 安装

要求 **macOS 14 Sonoma 或更高版本**。DMG 和 Homebrew 版本免费；Mac App Store 版本可免费试用 7 天，之后一次性买断。在 1.4 版之前购买或在限免期间下载的用户无需再次付费。

### Mac App Store

[**从 Mac App Store 下载 Clipbara**](https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&ct=github_readme_zh&mt=8)

App Store 版开启了 App Sandbox，由 App Store 推送更新；免费的 DMG 版使用 Sparkle 自动更新。两个版本在同一天发布新版本。两个版本的 bundle ID 不同，历史记录分开存储；迁移时在旧版本中使用 **Settings → General → Backup → Export** 导出 JSON，再在新版本中 Import。两个版本同时运行会重复注册 `⌘⇧V`，请只保留一个。

### Homebrew

```bash
brew install --cask mobrava/tap/clipbara
```

### 手动下载

从 [GitHub Releases](https://github.com/mobrava/Clipbara/releases/latest) 下载最新 `.dmg`，拖入「应用程序」文件夹。

DMG 已使用 Apple Developer ID 签名并通过 Apple 公证（自 v1.1.11 起），首次启动不会出现安全提示。

## 终端中的图片剪贴

选择图片剪贴项会把图片重新放回 macOS 剪贴板，但 shell 提示符本身无法接收图片数据。必须由终端中运行的应用或 CLI 支持剪贴板图片输入。

以 macOS 上的 Codex CLI 为例：

1. 按 `⌘ ⇧ V` 并选择需要复用的图片剪贴项。
2. 回到 Codex，中途不要再复制其他内容。
3. 在 Codex 中按 `Control + V` 附加剪贴板图片。

Codex 使用 `Control + V` 附加图片，而不是 macOS 常用的 `⌘ V` 文本粘贴快捷键。其他终端应用可能有不同的图片粘贴方式。

## 更多内容

键盘快捷键、隐私说明、从源码构建、参与贡献等完整文档请参阅 [英文 README](README.md)。

## 许可证

[GNU General Public License v3.0](LICENSE)

<p align="center">
  <img src="Clipbara/Resources/Assets.xcassets/AppIcon.appiconset/256.png" width="128" height="128" alt="Clipbara icon">
</p>

<h1 align="center">Clipbara</h1>

<p align="center">
  A clipboard manager for macOS, with a companion app for iPhone.
</p>

<p align="center">
  English | <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&amp;ct=github_readme&amp;mt=8"><img src="https://img.shields.io/badge/Mac%20App%20Store-7--day%20free%20trial-0D96F6?style=flat-square&logo=apple&logoColor=white" alt="Clipbara on the Mac App Store"></a>
  <a href="https://github.com/mobrava/Clipbara/releases/latest"><img src="https://img.shields.io/github/v/release/mobrava/Clipbara?style=flat-square" alt="Latest release"></a>
  <a href="https://github.com/mobrava/Clipbara/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/mobrava/Clipbara/build.yml?branch=main&style=flat-square" alt="Build status"></a>
  <a href="https://github.com/mobrava/Clipbara/releases"><img src="https://img.shields.io/github/downloads/mobrava/Clipbara/total?style=flat-square" alt="Total downloads"></a>
  <a href="https://github.com/mobrava/Clipbara/stargazers"><img src="https://img.shields.io/github/stars/mobrava/Clipbara?style=flat-square" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/mobrava/Clipbara?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/iOS-26%2B-blue?style=flat-square" alt="iOS 26 or later">
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&amp;ct=github_readme&amp;mt=8"><strong>Get it on the Mac App Store</strong></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/mobrava/Clipbara/releases/latest"><strong>Download the DMG</strong></a>
</p>

https://github.com/user-attachments/assets/60db2f4c-fbe4-41d0-9bda-416b791c5c46

Clipbara keeps a history of what you copy. Press `⌘ ⇧ V` and a panel slides up at the bottom of the screen without pulling focus from the app you are in. Click a clip once and it is back on your clipboard.

It runs on macOS 14 Sonoma or later. The DMG and Homebrew builds are free. The Mac App Store build is free to try for 7 days, then a one-time purchase that also unlocks [Clipbara for iPhone](#iphone). With iCloud sync turned on, your history and Pinboards follow you to the iPhone.

## Install

### Mac App Store

[**Download Clipbara on the Mac App Store**](https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&ct=github_readme&mt=8)

### Homebrew

```bash
brew install --cask mobrava/tap/clipbara
```

### Direct download

Download the latest `.dmg` from [Releases](https://github.com/mobrava/Clipbara/releases/latest), open it, and drag the app into Applications. The DMG is signed with an Apple Developer ID and notarized by Apple as of v1.1.11, so it opens without a security warning.

<details>
<summary><strong>App Store build or DMG build?</strong></summary>

Both are built from this repository. The App Store build is free to try for 7 days and then a one-time purchase, is sandboxed, and updates through the App Store. If you bought it before version 1.5 or got it during the free week, it stays unlocked. The DMG build is free and updates itself through Sparkle. Both get each release on the same day.

The two differ in a few features:

- iCloud sync, and with it the iPhone app, is in the App Store build only.
- Pasting into the active app and Clip Queue are in the DMG build only. Both need Accessibility permission, which Apple does not allow App Store apps to use for this.

The two use different bundle identifiers, so they keep separate histories. To carry your clips across, open **Settings > General > Backup > Export** in one build and **Import** in the other. Existing clips are kept and duplicates are skipped.

Run only one of them. Two copies register `⌘ ⇧ V` twice and open two panels.

</details>

## Usage

1. Copy anything with <kbd>⌘</kbd> <kbd>C</kbd> as usual.
2. Press <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>V</kbd> to open the history panel.
3. Type to search, or move between clips with <kbd>←</kbd> and <kbd>→</kbd>.
4. Click a clip once, or press <kbd>Return</kbd>. The clip goes to your clipboard and the panel closes.
5. Press <kbd>⌘</kbd> <kbd>V</kbd> in the app you were using.

In the DMG build you can skip step 5: turn on **Settings > General > Paste into the Active App**. See the [FAQ](#why-doesnt-clipbara-paste-into-the-app-for-me) for the permission it needs.

Inside the panel:

- <kbd>Space</kbd> opens and closes Quick Look for the clip under the pointer, or the selected one
- <kbd>⌘</kbd> <kbd>E</kbd> edits the text of a text clip
- <kbd>Delete</kbd> removes the selected clip (on a Pinboard tab, from that Pinboard only), and <kbd>⌘</kbd> <kbd>Z</kbd> brings it back
- <kbd>⌘</kbd> <kbd>1</kbd> to <kbd>⌘</kbd> <kbd>9</kbd> switch between History and Pinboards. Hold <kbd>⌘</kbd> to see the numbers
- <kbd>⌘</kbd> <kbd>,</kbd> opens Settings
- <kbd>Esc</kbd> clears the search, steps back, or closes the panel
- <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>⌫</kbd> clears unpinned history
- Holding <kbd>⇧</kbd> while pasting flips plain-text pasting for that one paste
- Right-clicking a clip lets you rename it, edit its text, add it to or move it between Pinboards, or delete it
- Dragging a Pinboard tab reorders it

Both global shortcuts and the Quick Look key can be changed in **Settings > Shortcuts**.

## iPhone

[Clipbara for iPhone](https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&ct=github_readme&mt=8) is the same App Store purchase as the Mac app. It needs iOS 26 or later.

- **Sync.** Turn on **iCloud Sync** in Settings on both: under **General** on the Mac, and in the **Sync** section on the iPhone. Clips, titles, and Pinboards sync both ways through your own iCloud. Pull the list down to sync right away.
- **Keyboard.** Add the Clipbara keyboard in **Settings > Apps > Clipbara > Keyboards**, then switch to it with the globe key and tap a clip to insert it in any app. It has no letter keys. It works without Full Access, which it uses only to fetch the newest clips from iCloud while the app is closed.
- **Saving on the iPhone.** iOS does not let apps read the clipboard in the background, so the iPhone saves a clip when you tap the Paste button in Clipbara, or when you share something to Clipbara from another app.

## Features

- Text, rich text, HTML, images, links, files, and colors
- Optional iCloud sync with Clipbara for iPhone (App Store build)
- Search by content or title, with filters for type and date
- Pinboards for the clips you keep reusing, with clips movable between them
- Quick Look preview without leaving the panel, and text editing inside it
- Paste as plain text, always or per paste
- Optional pasting into the active app (DMG build)
- Clip Queue: copy several things, then paste them back in order with <kbd>⌘</kbd> <kbd>V</kbd> (DMG build)
- `clipbara://open` and `clipbara://toggle` links (and `clipbara://queue` in the DMG build) for launchers such as Raycast, Alfred, or Shortcuts
- A hideable menu bar icon, and a panel that can open without animation
- English, Korean, and Simplified Chinese
- Excluded apps, so a password manager never reaches the history
- History limit, appearance, and launch at login
- JSON export and import for moving between machines or builds

## Screenshots

<p align="center">
  <img src="docs/assets/screenshot-history-panel.png" width="900" alt="Clipbara history panel with clipboard cards at the bottom of the screen">
</p>

<p align="center">
  <img src="docs/assets/screenshot-menubar.png" width="320" alt="Clipbara menu bar dropdown with recent copies">
  &nbsp;&nbsp;
  <img src="docs/assets/screenshot-settings.png" width="420" alt="Clipbara settings window">
</p>

## Privacy

History is stored on your Mac with SwiftData. It leaves the Mac only if you turn on iCloud sync in the App Store build, and then it goes to your own private iCloud database, not to a server of ours. Sync is off until you turn it on. No account, no server, no analytics.

Everything except sync works offline. The DMG build reaches the network for one thing, Sparkle update checks, and the App Store build ships without an updater.

Add a password manager, or any other app, under **Settings > Exclusions** and nothing copied from it is recorded.

The DMG build needs Accessibility permission only if you turn on pasting into the active app or use Clip Queue. Both need it to press or notice <kbd>⌘</kbd> <kbd>V</kbd> in other apps, and nothing else uses it.

## FAQ

### Why doesn't Clipbara paste into the app for me?

By default, picking a clip puts it on the clipboard and closes the panel, and you press <kbd>⌘</kbd> <kbd>V</kbd> yourself. In the DMG build, turn on **Settings > General > Paste into the Active App** and Clipbara presses <kbd>⌘</kbd> <kbd>V</kbd> for you. That needs Accessibility permission in **System Settings > Privacy & Security > Accessibility**, and Settings shows whether it is on.

The App Store build doesn't have this option. Pressing a key in another app needs Accessibility permission, and App Review does not allow App Store apps to use it for anything other than accessibility.

### I hid the menu bar icon. How do I get back to Settings?

Open Clipbara again from Applications or Spotlight while it runs, and Settings opens. You can also press <kbd>⌘</kbd> <kbd>,</kbd> in the panel, or choose **Settings…** from its <kbd>…</kbd> menu.

If the icon doesn't reappear after you turn it back on, check the hidden section of your menu bar manager (Bartender, Ice, Thaw, and similar). A returning icon can land there.

### Can I sync with the DMG build?

No. Sync is part of the App Store build only. To move your history from the DMG build into the App Store build, use **Settings > General > Backup > Export** and **Import**.

### Why does iOS warn about Full Access for the keyboard?

iOS shows the same warning for every keyboard that asks for Full Access, because a keyboard with it could send what you type somewhere. The Clipbara keyboard has no letter keys, so you never type with it. Full Access only lets it read your own clips from iCloud while the app is closed, and the keyboard works without it.

### The shortcut does not open the panel

Another app may already hold <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>V</kbd>. Record a different combination in **Settings > Shortcuts**.

### Images do not paste in my terminal

Selecting an image clip puts the image back on the macOS clipboard, but a shell prompt cannot accept image data. The program running inside the terminal has to support it, and the shortcut is often not <kbd>⌘</kbd> <kbd>V</kbd>. Codex CLI, for example, attaches the clipboard image with <kbd>Control</kbd> <kbd>V</kbd>: press <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>V</kbd>, pick the image, go back to Codex without copying anything else, then press <kbd>Control</kbd> <kbd>V</kbd>.

### Where does the history live, and how do I remove it?

The DMG build stores it in `~/Library/Application Support/com.minsang.PasteClip`. The App Store build is sandboxed, so it stores it in `~/Library/Containers/com.minsang.Clipbara`. Deleting that folder deletes the history. If sync is on, **Delete iCloud Data…** in the Sync settings removes the copy in iCloud as well.

To uninstall, drag the app to the Trash, or run `brew uninstall --cask mobrava/tap/clipbara` if you installed it with Homebrew.

### Wasn't this called PasteClip?

It was, until August 2026. An unrelated app on the Mac App Store already used that name. Releases up to v1.1.11 still ship as PasteClip, and old links redirect on their own.

## Build from source

Requires macOS 14 or later, Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/mobrava/Clipbara.git
cd Clipbara
brew install xcodegen
xcodegen generate
open Clipbara.xcodeproj
```

Build and run the `Clipbara` scheme with <kbd>⌘</kbd> <kbd>R</kbd>. The iPhone app is the `ClipbaraiOS` scheme and needs Xcode 26. The app is Swift 6 with strict concurrency on, SwiftUI hosted inside an AppKit `NSPanel`, and SwiftData for storage. Global shortcuts come from [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), and DMG updates from [Sparkle](https://github.com/sparkle-project/Sparkle).

## Motivation

I wanted the card-style clipboard history that Paste has, without the subscription. The code and the DMG build stay free here. The App Store build is a one-time purchase, after a 7-day trial, for anyone who wants iPhone sync and updates through the App Store, or who wants to support the work.

A clipboard manager sees everything you copy, including the things you would rather it did not. That is reason enough to be able to read the code that touches it.

## Contributing

Issues and pull requests are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers the CLA that the dual licensing requires, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies.

## License

Clipbara is available under the [GNU General Public License v3.0](LICENSE).

The Mac App Store edition is distributed by the copyright holder under a separate
proprietary license (dual licensing). The source code for both editions lives in
this repository.

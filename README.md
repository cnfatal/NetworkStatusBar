# Network Status Bar

A macOS menu bar tool for monitoring real-time network traffic per process, written in **SwiftUI**.

## Preview

### Status Bar

```text
┌──────────────────────────────────────┐
│        ┊ 12.5KB/s ▲ ┊  Wi-Fi  🔍     │
│        ┊  3.2KB/s ▼ ┊                │
└──────────────────────────────────────┘
```

### Dropdown Menu

```text
┌────────────────────────────────┐
│  Network Traffic               │
│  ↑ 12.5KB/s    ↓ 3.2KB/s       │
├────────────────────────────────┤
│  Chrome           ↑  8.1KB/s   │
│                   ↓  2.0KB/s   │
│  Slack            ↑  3.2KB/s   │
│                   ↓  1.0KB/s   │
│  Terminal         ↑  1.2KB/s   │
│                   ↓  0.2KB/s   │
├────────────────────────────────┤
│  ⚙ Settings            ⌘ ,     │
│  ⏻ Quit                ⌘ Q     │
└────────────────────────────────┘
```

### Settings Window

```text
┌─ Settings ─────────────────────┐
│                                │
│  🕐 Refresh Interval           │
│  ┌────────────────────────┐    │
│  │ 1s  2s  3s  5s  10s    │    │
│  └────────────────────────┘    │
│                                │
│  🏎 Min Traffic Threshold      │
│  ┌────────────────────────┐    │
│  │ All  1KB  10KB  100KB  │    │
│  └────────────────────────┘    │
│                                │
│  🚫 Process Blacklist          │
│  ┌────────────────────────┐    │
│  │ Select process    [▾]  │    │
│  └────────────────────────┘    │
│  ┌─────────────────────┐       │
│  │ ClashX          (x) │       │
│  │ Surge           (x) │       │
│  └─────────────────────┘       │
│                                │
└────────────────────────────────┘
```

## Install

> **Requires macOS 14 (Sonoma) or later.**

### Homebrew

```bash
brew tap cnfatal/tap
brew install --cask network-status-bar
```

### Manual

Download the latest `NetworkStatusBar.zip` from [Releases](https://github.com/cnfatal/NetworkStatusBar/releases), unzip and drag `NetworkStatusBar.app` to `/Applications`.

> **Note:** The app is not notarized. On first launch, right-click → Open, or run `xattr -cr /Applications/NetworkStatusBar.app`.

## Features

- [x] SwiftUI based macOS menu bar app
- [x] Real-time network upload/download speed on status bar
- [x] Per-process network traffic breakdown in dropdown menu
- [x] Configurable refresh interval (1s / 2s / 3s / 5s / 10s)
- [x] Configurable minimum traffic threshold filter
- [x] Process blacklist — select from detected processes to exclude (e.g. proxies)
- [x] Standalone settings window (⌘,)
- [x] Settings persist via UserDefaults
- [x] Localization support (English / 中文)

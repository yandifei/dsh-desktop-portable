# DSH Desktop Portable (Windows)

**English** | [中文](README.zh-CN.md)

Unofficial portable build of [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) for **Windows x64**.
It keeps the official Electron desktop application, but moves every writable path next to the executable, so the
whole folder can live on a USB drive and be used on another Windows PC without installing anything.

> **This is not an official DeepSeek project.** It is not affiliated with, endorsed by, or supported by
> Hangzhou DeepSeek Artificial Intelligence Co., Ltd. "DeepSeek" and "DeepSeek Harness" are trademarks of their
> owner and are used here only to describe the upstream software.

## Features

- Official Electron desktop UI and official runtime packages (same app as the official installer).
- No installation, **no registry writes**, no PATH changes, no Start-menu entries.
- `DSH_HOME` is `<exe dir>\.dsh` (native name), Electron `userData` is `<exe dir>\@deepseek-ai\dsh-desktop`.
- Plugin packages, pnpm store/cache, pnpm state, plugin temp files and the first-use workspace all stay on the drive.
- The Host process resolves the user home to `<exe dir>\home`, so plugins that write to `~` stay portable.
- Built-in portable updater: downloads the official installer, verifies SHA-512 and Authenticode, extracts it
  **without running it**, re-applies the portable patches, and replaces program files while keeping data.
- Windows x64 only.

## Requirements

- Windows 10/11 x64.
- NTFS-formatted USB drive (exFAT works for normal use but does not support hard links/symlinks used by pnpm).
- WinRAR or 7-Zip installed when you use the updater (the updater extracts the official installer).

## Quick start

1. Download the latest release zip and extract it to the root of the USB drive (short path recommended).
2. Double-click `DeepSeek Harness.exe`.
3. Sign in or add an API key on the welcome page.
4. Quit from the tray, wait for the process to exit, then eject the drive safely.

No launcher script or environment variable is required.

## What is modified

Only `resources/app.asar` is patched (JavaScript). The Electron binaries remain the official signed files.
See [docs/how-it-works.md](docs/how-it-works.md) for the exact patch list.

## Data layout

| Path | Content |
| --- | --- |
| `.dsh\` | DSH_HOME: sessions, attachments, settings, credentials, plugins, runtime payload |
| `.dsh\profiles\desktop\node_modules` | installed plugins |
| `.dsh\cache\pnpm-store`, `.dsh\cache\pnpm-cache` | plugin download store and metadata cache |
| `.dsh\plugin-data\` | plugin-specific data (e.g. wallpaper engine) |
| `home\` | Host user home: `.agents`, `.bili-ai`, `.npmrc`, `AppData\Local` (pnpm state) |
| `@deepseek-ai\dsh-desktop\` | Electron cookies, local storage, shortcuts, caches |
| `@deepseek-aidsh-desktop-updater\` | updater download/temp/cache |

## Updates

Run `Update-Harness.cmd`. It reads the official feed, downloads the installer to
`@deepseek-aidsh-desktop-updater\download`, verifies it, extracts it, re-applies the patches, and restarts the app.
Data directories are preserved. If a patch anchor no longer matches a new upstream version, the updater aborts and
leaves the current version untouched.

## Build it yourself

```powershell
pwsh scripts/build.ps1 -Version latest
```

The script downloads the official installer from `download.deepseek.com`, verifies its signature and checksum,
extracts it, patches the asar, and writes a zip plus SHA-256 file under `dist/`. See [docs/build.md](docs/build.md).

## Security notes

- Release assets are built from the official signed installer; the build script verifies the installer's
  SHA-512 and Authenticode signature before extracting it.
- Always compare the SHA-256 published with a release.
- Do **not** sign in with a real account using a build from an untrusted source.
- The official auto-updater is disabled on purpose; the portable updater is the only update path.

## Limitations

- Windows x64 only. macOS/Linux are not supported by this repository.
- Modifying `app.asar` means the application is no longer byte-identical to the official payload; upstream support
  does not cover it.
- The first-use workspace is stored under `.dsh\workspace`. Workspace paths are absolute, so a drive-letter change
  requires selecting the workspace again (session data itself is preserved).
- Upstream releases may change JavaScript anchors; builds then fail safely until the patch script is updated.

## 中文说明

这是 **DeepSeek Harness 官方 Windows 桌面端的非官方便携化补丁**：只修改 `app.asar`，不安装、不写注册表，
`DSH_HOME`、浏览器数据、插件、pnpm 缓存、临时文件和默认工作区全部落在 exe 同级目录，可整个文件夹拷到
NTFS U 盘使用。更新用 `Update-Harness.cmd`（需要 WinRAR 或 7-Zip）。本项目与 DeepSeek 官方无关。

## License

The scripts and documentation in this repository are MIT licensed (see `LICENSE`).
The bundled DeepSeek Harness payload and third-party components keep their own licenses; see
`THIRD_PARTY_NOTICES.md` and the license files shipped with the release.

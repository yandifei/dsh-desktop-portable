# DSH Desktop Portable（Windows 中文说明）

[English](README.md) | 中文

这是 **DeepSeek Harness 官方 Windows 桌面端的非官方便携化版本**。程序本体与官方安装包一致，只修改了
`resources/app.asar`，让所有可写数据都落在 exe 同级目录，整个文件夹可以放在 U 盘里，换一台 Windows 电脑
直接双击运行。

> 本项目与 DeepSeek 官方无关，未获得官方背书或支持。"DeepSeek / DeepSeek Harness" 是其权利人的商标，
> 此处仅用于说明上游软件。

## 特性

- 保留官方 Electron 桌面体验与官方运行时包。
- 不安装、**不写注册表**、不改 PATH、不建开始菜单。
- `DSH_HOME` = `<exe 同级>\.dsh`；Electron 用户数据 = `<exe 同级>\@deepseek-ai\dsh-desktop`。
- 插件包、pnpm store/cache、pnpm 状态、临时文件、首次工作区全部留在 U 盘。
- Host 进程的用户目录重定向到 `<exe 同级>\home`，插件写到 `~` 的数据也不会落到系统盘。
- 内置便携更新器：下载官方安装包 → 校验 SHA-512 与数字签名 → 解包（不运行安装器）→ 重新打补丁 → 覆盖程序，
  数据目录保留。
- 仅支持 Windows x64。

## 环境要求

- Windows 10/11 x64。
- NTFS 格式 U 盘（exFAT 可用于日常使用，但 pnpm 的硬链接/符号链接可能受限）。
- 使用更新器时需要安装 WinRAR 或 7-Zip。

## 快速开始

1. 下载 Release 里的 zip，解压到 U 盘根目录（路径尽量短）。
2. 双击 `DeepSeek Harness.exe`。
3. 在欢迎页登录账号或填写 API Key。
4. 退出请用托盘 → Quit，等进程完全退出后再安全弹出 U 盘。

不需要启动脚本，也不需要设置环境变量。

## 数据位置

| 路径 | 内容 |
| --- | --- |
| `.dsh\` | DSH_HOME：会话、附件、设置、凭据、插件、运行时 |
| `.dsh\profiles\desktop\node_modules` | 已安装插件 |
| `.dsh\cache\pnpm-store`、`pnpm-cache` | 插件下载库与元数据缓存 |
| `.dsh\plugin-data\` | 插件自定义数据 |
| `home\` | Host 用户目录：`.agents`、`.bili-ai`、`.npmrc`、`AppData\Local` |
| `@deepseek-ai\dsh-desktop\` | Electron Cookie、LocalStorage、快捷键、缓存 |
| `@deepseek-aidsh-desktop-updater\` | 更新下载、临时文件、插件缓存 |

## 更新

双击 `Update-Harness.cmd`。它会从官方 feed 下载安装包到 `@deepseek-aidsh-desktop-updater\download`，校验后解包、
重新打补丁并覆盖程序文件；`.dsh`、`home` 等数据目录不会被动。

如果上游代码结构变化导致补丁失败，更新器会中止并保留当前版本。

## 自己构建

```powershell
pwsh scripts/build.ps1 -Version latest
```

输出在 `dist/`，包含 zip 和 `.sha256`。详见 [docs/build.md](docs/build.md)。

## 安全提示

- 每个 Release 附带 SHA-256，请核对。
- 构建脚本只从官方安装包解包；校验 SHA-512 与 Authenticode 签名。
- 不要用来源不明的预构建包登录真实账号。
- 官方自动更新已禁用，更新只走包内更新器。

## 已知限制

- 仅 Windows x64；macOS/Linux 不支持。
- 修改过 `app.asar`，与官方 payload 不再逐字节一致，官方不支持此用法。
- 工作区路径是绝对路径，换盘符后需要重新选择工作区（会话数据仍在 `.dsh`）。
- 上游 JS 结构变化可能导致补丁失败，需要更新 `scripts/patch-asar.js` 的锚点。

## 许可证

仓库内脚本与文档为 MIT（见 `LICENSE`）；官方 payload 与第三方组件遵循各自许可证（见
`THIRD_PARTY_NOTICES.md`）。

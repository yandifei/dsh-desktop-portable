# 更新便携包

## 原地更新

在包根目录运行 `Update-Harness.cmd`（或 `Update-Harness.ps1`）。

1. 读取 `https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml`。
2. 从 `resources\runtime\primary-runtime\runtime.json` 读取当前版本。
3. 把官方安装包下载到 `@deepseek-aidsh-desktop-updater\download`。
4. 校验 feed 的 SHA-512 与 Authenticode 签名。
5. 用 WinRAR 或 7-Zip 解包到 `@deepseek-aidsh-desktop-updater\staging`。
6. 对新 payload 执行 `Patch-Asar.js`。
7. 覆盖程序文件，保留 `.dsh`、`home`、`@deepseek-ai`、`@deepseek-aidsh-desktop-updater`。
8. 把新的 `resources/app-update.yml` 改名为 `.disabled`，然后启动应用。

前置条件：

- DeepSeek Harness 必须已经完全退出。
- 本机需安装 WinRAR 或 7-Zip（更新器只解包官方安装包，不会运行它）。

## 版本比较

更新器按版本号比较，而不是字符串相等：

- 当前版本等于 feed → 提示已是最新。
- 当前版本高于 feed（例如本仓库先于官方 feed 发布了包）→ 提示无需更新，**不会降级**。
- 只有 feed 版本更高时才下载安装。

## 安全性

- 更新器从不运行官方安装器，因此不写注册表、不安装任何东西。
- 数据目录被显式保留。
- 校验或补丁失败时，在动任何程序文件之前就会退出。
- 官方更新器保持禁用（`app-update.yml.disabled`），应用内更新无法把文件装回机器上的固定路径。

## 手动重建

如果更新器无法为新的上游版本打补丁，从源码重建：

```powershell
pwsh scripts/build.ps1 -Version latest
```

然后把新 zip 解压覆盖到现有包目录，保留数据目录。

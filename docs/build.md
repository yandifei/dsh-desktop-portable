# 构建

## 环境要求

- Windows 10/11 x64。
- PowerShell 7（`pwsh`）。
- 已安装 7-Zip 或 WinRAR（用来解包官方安装包）。
- 能访问 `download.deepseek.com`。

## 构建

```powershell
pwsh scripts/build.ps1
```

脚本会依次执行：

1. 读取官方 nightly feed，解析最新的 Windows x64 安装包。
2. 下载，并校验 feed 公布的 SHA-512 与 Authenticode 签名。
3. 解包（不运行安装器）。
4. 用 payload 自带的 Node 运行时执行 `scripts/patch-asar.js`。
5. 禁用官方自动更新（`app-update.yml` → `.disabled`）。
6. 把 README、许可证声明、docs、`Patch-Asar.js` 与更新器脚本拷进包内。
7. 压缩 payload，并写出对应的 `.sha256`。

产物：`dist/DSH-Desktop-Portable-<版本>-win-x64.zip` 和同名的 `.sha256`。

只校验补丁锚点是否仍匹配上游、不产出压缩包：

```powershell
pwsh scripts/build.ps1 -Version latest -NoArchive
```

校验已完成的压缩包（校验和、必需文件、有没有混入个人数据）：

```powershell
pwsh scripts/verify-release.ps1 -Zip dist\DSH-Desktop-Portable-<版本>-win-x64.zip
```

## 固定版本

```powershell
pwsh scripts/build.ps1 -Version 0.2.2-rc.1
```

固定版本时 feed 没有对应的校验和，只能校验 Authenticode 签名。优先使用默认的 feed 流程，它会同时校验两者。

## CI

`.github/workflows/build.yml` 在 `windows-latest` 上构建并上传 artifact；推送 `v*` 标签时会把 zip 附到
GitHub Release，并把该 Release 标记为 latest。流程使用 Actions 自带的 `GITHUB_TOKEN`，不需要额外配置 secret。

## 校验构建产物

- 用 Release 附带的 `.sha256` 对比下载包的 SHA-256。
- 可选：审阅 `scripts/patch-asar.js`，它是唯一改写 payload 的代码。
- 本地重新构建同一上游版本，比较生成的 `app.asar` 哈希。

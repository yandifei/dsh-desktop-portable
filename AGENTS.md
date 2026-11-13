# AGENTS.md

本文件约束在本仓库工作的 AI 代理（以及自动化脚本）。人类贡献者也建议遵守。

## 项目定位

- 本项目是 **DeepSeek Harness 官方 Windows 桌面端的非官方便携化封装**，受众是中文用户。
- 只改 `resources/app.asar` 与打包脚本；官方 Electron 二进制、安装包来源、签名校验流程都不动。
- 补丁面越小越好：每多一个补丁，上游一变就多一处维护成本。

## 语言规范（硬性）

**面向用户的文字一律用简体中文。** 包括：

| 位置 | 语言 | 说明 |
| --- | --- | --- |
| `README.md` | 中文 | 主文档，中文是默认版本 |
| `README.en.md` | 英文 | 仅作对照镜像，改 `README.md` 时必须同步 |
| `CHANGELOG.md` | 中文 | 面向用户，不要写英文条目 |
| `docs/*.md` | 中文 | 构建、更新、原理、排障 |
| Release 标题与正文 | 中文 | 标题可用版本号，正文用中文模板（见下） |
| commit message | 中文 | 见下 |
| Issue / PR 模板 | 中文 | 字段 `id`、`type`、标签名保持英文，展示文字用中文 |
| 代码、脚本、变量、日志、文件名 | 英文 | 便于和上游对照，不要翻译 |

其它约定：

- 技术名词保留原文：`app.asar`、`Authenticode`、`pnpm`、`SHA-512`、`payload`，不要硬翻成生造词。
- 不要在中文文档里中英混排整句；除了命令、路径、标识符，正文用中文。
- 命令块里的注释也用中文（`# 只校验补丁锚点，不产出压缩包`）。

## README 结构

`README.md` 的板块顺序固定，改动时不要打乱：

1. 横幅 `docs/assets/banner.svg`
2. 一句话定位
3. 徽章行（平台 / release / 下载量 / 上游检查 / 许可证）
4. 语言切换（`简体中文` · `English`）
5. `> [!WARNING]` 非官方声明
6. 特性
7. 快速开始
8. 与官方安装版对比
9. 数据布局（路径表 + 目录树）
10. 更新
11. 自己构建
12. 工作原理
13. 安全
14. 常见问题（`<details>` 折叠）
15. 已知限制
16. 贡献与反馈
17. 许可证与致谢
18. 结尾 Star 引导

硬性要求：

- 只写仓库里能验证的事实。**不编造截图**、不写没测过的性能数字、不承诺未实现的功能。
- 版本号示例（下载文件名、`verify-release.ps1` 的参数）必须与最新 Release 一致。
- 图片放 `docs/assets/`（会随包发布），用相对路径引用，不要用外链图床。
- 不引入 Star History 之类在国内打不开的图床（会变裂图）。

## 提交信息

格式：`类型: 中文摘要`

- 类型用：`feat` / `fix` / `docs` / `chore` / `release` / `ci`。
- 摘要用中文、动词开头、不超过 50 字，句尾不加句号。
- 正文写 **为什么**，可分条；命令、版本号、路径原样保留。

示例：

```text
release: 打包 0.2.2-rc.2，修掉降级与 NSIS 残留

- payload 固定到上游 0.2.2-rc.2（feed 仍是 rc.1，只验签名）
- 便携更新器改为比较版本，当前包比 feed 新时不再回退
```

禁止：

- `update files`、`fix bug`、`修改了一下` 这类没有信息量的摘要。
- 在同一个提交里夹带无关的格式化改动。

## Release 规范

- 标题：`vX.Y.Z-type.N`（与 tag 一致）；需要说明时用 `vX.Y.Z — Windows x64 便携版`。
- 正文模板（中文）：

  ```text
  DeepSeek Harness <版本> 的 Windows x64 便携版。

  - 基于官方安装包构建，解包前已校验 Authenticode 签名。
  - payload 已打便携补丁：所有可写路径留在 exe 同级目录。
  - 下载后请比对附带的 .sha256。
  - 非官方构建，与 DeepSeek 官方无关。

  使用方法见 README.md，变更见 CHANGELOG.md。
  ```

- 资产命名固定：`DSH-Desktop-Portable-<版本>-win-x64.zip` 与同名 `.sha256`，两个都要上传。
- 发布即 **Latest**：GitHub 的 latest 与 pre-release 互斥，本仓库选择 latest，保证
  `/releases/latest` 和 Releases 页始终指向最新可下载的包。
- 若官方 feed（`nightly.yml`）尚未推进到该版本，正文必须补一句：官方更新通道仍是 `<旧版本>`，
  包内更新器不会自动升级也不会降级，需要手动下载覆盖。

## 发布前检查

```powershell
# 1. 补丁锚点是否还能匹配新 payload
pwsh scripts/build.ps1 -Version <版本> -NoArchive

# 2. 校验成品：校验和、必需文件、有无个人数据、asar 是否可加载
pwsh scripts/verify-release.ps1 -Zip dist\DSH-Desktop-Portable-<版本>-win-x64.zip
```

- 确认包内 `resources\runtime\primary-runtime\runtime.json` 的 `desktopVersion` 正确。
- 确认 `resources\app.asar` 里有四个补丁标记（`__dshPortableRoot`、`DSH_HOME ??=`、
  `DSH_DESKTOP_REGISTER_PROTOCOL`、`.dsh\workspace`）。
- **确认 asar 根 `package.json` 能被 `JSON.parse`**。重写 asar 时数据区起点是 `8 + headerSize`
  （含 4 字节对齐填充），算错会让每个文件整体位移几字节，而 offset/integrity 又自洽，
  校验和与"文件齐全"都发现不了——只有真正解析清单才拦得住（rc.2 就栽在这里）。
- 确认包里没有 `$PLUGINSDIR`（NSIS 解包残留，约 285 MB）。
- 不提交 `dist/`、`.dsh/`、`home/`、`@deepseek-ai/`、`@deepseek-aidsh-desktop-updater/`（`.gitignore` 已覆盖）。
- 发布后把线上包下载回来跑一次 `verify-release.ps1`，并核对其 SHA-256 与 Release 附件一致。

## 安全

- 不要在日志、回复或提交里输出凭据、token、Cookie、会话内容、个人路径。
- 临时保存的凭据用完立即删除。
- Release 只允许从官方安装包构建；构建前必须校验 SHA-512（feed 提供时）与 Authenticode 签名。

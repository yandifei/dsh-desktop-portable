# 变更日志

本项目的所有重要变更都记录在这里。

## v0.2.2-rc.2（2026-11-13）

基于上游 `0.2.2-rc.2` payload 重新打包（上游 GitHub 发版 `dsh-v0.2.2-rc.2`，2026-11-11）。

- payload：`0.2.2-rc.2`。打包时官方桌面 feed（`nightly.yml`）仍指向 `0.2.2-rc.1`，因此按版本号固定构建，
  只能校验安装包的 Authenticode 签名（feed 没有为该版本发布 SHA-512）。
- 补丁锚点在 rc.2 的 payload 上未变，便携补丁面与 rc.1 完全一致。
- 便携更新器：版本改为比较大小而不是字符串相等。当前包比 feed 新时保持不动、不再降级，
  同时正确处理预发布序号（`-rc.2` > `-rc.1`）。
- 打包：解包后删除 NSIS 的 `$PLUGINSDIR` 暂存目录（约 285 MB，内含 payload 的另一份副本），不再打进 zip。
  构建脚本与更新器都已处理，更新时也不会把这些文件拷进包目录。
- 发布流程：`v*` 标签决定构建哪个 payload 版本（此前所有标签都取 feed 的 `latest`，打固定版本标签会发错包），
  Release 正文会写明确切版本。
- 发布标记：以 **latest** 发布而非预发布，保证 `/releases/latest` 与 Releases 页始终指向最新可下载的包。
  GitHub 的 "latest" 与 "pre-release" 互斥，因此 rc 构建不再带预发布标记——版本号本身仍是 `rc`。
- **修复 rc.2 发布包无法启动**：`Patch-Asar.js` 计算数据区起点时用了 `16 + jsonLength`，忽略了 header 的
  4 字节对齐填充。当 header 长度不是 4 的倍数时（rc.2 的 padding 为 3），读文件会整体前移 3 字节：
  根 `package.json` 变成 `);{…}` 的非法 JSON，Electron 回退到默认页；完整性块因为也是按同一份错位数据
  重算的，所以「校验全过」但内容已坏。rc.1 的 header 恰好对齐，所以没暴露。
  现在改为按文件头里的 `headerSize` 计算数据区起点（`8 + headerSize`），并在写完归档后自检：
  根 `package.json` 必须能 `JSON.parse`、三处补丁标记必须存在、**所有未改动文件必须与原包逐字节一致**；
  任一项不通过就删除临时归档、保持原 payload 不动（退出码 2）。
  `verify-release.ps1` 增加同样的断言，这类事故以后在发布前就会被拦下。

## v0.2.2-rc.1（2026-11-11）

首次公开发布。

- 基于官方 DeepSeek Harness 安装包构建 Windows x64 便携包的工具链。
- 只补丁 `resources/app.asar`：
  - `DSH_HOME`、Electron `userData`/`sessionData`、临时目录与壁纸引擎数据目录都落在 exe 同级；
  - `defaultDshHome()` 解析到 exe 同级；
  - Host 进程的 `USERPROFILE`/`LOCALAPPDATA` 指向便携的 `home` 目录；
  - 首次工作区落在 `.dsh\workspace`；
  - `dsh://` 协议注册改为可选（`DSH_DESKTOP_REGISTER_PROTOCOL=1`）；
  - 禁用官方 NSIS 自动更新（`app-update.yml` 改名）。
- 便携更新器（`Update-Harness.ps1`）：下载官方安装包、校验 SHA-512 与 Authenticode、解包但不运行、
  重新打补丁并保留用户数据。
- GitHub Actions 工作流：标签发布 + 每周的上游兼容性检查。
- 解包支持 NSIS 内层的 `$PLUGINSDIR/app-64.7z`，只装了 7-Zip 的机器在构建脚本和更新器里都能用。
- `Verify-Release.ps1`（校验和、必需文件、个人数据检查）、中文 README、贡献指南、Issue/PR 模板与排障文档。

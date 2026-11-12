# 便携化是怎么实现的

本项目保留**官方**的 DeepSeek Harness Electron 桌面 payload，只补丁 `resources/app.asar`。
`app.asar` 是未加密归档（JSON 头 + 拼接的文件），所以补丁脚本可以原位重写：

- 打包文件按原顺序复制，重新计算偏移与 SHA-256 完整性块；
- 标记为 `unpacked` 的文件仍留在 `resources/app.asar.unpacked`，引用方式不变；
- 只改 `lib/main.js` 和两个 workspace-controller 模块。

`.exe` 与 DLL 仍是官方签名的二进制。Windows 的 Authenticode 签名覆盖可执行文件而不是 `app.asar`，
所以应用仍能正常启动——也正因 UI 代码被改过，本项目是非官方的。

## 补丁

### 1. 便携根目录与数据路径（`lib/main.js`）

模块加载时，应用从 `dirname(process.execPath)` 推出根目录，然后：

| 设置 | 便携值 |
| --- | --- |
| `DSH_HOME` | `<root>\.dsh` |
| `TEMP`、`TMP` | `<root>\@deepseek-aidsh-desktop-updater\temp` |
| `DSH_WE_DATA_DIR` | `<root>\.dsh\plugin-data\wallpaper-engine` |
| `DSH_WE_CACHE_DIR` | `<root>\@deepseek-aidsh-desktop-updater\wallpaper-engine-cache` |
| Electron `userData` / `sessionData` | `<root>\@deepseek-ai\dsh-desktop` |
| `defaultDshHome()` | `<root>\.dsh` |

`DSH_*` 的值用 `??=` 赋值，显式设置的环境变量仍然优先。

### 2. Host 进程的用户目录（`desktopNodeEnvironment` 调用）

Host（以及它派生的所有插件、agent 子进程）会收到：

- `USERPROFILE` = `<root>\home`，于是 `os.homedir()` 和 `~` 都落在盘上；
- `LOCALAPPDATA` = `<root>\home\AppData\Local`，pnpm 状态之类的缓存留在盘上；
- `HOME` = 真实用户目录，保证 git/ssh 配置照常可用。

### 3. 首次工作区

`@deepseek-ai/dsh-api-workspace-controller` 里有两份相同逻辑（`lib/index.js` 内联一份，
`lib/types/default-directory.js` 转出另一份）。两处都改成：

```js
if (documentsDirectory === undefined) {
  const portableHome = process.env.DSH_HOME || paths.join(paths.dirname(process.execPath), '.dsh');
  return paths.join(portableHome, 'workspace', 'deepseek-harness', DEFAULT_WORKSPACE_DIRECTORY);
}
```

默认工作区因此创建在 `.dsh\workspace` 下，而不是「文档」。

### 4. 协议注册

`app.setAsDefaultProtocolClient('dsh')` 改为按需启用：

```js
if (process.env.DSH_DESKTOP_REGISTER_PROTOCOL === '1') app.setAsDefaultProtocolClient('dsh');
```

启动默认不写注册表。代价是 `dsh://open` 深链不再唤起应用。

### 5. 更新

官方更新器只在 `resources/app-update.yml` 存在时才启用，所以构建脚本把它改名为 `app-update.yml.disabled`。
包内的 `Update-Harness.ps1` 用便携流程替代：解包官方安装包，而不是运行它。

## 数据布局

| 路径 | 内容 |
| --- | --- |
| `.dsh\` | DSH_HOME：会话、设置、凭据、插件、运行时 |
| `.dsh\profiles\desktop\node_modules` | 插件管理安装的插件 |
| `.dsh\cache\pnpm-store`、`.dsh\cache\pnpm-cache` | pnpm 下载库与元数据缓存（在 profile 里按相对路径配置） |
| `.dsh\plugin-data\` | 插件数据（壁纸引擎等） |
| `home\` | Host 用户目录：`.agents`、`.bili-ai`、`.npmrc`、`AppData\Local` |
| `@deepseek-ai\dsh-desktop\` | Electron Cookie、LocalStorage、快捷键、缓存 |
| `@deepseek-aidsh-desktop-updater\` | 更新下载、暂存、临时文件、壁纸缓存 |

## 失败行为

每个补丁锚点都有断言。上游发版改了周边代码时，`Patch-Asar.js` 会在动 payload 之前以退出码 2 结束。
构建脚本随后中止；更新器同理，当前安装保持不动。

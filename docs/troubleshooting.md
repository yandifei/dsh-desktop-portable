# 故障排查

## 应用起不来

- 确认是 x64 Windows，U 盘是 NTFS。
- 路径尽量短，不要带奇怪字符。
- 看 `@deepseek-ai\dsh-desktop\logs` 和 Windows 事件查看器。
- 杀毒软件可能隔离被修改过的 `app.asar`；只有在你信任这个构建时才加白名单。

## 应用能起，但数据跑到了系统盘

- 便携路径由 `process.execPath` 推导。不要只拷 exe，整个文件夹一起拷。
- `C:\Users\<用户>\.dsh` 下的旧数据不会被便携版使用，这是预期行为。
- 硬编码 `%APPDATA%` 或绝对路径的第三方插件仍可能写到包外。

## 更新时报 "patch failed"

上游改了 JavaScript 结构。`Patch-Asar.js` 会在修改 payload 之前退出，当前版本继续可用。
更新 `scripts/patch-asar.js` 里的锚点后本地重建，或者带上游版本号提 issue。

## 更新时报 "WinRAR or 7-Zip is required"

装其中之一。更新器需要解包官方安装包、不会运行它，所以必须有解包工具。

## 换了盘符，工作区不见了

DSH 把工作区路径存成绝对路径。在新盘符上重新选择/添加工作区即可；会话仍在 `.dsh` 下。
经常换机器的话，建议给 U 盘固定一个盘符。

## 换了盘之后登录状态丢失

Cookie 在 `@deepseek-ai\dsh-desktop`。确保应用关闭时整目录拷贝，并且不要删除 `Local State`
（它保存着加密 Cookie 所用的密钥）。

## 回滚

更新前把整个包目录复制一份；或者用 `pwsh scripts/build.ps1 -Version <旧版本>` 重建旧版本，
解压覆盖到包目录，保留数据目录即可。

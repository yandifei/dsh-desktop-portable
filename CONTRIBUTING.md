# 贡献指南

感谢你考虑参与这个项目。它只是官方 DeepSeek Harness payload 外面的一层小封装，保持"小"本身就是设计目标。

## 基本规则

- 这**不是** DeepSeek 官方项目。不要声称官方关联，不要使用官方品牌作为项目身份。
- 绝不提交个人数据：`.dsh`、`home`、`@deepseek-ai`、Cookie、凭据、会话或插件状态。
- 保持补丁面最小。每多一个补丁，上游一变就多一处维护成本。
- 修改官方 payload 中 `resources/app.asar` 之外内容的需求，不在本项目范围内。

## 开发

1. 准备 Windows 10/11 x64、PowerShell 7 和 7-Zip（或 WinRAR）。
2. 克隆仓库。
3. 构建：

   ```powershell
   pwsh scripts/build.ps1 -Version latest
   ```

4. 把 `dist/*.zip` 解压到一个临时目录，启动 `DeepSeek Harness.exe` 验证：它会在 exe 同级创建 `.dsh`，
   并且不写 `dsh://` 注册表键。
5. 检查 `dist/*.sha256`。

## 修改补丁

`scripts/patch-asar.js` 在改动 payload 之前会断言每个锚点。上游变化时：

- 在 `resources/app.asar` 里定位新代码；
- 更新锚点与替换内容；
- 用 `-NoArchive` 快速验证一次构建。

锚点匹配不上时，脚本以退出码 2 结束且 payload 保持原样——请保留这个行为。

## 提交合并请求（PR）

- 说明问题、改动内容，以及你如何验证。
- 注明测试所用的上游版本号。
- 不要包含构建产物或个人数据。
- 提交 PR 即表示你同意贡献内容以 MIT 协议授权。

## 发布流程

维护者用 `scripts/build.ps1` 本地构建，验证产物后发布带 zip 与 `.sha256` 的 Release。
推送 `v*` 标签也会触发 GitHub Actions 的发布工作流。

## 语言

面向用户的文档、Release 说明和提交信息统一用简体中文；代码、脚本与变量名保持英文。
详见 [AGENTS.md](AGENTS.md)。

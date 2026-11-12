# 安全策略

## 报告漏洞

请通过 GitHub Security Advisories（"Report a vulnerability"）私下报告，不要开公开 issue。

## 本项目做什么

- 从**官方** DeepSeek Harness 安装包构建便携包。
- 解包之前校验安装包的 SHA-512 与 Authenticode 签名。
- 只补丁 `resources/app.asar`，Electron 二进制保持官方文件。
- 禁用官方自动更新，提供只从官方 feed 下载的便携更新器。

## 信任模型

- 发布资产由本项目的 GitHub Actions 工作流从官方安装包构建；每个 Release 都附带 SHA-256。
- 补丁脚本很小、可审计；你也可以用 `scripts/build.ps1` 自己构建。
- Release 中不含任何凭据、Cookie、会话或个人数据。

## 给用户的建议

- 把下载包的 SHA-256 与公布值对比。
- 不要用来路不明的构建登录真实账号。
- 包会把 Host 进程的 `USERPROFILE` 与 `LOCALAPPDATA` 重定向到便携的 `home\` 目录；这是有意为之，已在文档中说明。
- 如果预构建包里出现了不是本仓库产出的文件，请视为不可信。

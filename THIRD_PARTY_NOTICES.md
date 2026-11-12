# 第三方声明

本仓库构建的发布包内嵌官方 DeepSeek Harness 桌面 payload。本项目不为该 payload 重新授权，
只是补丁 `resources/app.asar`，让应用保持便携。

## DeepSeek Harness

- 项目：https://github.com/deepseek-ai/deepseek-harness
- 许可证：MIT
- 版权：Hangzhou DeepSeek Artificial Intelligence Co., Ltd.

官方安装包的文件（含 `LICENSE.electron.txt` 与 `LICENSES.chromium.html`）在发布包中原样保留。

## Electron

- 项目：https://www.electronjs.org/
- 许可证：MIT
- 发布包内的 Electron 运行时由官方 DeepSeek Harness 安装包提供。

## Chromium

- 项目：https://www.chromium.org/
- 许可证：BSD 风格许可及第三方许可
- 详见发布包内的 `LICENSES.chromium.html`。

## Node.js

- 项目：https://nodejs.org/
- 许可证：MIT
- 由官方安装包放在 `resources/runtime/primary-runtime/dependencies/node`。

## Python

- 项目：https://www.python.org/
- 许可证：PSF License
- 由官方安装包放在 `resources/runtime/primary-runtime/dependencies/python`。

## pnpm

- 项目：https://pnpm.io/
- 许可证：MIT
- 由官方安装包放在 `resources/runtime/primary-runtime/dependencies/pnpm`。

## 构建与更新工具（不随包分发）

- 7-Zip：https://www.7-zip.org/（LGPL）；构建脚本在本机安装了它时才会调用。
- WinRAR：专有软件；更新器在本机安装了它时才会调用。

## 商标

"DeepSeek"、"DeepSeek Harness" 及相关标识是其权利人的商标。本项目为非官方项目，
不使用官方标识作为项目身份。

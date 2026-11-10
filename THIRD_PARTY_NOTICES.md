# Third-party notices

Release packages built by this repository embed the official DeepSeek Harness
desktop payload. This project does not relicense that payload; it only patches
`resources/app.asar` so the application stays portable.

## DeepSeek Harness

- Project: https://github.com/deepseek-ai/deepseek-harness
- License: MIT
- Copyright: Hangzhou DeepSeek Artificial Intelligence Co., Ltd.

The official installer's files (including `LICENSE.electron.txt` and
`LICENSES.chromium.html`) are shipped unchanged in the release package.

## Electron

- Project: https://www.electronjs.org/
- License: MIT
- The release package contains the official Electron runtime as shipped by the
  DeepSeek Harness installer.

## Chromium

- Project: https://www.chromium.org/
- License: BSD-style and third-party licenses
- See `LICENSES.chromium.html` in the release package.

## Node.js

- Project: https://nodejs.org/
- License: MIT
- Bundled by the official installer under `resources/runtime/primary-runtime/dependencies/node`.

## Python

- Project: https://www.python.org/
- License: PSF License
- Bundled by the official installer under `resources/runtime/primary-runtime/dependencies/python`.

## pnpm

- Project: https://pnpm.io/
- License: MIT
- Bundled by the official installer under `resources/runtime/primary-runtime/dependencies/pnpm`.

## Build and update tools (not redistributed)

- 7-Zip: https://www.7-zip.org/ (LGPL); used locally by the build script if installed.
- WinRAR: proprietary; used locally by the updater if installed.

## Trademarks

"DeepSeek", "DeepSeek Harness" and associated logos are trademarks of their
owner. This project is unofficial and does not use the official logo as its
project identity.

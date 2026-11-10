# Building

## Requirements

- Windows 10/11 x64.
- PowerShell 7 (`pwsh`).
- 7-Zip or WinRAR installed (used to extract the official installer).
- Network access to `download.deepseek.com`.

## Build

```powershell
pwsh scripts/build.ps1
```

Steps performed by the script:

1. Read the official nightly feed and resolve the newest Windows x64 installer.
2. Download it and verify its SHA-512 (published in the feed) and Authenticode signature.
3. Extract it without running it.
4. Run `scripts/patch-asar.js` with the Node runtime bundled in the payload.
5. Disable the official updater (`app-update.yml` → `.disabled`).
6. Copy the README, license notices, docs, `Patch-Asar.js` and updater scripts into the package.
7. Zip the payload and write a `.sha256` file.

Output: `dist/DSH-Desktop-Portable-<version>-win-x64.zip` and the matching `.sha256`.

## Pinning a version

```powershell
pwsh scripts/build.ps1 -Version 0.2.2-rc.1
```

For a pinned version the feed checksum is unavailable, so only the Authenticode signature is verified. Prefer
the default feed flow, which verifies both.

## CI

`.github/workflows/build.yml` builds on `windows-latest`, uploads the artifact, and attaches the zip to a GitHub
release when a `v*` tag is pushed. It uses the `GITHUB_TOKEN` provided by Actions; no secrets are required.

## Verifying a build

- Compare the release SHA-256 with the `.sha256` asset.
- Optionally inspect `scripts/patch-asar.js`: it is the only code that rewrites the payload.
- Rebuild locally and compare the resulting `app.asar` hash for the same upstream version.

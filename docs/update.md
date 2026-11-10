# Updating the portable package

## In-place update

Run `Update-Harness.cmd` (or `Update-Harness.ps1`) from the package root.

1. Reads `https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml`.
2. Reads the current version from `resources\runtime\primary-runtime\runtime.json`.
3. Downloads the official installer to `@deepseek-aidsh-desktop-updater\download`.
4. Verifies SHA-512 from the feed and the Authenticode signature.
5. Extracts the installer to `@deepseek-aidsh-desktop-updater\staging` with WinRAR or 7-Zip.
6. Runs `Patch-Asar.js` against the new payload.
7. Copies program files over the current root, keeping `.dsh`, `home`, `@deepseek-ai` and
   `@deepseek-aidsh-desktop-updater`.
8. Renames the new `resources/app-update.yml` to `.disabled` and starts the app.

Requirements:

- DeepSeek Harness must be closed.
- WinRAR or 7-Zip must be installed (the updater extracts the official installer).

## Safety properties

- The updater never runs the official installer, so it writes no registry keys and installs nothing.
- Data directories are explicitly preserved.
- A checksum or patch failure aborts before program files are touched.
- The official updater remains disabled (`app-update.yml.disabled`), so the in-app update dialogs cannot
  install into a fixed machine path.

## Manual rebuild

If the updater cannot patch a new upstream release, rebuild from source:

```powershell
pwsh scripts/build.ps1 -Version latest
```

Then extract the new zip over the package while keeping the data directories.

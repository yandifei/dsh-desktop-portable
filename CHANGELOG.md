# Changelog

All notable changes to this project are documented here.

## v0.2.2-rc.1 (2026-11-11)

Initial public release.

- Build tooling for a portable Windows x64 package based on the official DeepSeek Harness installer.
- Patches `resources/app.asar` only:
  - `DSH_HOME`, Electron `userData`/`sessionData`, temp dirs and wallpaper-engine data dirs next to the executable;
  - `defaultDshHome()` resolves next to the executable;
  - Host `USERPROFILE`/`LOCALAPPDATA` point into the portable `home` directory;
  - first-use workspace under `.dsh\workspace`;
  - `dsh://` protocol registration is opt-in (`DSH_DESKTOP_REGISTER_PROTOCOL=1`);
  - official NSIS auto-updater disabled (`app-update.yml` renamed).
- Portable updater (`Update-Harness.ps1`) that downloads the official installer, verifies SHA-512 and
  Authenticode, extracts it without running it, re-applies the patches and keeps user data.
- GitHub Actions workflow for tag-based releases and a scheduled upstream compatibility check.

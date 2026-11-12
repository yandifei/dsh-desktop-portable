# Changelog

All notable changes to this project are documented here.

## v0.2.2-rc.2 (2026-11-13)

Repackaged on the upstream `0.2.2-rc.2` payload (upstream GitHub release `dsh-v0.2.2-rc.2`, 2026-11-11).

- Payload: `0.2.2-rc.2`. The Windows desktop feed (`nightly.yml`) still advertised `0.2.2-rc.1` when this
  package was built, so the version is pinned and the installer was verified through its Authenticode
  signature (the feed publishes no checksum for an unpublished version).
- Patch anchors still match the rc.2 payload unchanged; the portable patch surface is identical to rc.1.
- Portable updater: versions are now compared instead of matched as strings. A package newer than the feed
  is left alone instead of being downgraded, and prerelease ordering (`-rc.2` > `-rc.1`) is handled.
- Packaging: the NSIS extractor's `$PLUGINSDIR` staging directory (about 285 MB, including its own copy of
  the payload) is now removed after extraction instead of being shipped inside the zip. The build and the
  updater both did this, so update packages also stop copying those files into the package folder.
- Release workflow: a `v*` tag now decides which payload version is built. Previously every tag built the
  feed's `latest`, which would have published the wrong payload for a pinned tag. Tags containing a
  prerelease suffix are now published as GitHub prereleases, and the release notes state the exact
  payload version.

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
- Extraction handles the nested `$PLUGINSDIR/app-64.7z` payload, so machines with only 7-Zip work in both the
  build script and the updater.
- `Verify-Release.ps1` (checksum, required files, personal-data check), Chinese README, contribution guide,
  issue/PR templates and troubleshooting docs.

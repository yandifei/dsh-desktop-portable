# Security policy

## Reporting

Please report security issues privately via GitHub Security Advisories
("Report a vulnerability") rather than a public issue.

## What this project does

- Builds a portable package from the **official** DeepSeek Harness installer.
- Verifies the installer's SHA-512 and Authenticode signature before extracting.
- Patches only `resources/app.asar`; the Electron binaries stay official.
- Disables the official auto-updater and provides a portable updater that
  downloads only from the official feed.

## Trust model

- Release assets are built by the project's GitHub Actions workflow from the
  official installer; each release publishes a SHA-256 checksum.
- The patch script is small and auditable; you can build the package yourself
  with `scripts/build.ps1`.
- No credentials, cookies, sessions or personal data are included in releases.

## For users

- Compare the SHA-256 of a downloaded release with the published value.
- Do not sign in with a real account using a build from an untrusted source.
- The package redirects the Host process's `USERPROFILE` and `LOCALAPPDATA` to
  the portable `home\` directory; this is intentional and documented.
- If you find a prebuilt package that contains files not produced by this
  repository, treat it as untrusted.

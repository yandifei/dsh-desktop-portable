# Contributing

Thanks for considering a contribution. This project is a small, auditable wrapper around the official
DeepSeek Harness payload; keeping it small is part of the design.

## Ground rules

- This is **not** an official DeepSeek project. Do not claim affiliation or use official branding.
- Never commit personal data: no `.dsh`, `home`, `@deepseek-ai`, cookies, credentials, sessions or plugin state.
- Keep the patch surface minimal. Every extra patch is a new maintenance burden when upstream changes.
- Changes that alter the official payload beyond `resources/app.asar` are out of scope.

## Development

1. Install Windows 10/11 x64, PowerShell 7 and 7-Zip (or WinRAR).
2. Clone the repository.
3. Build:

   ```powershell
   pwsh scripts/build.ps1 -Version latest
   ```

4. Test the artifact by extracting `dist/*.zip` into a throwaway directory and starting `DeepSeek Harness.exe`.
   Verify it creates `.dsh` next to the exe and does not write the `dsh://` registry key.
5. Check `dist/*.sha256`.

## Changing the patches

`scripts/patch-asar.js` asserts every anchor before modifying the payload. When upstream changes:

- Locate the new code in `resources/app.asar`.
- Update the anchor and the replacement.
- Run a build with `-NoArchive` to validate quickly.

If an anchor cannot be matched, the script exits with code 2 and the payload is untouched — keep that behaviour.

## Pull requests

- Describe the problem, the change and how you verified it.
- Include the upstream version you tested against.
- Do not include build artifacts or personal data.
- By submitting a PR you agree your contribution is MIT licensed.

## Release process

Maintainers build locally with `scripts/build.ps1`, verify the artifact, then publish a release with the zip and
its `.sha256`. Tags matching `v*` also trigger the GitHub Actions release workflow.

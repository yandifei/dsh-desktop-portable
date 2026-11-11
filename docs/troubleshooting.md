# Troubleshooting

## The app does not start

- Check Windows is x64 and the drive is NTFS.
- Make sure the folder path is short and contains no exotic characters.
- Look at `@deepseek-ai\dsh-desktop\logs` and the Windows Event Viewer.
- Antivirus may quarantine a modified `app.asar`; add an exclusion only if you trust the build.

## The app starts but data appears on the system drive

- The portable paths are derived from `process.execPath`. Do not copy only the `.exe`; copy the whole folder.
- Existing data under `C:\Users\<user>\.dsh` is not used by the portable build; that is expected.
- Third-party plugins that hardcode `%APPDATA%` or absolute paths can still write outside the package.

## Updating fails with "patch failed"

Upstream changed the JavaScript layout. `Patch-Asar.js` exits before modifying the payload, so the current
version keeps working. Rebuild from source after updating the anchors in `scripts/patch-asar.js`, or report the
upstream version in an issue.

## Updating fails with "WinRAR or 7-Zip is required"

Install either tool. The updater extracts the official installer and never runs it, so it needs an extractor.

## Drive letter changed and the workspace is missing

DSH stores workspace paths as absolute paths. Re-add/select the workspace on the new drive letter; sessions stay
under `.dsh`. Use a fixed drive letter if you switch machines often.

## Login state lost after moving the drive

Cookies live in `@deepseek-ai\dsh-desktop`. Make sure you copy the whole folder while the app is closed, and do
not delete `Local State` (it holds the key used to encrypt cookies).

## Rolling back

Keep a copy of the previous package folder before updating, or rebuild the previous version with
`pwsh scripts/build.ps1 -Version <old-version>` and extract it over the package while keeping data directories.

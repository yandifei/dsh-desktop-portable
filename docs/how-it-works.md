# How the portable build works

This project keeps the **official** DeepSeek Harness Electron desktop payload and patches only
`resources/app.asar`. `app.asar` is an unencrypted archive (header JSON + concatenated files), so the
patch script rewrites it in place:

- packed files are copied in order with fresh offsets and fresh SHA-256 integrity blocks;
- files marked `unpacked` stay in `resources/app.asar.unpacked` and are referenced as before;
- only `lib/main.js` and two workspace-controller modules are changed.

The `.exe` and DLLs remain the official signed binaries. The Windows Authenticode signature covers the
executable, not `app.asar`, so the app still starts normally — but the UI code is modified, and the
project is therefore unofficial.

## Patches

### 1. Portable root and data paths (`lib/main.js`)

At module load, the app derives a root from `dirname(process.execPath)` and:

| Setting | Portable value |
| --- | --- |
| `DSH_HOME` | `<root>\.dsh` |
| `TEMP`, `TMP` | `<root>\@deepseek-aidsh-desktop-updater\temp` |
| `DSH_WE_DATA_DIR` | `<root>\.dsh\plugin-data\wallpaper-engine` |
| `DSH_WE_CACHE_DIR` | `<root>\@deepseek-aidsh-desktop-updater\wallpaper-engine-cache` |
| Electron `userData` / `sessionData` | `<root>\@deepseek-ai\dsh-desktop` |
| `defaultDshHome()` | `<root>\.dsh` |

`DSH_*` values use `??=` so an explicit environment override still wins.

### 2. Host process home (`desktopNodeEnvironment` call)

The Host (and therefore every plugin and agent subprocess) receives:

- `USERPROFILE` = `<root>\home`, so `os.homedir()` and `~` resolve to the drive;
- `LOCALAPPDATA` = `<root>\home\AppData\Local`, so pnpm state and similar caches stay portable;
- `HOME` = the real user profile, so git/ssh configs keep working.

### 3. First-use workspace

`@deepseek-ai/dsh-api-workspace-controller` contains two copies of the same logic
(`lib/index.js` inlined and `lib/types/default-directory.js` re-exported). Both are changed to:

```js
if (documentsDirectory === undefined) {
  const portableHome = process.env.DSH_HOME || paths.join(paths.dirname(process.execPath), '.dsh');
  return paths.join(portableHome, 'workspace', 'deepseek-harness', DEFAULT_WORKSPACE_DIRECTORY);
}
```

The default workspace is therefore created under `.dsh\workspace` instead of `Documents`.

### 4. Protocol registration

`app.setAsDefaultProtocolClient('dsh')` becomes opt-in:

```js
if (process.env.DSH_DESKTOP_REGISTER_PROTOCOL === '1') app.setAsDefaultProtocolClient('dsh');
```

Startup writes no registry keys by default. The trade-off: `dsh://open` deep links no longer focus the app.

### 5. Updates

The official updater is enabled only when `resources/app-update.yml` exists, so the build script renames it
to `app-update.yml.disabled`. The bundled `Update-Harness.ps1` replaces it with a portable flow that extracts
the official installer instead of running it.

## Data layout

| Path | Content |
| --- | --- |
| `.dsh\` | DSH_HOME: sessions, settings, credentials, plugins, runtime payload |
| `.dsh\profiles\desktop\node_modules` | plugins installed by the plugin manager |
| `.dsh\cache\pnpm-store`, `.dsh\cache\pnpm-cache` | pnpm store and metadata cache (configured relatively in the profile) |
| `.dsh\plugin-data\` | plugin data (wallpaper engine and similar) |
| `home\` | Host user home: `.agents`, `.bili-ai`, `.npmrc`, `AppData\Local` |
| `@deepseek-ai\dsh-desktop\` | Electron cookies/local storage/shortcuts/caches |
| `@deepseek-aidsh-desktop-updater\` | updater downloads, temp, wallpaper cache |

## Failure behaviour

Each patch anchor is asserted. If an upstream release changes the surrounding code, `Patch-Asar.js` exits with
code 2 before touching the payload. The build script then aborts; the updater also aborts and leaves the current
installation untouched.

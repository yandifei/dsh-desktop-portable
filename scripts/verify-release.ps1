# Verify a built portable package before publishing or using it.
#
# Usage:
#   pwsh scripts/verify-release.ps1 -Zip dist/DSH-Desktop-Portable-<version>-win-x64.zip
#
# Checks:
#   - SHA-256 against the sibling .sha256 file (when present)
#   - the required program files exist in the archive
#   - no personal runtime data is present at the archive root

param(
    [Parameter(Mandatory = $true)]
    [string]$Zip
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Zip)) { throw ('Zip not found: ' + $Zip) }
$Zip = (Resolve-Path $Zip).Path

Write-Host ('Package: ' + $Zip)
Write-Host ('Size:    ' + [math]::Round((Get-Item $Zip).Length / 1MB, 1) + ' MB')

$shaFile = $Zip + '.sha256'
if (Test-Path $shaFile) {
    $expected = ((Get-Content $shaFile -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLowerInvariant()
    Write-Host ('SHA256:  ' + $actual)
    if ($expected -ne $actual) { throw 'SHA-256 mismatch.' }
    Write-Host 'SHA-256 verified.'
} else {
    Write-Host 'No .sha256 file next to the zip; skipping checksum.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($Zip)
try {
    $names = @($archive.Entries | ForEach-Object { $_.FullName })

    $required = @(
        'DeepSeek Harness.exe',
        'resources/app.asar',
        'Patch-Asar.js',
        'Update-Harness.ps1',
        'Update-Harness.cmd',
        'README.md',
        'LICENSE'
    )
    foreach ($item in $required) {
        if ($names -notcontains $item) { throw ('Missing required file: ' + $item) }
    }
    Write-Host 'Required files present.'

    $forbiddenPrefixes = @('.dsh/', 'home/', '@deepseek-ai/dsh-desktop/', '@deepseek-aidsh-desktop-updater/')
    $forbiddenNames = @('.credentials.yaml', 'Cookies', 'bili-whale.config.json', 'dsh-runtimes', 'speech-to-text')
    $hits = @()
    foreach ($name in $names) {
        if ($forbiddenPrefixes | Where-Object { $name.StartsWith($_) }) { $hits += $name; continue }
        if ($forbiddenNames | Where-Object { $name -eq $_ -or $name.StartsWith($_) }) { $hits += $name }
    }
    if ($hits.Count -gt 0) {
        $hits | Select-Object -First 20 | ForEach-Object { Write-Host ('  suspicious: ' + $_) }
        throw 'The archive contains personal/runtime data and must not be published.'
    }
    Write-Host 'No personal runtime data found.'

    # --- the asar must actually be loadable -------------------------------------------------
    # A shifted data section rewrites every file by a few bytes but keeps the offsets and
    # integrity blocks self-consistent, so a damaged archive still looks "complete". The
    # only reliable check is to parse the root manifest and look for the patch markers.
    $asarEntry = $archive.GetEntry('resources/app.asar')
    $tempAsar = Join-Path ([IO.Path]::GetTempPath()) ('verify-asar-' + [guid]::NewGuid().ToString('N') + '.asar')
    [IO.Compression.ZipFileExtensions]::ExtractToFile($asarEntry, $tempAsar, $true)
    try {
        $stream = [IO.File]::OpenRead($tempAsar)
        try {
            $fileLength = $stream.Length
            $head = New-Object byte[] 16
            $null = $stream.Read($head, 0, 16)
            $headerSize = [BitConverter]::ToUInt32($head, 4)
            $jsonLength = [BitConverter]::ToUInt32($head, 12)
            $dataBase = 8 + $headerSize
            if ($dataBase + 1 -ge $fileLength) { throw 'asar header looks truncated.' }

            $jsonBytes = New-Object byte[] $jsonLength
            $stream.Position = 16
            $read = 0
            while ($read -lt $jsonLength) {
                $chunk = $stream.Read($jsonBytes, $read, $jsonLength - $read)
                if ($chunk -le 0) { break }
                $read += $chunk
            }
            $asar = ([Text.Encoding]::UTF8.GetString($jsonBytes, 0, $read).TrimEnd([char]0)) | ConvertFrom-Json

            $readEntry = {
                param($node)
                $offset = $dataBase + [long]$node.offset
                if ($offset + [long]$node.size -gt $fileLength) {
                    throw ('asar entry out of bounds: ' + $offset + ' + ' + $node.size)
                }
                $buffer = New-Object byte[] ([long]$node.size)
                $stream.Position = $offset
                $got = 0
                while ($got -lt $buffer.Length) {
                    $chunk = $stream.Read($buffer, $got, $buffer.Length - $got)
                    if ($chunk -le 0) { break }
                    $got += $chunk
                }
                return $buffer
            }

            $resolveNode = {
                param([string]$path)
                $current = $asar
                foreach ($part in $path.Split('/')) {
                    $current = $current.files.$part
                    if ($null -eq $current) { throw ('asar is missing ' + $path) }
                }
                return $current
            }

            $packageNode = & $resolveNode 'package.json'
            $packageText = [Text.Encoding]::UTF8.GetString((& $readEntry $packageNode))
            try {
                $manifest = $packageText | ConvertFrom-Json
            } catch {
                $preview = $packageText.Substring(0, [Math]::Min(60, $packageText.Length))
                throw ('root package.json is not valid JSON (starts with: ' + $preview + ')')
            }
            if ($manifest.name -ne '@deepseek-ai/dsh-desktop') {
                throw ('unexpected root package name: ' + $manifest.name)
            }
            Write-Host ('asar root manifest: ' + $manifest.name + ' ' + $manifest.version)

            $markers = @(
                @{ Path = 'lib/main.js'; Text = '__dshPortableRoot' },
                @{ Path = 'dsh/node_modules/@deepseek-ai/dsh-api-workspace-controller/lib/types/default-directory.js'; Text = 'portableHome' },
                @{ Path = 'dsh/node_modules/@deepseek-ai/dsh-api-workspace-controller/lib/index.js'; Text = 'portableHome' }
            )
            foreach ($marker in $markers) {
                $bytes = & $readEntry (& $resolveNode $marker.Path)
                if (-not [Text.Encoding]::UTF8.GetString($bytes).Contains($marker.Text)) {
                    throw ('portable patch missing from ' + $marker.Path)
                }
            }
            Write-Host 'Portable patches present in the asar.'
        } finally {
            $stream.Dispose()
        }
    } finally {
        Remove-Item $tempAsar -Force -ErrorAction SilentlyContinue
    }
} finally {
    $archive.Dispose()
}

Write-Host ''
Write-Host 'Package verification passed.' -ForegroundColor Green

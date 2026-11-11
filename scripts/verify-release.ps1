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
} finally {
    $archive.Dispose()
}

Write-Host ''
Write-Host 'Package verification passed.' -ForegroundColor Green

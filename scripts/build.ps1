# Build a portable DeepSeek Harness package for Windows x64.
#
# Usage:
#   pwsh scripts/build.ps1                 # latest version from the official nightly feed
#   pwsh scripts/build.ps1 -Version 0.2.2-rc.1
#
# The script downloads the official installer, verifies SHA-512 and Authenticode,
# extracts it without running it, applies the portable patches, and writes a zip
# plus a SHA-256 file under dist/.

param(
    [string]$Version = 'latest',
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\dist'),
    [string]$Extractor = '',
    [switch]$NoArchive,
    [switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$feedUrl = 'https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml'
$downloadBase = 'https://download.deepseek.com/dsh-desk/bin/win-x64'
$tempRoot = Join-Path $env:TEMP ('dsh-portable-build-' + [guid]::NewGuid().ToString('N'))

function Write-Step([string]$message) {
    Write-Host ''
    Write-Host ('==> ' + $message) -ForegroundColor Cyan
}

function Find-Extractor {
    if ($Extractor) {
        if (-not (Test-Path $Extractor)) { throw ('Extractor not found: ' + $Extractor) }
        return $Extractor
    }
    $onPath = Get-Command '7z.exe', 'WinRAR.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    $candidates = @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe'),
        (Join-Path $env:ProgramFiles 'WinRAR\WinRAR.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'WinRAR\WinRAR.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    throw '7-Zip or WinRAR is required to extract the official installer.'
}

function Expand-InstallerPayload([string]$extractor, [string]$installer, [string]$destination) {
    if ($extractor -like '*WinRAR*') {
        & $extractor x -y -ibck $installer ($destination + '\') | Out-Null
    } else {
        & $extractor x -y $installer ('-o' + $destination) | Out-Null
    }
    Start-Sleep -Seconds 2
    if (Test-Path (Join-Path $destination 'DeepSeek Harness.exe')) { return }

    # electron-builder NSIS stores the real payload in $PLUGINSDIR/app-64.7z.
    # WinRAR usually expands it directly; 7-Zip needs a second pass.
    $nested = Get-ChildItem $destination -Recurse -Force -Filter 'app-*.7z' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $nested) { return }
    Write-Host ('Extracting nested payload: ' + $nested.Name)
    if ($extractor -like '*WinRAR*') {
        & $extractor x -y -ibck $nested.FullName ($destination + '\') | Out-Null
    } else {
        & $extractor x -y $nested.FullName ('-o' + $destination) | Out-Null
    }
    Start-Sleep -Seconds 2
}

function Get-Feed([string]$url) {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60
    $text = if ($response.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($response.Content) } else { [string]$response.Content }
    $published = [regex]::Match($text, '(?m)^version:\s*(\S+)').Groups[1].Value
    $fileUrl = [regex]::Match($text, 'path:\s*>-\s*[\r\n]+\s*(\S+)').Groups[1].Value
    $sha512 = [regex]::Match($text, 'sha512:\s*>-\s*[\r\n]+\s*(\S+)').Groups[1].Value
    if (-not $published -or -not $fileUrl -or -not $sha512) {
        throw 'The official feed format was not recognized.'
    }
    return [pscustomobject]@{ Version = $published; Url = $fileUrl; Sha512 = $sha512 }
}

try {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    Write-Step 'Resolving the official release'
    if ($Version -eq 'latest') {
        $release = Get-Feed $feedUrl
    } else {
        $release = [pscustomobject]@{
            Version  = $Version
            Url      = ($downloadBase + '/deepseek-harness-' + $Version + '-win-x64.exe')
            Sha512   = $null
        }
    }
    Write-Host ('Version: ' + $release.Version)

    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $installer = Join-Path $tempRoot 'setup.exe'

    Write-Step 'Downloading the official installer'
    Invoke-WebRequest -Uri $release.Url -OutFile $installer -UseBasicParsing -TimeoutSec 3600
    Write-Host ('Downloaded: ' + [math]::Round((Get-Item $installer).Length / 1MB, 1) + ' MB')

    Write-Step 'Verifying signature and checksum'
    $signature = Get-AuthenticodeSignature $installer
    if ($signature.Status -ne 'Valid') { throw ('Invalid Authenticode signature: ' + $signature.Status) }
    Write-Host ('Publisher: ' + $signature.SignerCertificate.Subject)
    if ($release.Sha512) {
        $hashBytes = [Security.Cryptography.SHA512]::Create().ComputeHash([IO.File]::ReadAllBytes($installer))
        $actual = [Convert]::ToBase64String($hashBytes)
        if ($actual -ne $release.Sha512) { throw 'SHA-512 mismatch for the downloaded installer.' }
        Write-Host 'SHA-512 verified.'
    } else {
        Write-Host 'Checksum not published for this version; signature only.'
    }

    Write-Step 'Extracting the installer (no installation)'
    $extractor = Find-Extractor
    $payload = Join-Path $tempRoot 'payload'
    New-Item -ItemType Directory -Force -Path $payload | Out-Null
    Expand-InstallerPayload $extractor $installer $payload
    if (-not (Test-Path (Join-Path $payload 'DeepSeek Harness.exe'))) { throw 'Extraction failed: executable not found.' }

    Write-Step 'Applying portable patches'
    $node = Join-Path $payload 'resources\runtime\primary-runtime\dependencies\node\bin\node.exe'
    if (-not (Test-Path $node)) { throw 'Bundled Node runtime not found in the extracted payload.' }
    & $node (Join-Path $PSScriptRoot 'patch-asar.js') $payload
    if ($LASTEXITCODE -ne 0) { throw 'Patch script failed; the payload was not modified.' }

    Write-Step 'Disabling the official auto-updater'
    $updateYml = Join-Path $payload 'resources\app-update.yml'
    if (Test-Path $updateYml) { Rename-Item $updateYml 'app-update.yml.disabled' -Force }
    $staleBackup = Join-Path $payload 'resources\app.asar.orig'
    if (Test-Path $staleBackup) { Remove-Item $staleBackup -Force }

    if ($NoArchive) {
        Write-Step 'Check-only build: patches applied successfully; skipping archive'
        return
    }

    Write-Step 'Assembling the portable package'
    Copy-Item (Join-Path $repoRoot 'README.md') $payload -Force
    Copy-Item (Join-Path $repoRoot 'LICENSE') $payload -Force
    Copy-Item (Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md') $payload -Force
    Copy-Item (Join-Path $repoRoot 'SECURITY.md') $payload -Force
    Copy-Item (Join-Path $repoRoot 'docs') $payload -Recurse -Force
    Copy-Item (Join-Path $repoRoot 'scripts\patch-asar.js') (Join-Path $payload 'Patch-Asar.js') -Force
    Copy-Item (Join-Path $repoRoot 'portable\Update-Harness.ps1') $payload -Force
    Copy-Item (Join-Path $repoRoot 'portable\Update-Harness.cmd') $payload -Force

    Write-Step 'Creating the zip archive'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipName = 'DSH-Desktop-Portable-' + $release.Version + '-win-x64.zip'
    $zipPath = Join-Path $OutputDir $zipName
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    [IO.Compression.ZipFile]::CreateFromDirectory($payload, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
    Write-Host ('Zip: ' + $zipPath + ' (' + [math]::Round((Get-Item $zipPath).Length / 1GB, 2) + ' GB)')

    Write-Step 'Writing checksum'
    $hash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
    $hashFile = $zipPath + '.sha256'
    Set-Content -LiteralPath $hashFile -Value ($hash + '  ' + $zipName) -Encoding ASCII
    Write-Host ('SHA-256: ' + $hash)
    Write-Host ''
    Write-Host 'Build complete.' -ForegroundColor Green
} finally {
    if (-not $KeepTemp -and (Test-Path $tempRoot)) {
        Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

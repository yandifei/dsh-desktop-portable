param([switch]$NoPause)
# Portable updater for DSH Desktop Portable.
# Downloads the official installer, verifies it, extracts it, re-applies the
# portable patches and replaces program files while keeping user data.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $root 'DeepSeek Harness.exe'
$cache = Join-Path $root '@deepseek-aidsh-desktop-updater'
$feed = 'https://download.deepseek.com/dsh-desk/feeds/win-x64/nightly.yml'

function Pause-Exit([int]$code) {
    if (-not $NoPause) {
        Write-Host ''
        Read-Host 'Press Enter to exit'
    }
    exit $code
}

function ConvertTo-VersionParts([string]$text) {
    $clean = ($text.Trim() -replace '^[vV]', '')
    $segments = $clean -split '-', 2
    $core = @()
    foreach ($piece in ($segments[0] -split '\.')) {
        $number = 0
        [void][int]::TryParse(($piece -replace '[^0-9]', ''), [ref]$number)
        $core += $number
    }
    $pre = @()
    if ($segments.Count -gt 1 -and $segments[1]) { $pre = $segments[1] -split '\.' }
    return [pscustomobject]@{ Core = $core; Pre = $pre }
}

# Compares two versions the way the release feed orders them: 1 when $left is newer,
# 0 when equal, -1 when older. Semver ordering, so 0.2.2-rc.2 > 0.2.2-rc.1 and
# a release is newer than any of its prereleases.
function Compare-DshVersion([string]$left, [string]$right) {
    $a = ConvertTo-VersionParts $left
    $b = ConvertTo-VersionParts $right
    $count = [Math]::Max($a.Core.Count, $b.Core.Count)
    for ($i = 0; $i -lt $count; $i++) {
        $x = if ($i -lt $a.Core.Count) { $a.Core[$i] } else { 0 }
        $y = if ($i -lt $b.Core.Count) { $b.Core[$i] } else { 0 }
        if ($x -ne $y) { return [Math]::Sign($x - $y) }
    }
    if ($a.Pre.Count -eq 0 -and $b.Pre.Count -eq 0) { return 0 }
    if ($a.Pre.Count -eq 0) { return 1 }
    if ($b.Pre.Count -eq 0) { return -1 }
    $count = [Math]::Max($a.Pre.Count, $b.Pre.Count)
    for ($i = 0; $i -lt $count; $i++) {
        if ($i -ge $a.Pre.Count) { return -1 }
        if ($i -ge $b.Pre.Count) { return 1 }
        $x = $a.Pre[$i]
        $y = $b.Pre[$i]
        $xn = 0
        $yn = 0
        $xIsNumber = [int]::TryParse($x, [ref]$xn)
        $yIsNumber = [int]::TryParse($y, [ref]$yn)
        if ($xIsNumber -and $yIsNumber) {
            if ($xn -ne $yn) { return [Math]::Sign($xn - $yn) }
        } elseif ($xIsNumber) {
            return -1
        } elseif ($yIsNumber) {
            return 1
        } else {
            $comparison = [string]::CompareOrdinal($x, $y)
            if ($comparison -ne 0) { return [Math]::Sign($comparison) }
        }
    }
    return 0
}

function Expand-InstallerPayload([string]$extractor, [string]$installer, [string]$destination) {
    if ($extractor -like '*WinRAR*') {
        & $extractor x -y -ibck $installer ($destination + '\') | Out-Null
    } else {
        & $extractor x -y $installer ('-o' + $destination) | Out-Null
    }
    Start-Sleep -Seconds 2
    if (Test-Path (Join-Path $destination 'DeepSeek Harness.exe')) { return }
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

function Find-Extractor {
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
    return $null
}

try {
    Write-Host '=== DeepSeek Harness portable updater ==='

    $running = Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) }
    if ($running) {
        Write-Host 'Please quit DeepSeek Harness completely (tray -> Quit) before updating.'
        Pause-Exit 1
    }

    Write-Host 'Reading the official update feed...'
    $response = Invoke-WebRequest -Uri $feed -UseBasicParsing -TimeoutSec 30
    $yml = if ($response.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($response.Content) } else { [string]$response.Content }
    $version = [regex]::Match($yml, '(?m)^version:\s*(\S+)').Groups[1].Value
    $url = [regex]::Match($yml, 'path:\s*>-\s*[\r\n]+\s*(\S+)').Groups[1].Value
    $sha = [regex]::Match($yml, 'sha512:\s*>-\s*[\r\n]+\s*(\S+)').Groups[1].Value
    if (-not $version -or -not $url -or -not $sha) { throw 'The update feed format was not recognized.' }

    $current = ''
    $runtimeJson = Join-Path $root 'resources\runtime\primary-runtime\runtime.json'
    if (Test-Path $runtimeJson) {
        try { $current = [string](Get-Content $runtimeJson -Raw | ConvertFrom-Json).desktopVersion } catch { }
    }

    Write-Host ('Current version: {0}    Official version: {1}' -f $current, $version)
    if ($current) {
        $order = Compare-DshVersion $current $version
        if ($order -eq 0) {
            Write-Host 'Already up to date.'
            Pause-Exit 0
        }
        if ($order -gt 0) {
            Write-Host ('This package ({0}) is newer than the official feed ({1}); nothing to do.' -f $current, $version)
            Write-Host 'Waiting for the official feed to catch up avoids downgrading.'
            Pause-Exit 0
        }
    }

    $extractor = Find-Extractor
    if (-not $extractor) { throw 'WinRAR or 7-Zip is required to extract the official installer.' }

    $downloadDir = Join-Path $cache 'download'
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    $setup = Join-Path $downloadDir ('deepseek-harness-{0}-setup.exe' -f $version)

    Write-Host ('Downloading ' + $url)
    Invoke-WebRequest -Uri $url -OutFile $setup -UseBasicParsing -TimeoutSec 3600

    Write-Host 'Verifying SHA-512...'
    $bytes = [IO.File]::ReadAllBytes($setup)
    $actual = [Convert]::ToBase64String([Security.Cryptography.SHA512]::Create().ComputeHash($bytes))
    if ($actual -ne $sha) {
        Remove-Item $setup -Force
        throw 'SHA-512 mismatch; the download was removed.'
    }

    Write-Host 'Verifying Authenticode signature...'
    $signature = Get-AuthenticodeSignature $setup
    if ($signature.Status -ne 'Valid') { throw ('Invalid signature: ' + $signature.Status) }
    Write-Host ('Publisher: ' + $signature.SignerCertificate.Subject)

    $staging = Join-Path $cache 'staging'
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $staging | Out-Null

    Write-Host 'Extracting the official installer (no installation, no registry writes)...'
    Expand-InstallerPayload $extractor $setup $staging
    if (-not (Test-Path (Join-Path $staging 'DeepSeek Harness.exe'))) { throw 'Extraction failed: executable not found.' }

    # Drop the NSIS outer layer's staging directory so it is not copied into the package.
    $nsisLeftovers = Join-Path $staging '$PLUGINSDIR'
    if (Test-Path $nsisLeftovers) { Remove-Item $nsisLeftovers -Recurse -Force }

    Write-Host 'Re-applying portable patches...'
    $node = Join-Path $root 'resources\runtime\primary-runtime\dependencies\node\bin\node.exe'
    if (-not (Test-Path $node)) { throw 'Bundled Node runtime not found; cannot patch the new version.' }
    & $node (Join-Path $root 'Patch-Asar.js') $staging
    if ($LASTEXITCODE -ne 0) { throw 'Patch failed (upstream code layout changed). The current version was not modified.' }

    Write-Host 'Replacing program files (data directories are preserved)...'
    $keep = @('.dsh', 'home', '@deepseek-ai', '@deepseek-aidsh-desktop-updater')
    $keepFiles = @('Update-Harness.cmd', 'Update-Harness.ps1', 'Patch-Asar.js', 'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'SECURITY.md')
    Get-ChildItem $staging -Force |
        Where-Object { $keep -notcontains $_.Name -and $keepFiles -notcontains $_.Name } |
        ForEach-Object { Copy-Item $_.FullName -Destination $root -Recurse -Force }

    $updateYml = Join-Path $root 'resources\app-update.yml'
    $disabledYml = Join-Path $root 'resources\app-update.yml.disabled'
    if (Test-Path $disabledYml) { Remove-Item $disabledYml -Force }
    if (Test-Path $updateYml) { Rename-Item $updateYml 'app-update.yml.disabled' -Force }
    $staleBackup = Join-Path $root 'resources\app.asar.orig'
    if (Test-Path $staleBackup) { Remove-Item $staleBackup -Force }
    Remove-Item $staging -Recurse -Force

    Write-Host ''
    Write-Host ('Updated to ' + $version + '; starting...')
    Start-Process -FilePath $exe
    Start-Sleep -Seconds 2
    Pause-Exit 0
} catch {
    Write-Host ''
    Write-Host ('Update failed: ' + $_.Exception.Message) -ForegroundColor Red
    Pause-Exit 1
}

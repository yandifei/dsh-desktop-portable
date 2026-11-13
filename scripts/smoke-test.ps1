# 便携包启动自检：解压 → 启动 → 检查数据目录是否真的落在 exe 同级 → 退出。
#
# 用法：
#   pwsh scripts/smoke-test.ps1 -Zip dist/DSH-Desktop-Portable-0.2.2-rc.2-win-x64.zip
#
# 注意：必须先完全退出 DeepSeek Harness（托盘 → Quit）。Electron 的单实例机制会让
# 第二份拷贝在加载 app.asar 之前就直接退出（退出码 0，且不产生任何目录），
# 那种情况本脚本会判定为“环境冲突”，而不是包有问题。

param(
    [Parameter(Mandatory = $true)]
    [string]$Zip,
    [int]$TimeoutSeconds = 40
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Zip)) { throw ('找不到压缩包：' + $Zip) }
$Zip = (Resolve-Path $Zip).Path

$running = @(Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    Write-Host ('检测到 ' + $running.Count + ' 个 DeepSeek Harness 进程仍在运行。') -ForegroundColor Yellow
    $running | Select-Object -First 5 Id, Path | Format-Table -AutoSize
    Write-Host '请先从托盘 Quit 完全退出，再运行本脚本；否则新拷贝会在加载 app.asar 之前直接退出。' -ForegroundColor Yellow
    Write-Host '（这种情况不代表包有问题。）'
    exit 2
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$dir = Join-Path ([IO.Path]::GetTempPath()) ('dsh-smoke-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host ('解压到：' + $dir)
[IO.Compression.ZipFile]::ExtractToDirectory($Zip, $dir)

$exe = Join-Path $dir 'DeepSeek Harness.exe'
if (-not (Test-Path $exe)) { throw '压缩包里没有 DeepSeek Harness.exe' }

$dshHome = Join-Path $dir '.dsh'
$portableHome = Join-Path $dir 'home'
$tempDir = Join-Path $dir '@deepseek-aidsh-desktop-updater'

Write-Host ('启动：' + $exe)
$process = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$ready = $false
while ((Get-Date) -lt $deadline) {
    if (Test-Path $dshHome) { $ready = $true; break }
    if ($process.HasExited) { break }
    Start-Sleep -Milliseconds 500
}

$alive = -not $process.HasExited
$created = [pscustomobject]@{
    '.dsh'                               = Test-Path $dshHome
    'home'                               = Test-Path $portableHome
    '@deepseek-aidsh-desktop-updater'    = Test-Path $tempDir
}

Write-Host ''
Write-Host ('进程存活：' + $alive)
$created.PSObject.Properties | ForEach-Object {
    Write-Host ('  ' + $_.Name + '：' + $_.Value)
}

if ($alive) {
    if (-not $process.HasExited) { $process.CloseMainWindow() | Out-Null; Start-Sleep -Seconds 3 }
    Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like ($dir + '*') } | Stop-Process -Force
}

Write-Host ''
if ($ready -and $created.home) {
    Write-Host '结论：启动正常，可写数据落在 exe 同级目录。' -ForegroundColor Green
    Write-Host ('解压目录保留在：' + $dir + '（可手动删除）')
    exit 0
}

Write-Host '结论：没有观察到便携目录生成，应用没有完成启动。' -ForegroundColor Red
if ($process.HasExited) { Write-Host ('  退出码：' + $process.ExitCode) }
Write-Host ('  解压目录：' + $dir)
Write-Host '  如果确认没有任何 DSH 实例在运行，请带上这个结果提 issue。'
exit 1

param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\sanjiaozhou_luzhi"),
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN"
)

$ErrorActionPreference = "Stop"

$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = [Environment]::ExpandEnvironmentVariables($InstallDir)

if (-not (Test-Path (Join-Path $sourceRoot "sanjiaozhou_luzhi.ps1"))) {
    throw "Installer must be run from the extracted sanjiaozhou_luzhi package."
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

$items = @(
    "assets",
    "pets",
    "tools",
    "sanjiaozhou_luzhi.ps1",
    "sanjiaozhou_luzhi_run.vbs",
    "sanjiaozhou_luzhi_run.cmd",
    "sanjiaozhou_luzhi_launcher.ps1",
    "sanjiaozhou_luzhi_launcher.cmd",
    "sanjiaozhou_luzhi_shortcut.ps1",
    "sanjiaozhou_luzhi_shortcut.cmd",
    "Uninstall.ps1",
    "Uninstall.cmd",
    "README.md",
    "NOTICE.md"
)

foreach ($item in $items) {
    $src = Join-Path $sourceRoot $item
    if (-not (Test-Path $src)) {
        continue
    }
    $dst = Join-Path $installDir $item
    if ((Get-Item $src).PSIsContainer) {
        if (Test-Path $dst) {
            Remove-Item -LiteralPath $dst -Recurse -Force
        }
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    } else {
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installDir "sanjiaozhou_luzhi_shortcut.ps1") -Action Install -Target Both -Language $Language

Write-Host "Installed to: $installDir"
Write-Host "Launch from the Desktop or Start Menu shortcut."

param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\HatchReplayPet"),
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN"
)

$ErrorActionPreference = "Stop"

$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = [Environment]::ExpandEnvironmentVariables($InstallDir)

if (-not (Test-Path (Join-Path $sourceRoot "SimpleReplayController.ps1"))) {
    throw "Installer must be run from the extracted Hatch Replay Pet package."
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

$items = @(
    "assets",
    "pets",
    "tools",
    "SimpleReplayController.ps1",
    "Run-SimpleReplayController.vbs",
    "Run-SimpleReplayController.cmd",
    "QuickLaunch.ps1",
    "QuickLaunch.cmd",
    "Install-QuickLaunch.ps1",
    "Install-QuickLaunch.cmd",
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

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installDir "Install-QuickLaunch.ps1") -Action Install -Target Both -Language $Language

Write-Host "Installed to: $installDir"
Write-Host "Launch from the Desktop or Start Menu shortcut."

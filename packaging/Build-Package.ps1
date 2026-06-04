param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$buildRoot = Join-Path $projectRoot "build"
$distRoot = Join-Path $projectRoot "dist"
$packageName = "sanjiaozhou_luzhi-$Version"
$packageRoot = Join-Path $buildRoot $packageName
$zipPath = Join-Path $distRoot "$packageName.zip"

if (Test-Path $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

$items = @(
    "assets\sanjiaozhou_luzhi.ico",
    "assets\sanjiaozhou_luzhi_icon.png",
    "pets\hatch-default\pet.json",
    "pets\hatch-default\spritesheet.webp",
    "tools\ffmpeg\ffmpeg.exe",
    "tools\ffmpeg\ffprobe.exe",
    "sanjiaozhou_luzhi.ps1",
    "sanjiaozhou_luzhi_run.vbs",
    "sanjiaozhou_luzhi_run.cmd",
    "sanjiaozhou_luzhi_launcher.ps1",
    "sanjiaozhou_luzhi_launcher.cmd",
    "sanjiaozhou_luzhi_shortcut.ps1",
    "sanjiaozhou_luzhi_shortcut.cmd",
    "README.md",
    "NOTICE.md"
)

foreach ($item in $items) {
    $src = Join-Path $projectRoot $item
    if (-not (Test-Path $src)) {
        throw "Missing package item: $item"
    }
    $dst = Join-Path $packageRoot $item
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

foreach ($item in @("Install.cmd", "Install.ps1", "Uninstall.cmd", "Uninstall.ps1")) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "packaging\$item") -Destination (Join-Path $packageRoot $item) -Force
}

if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -Force
Write-Host "Package root: $packageRoot"
Write-Host "Package zip: $zipPath"

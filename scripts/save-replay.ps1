param(
    [int]$MaxSegments = 17
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$localFfmpeg = Join-Path $projectRoot "tools\ffmpeg\ffmpeg.exe"

if (Test-Path $localFfmpeg) {
    $ffmpeg = $localFfmpeg
} else {
    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Write-Host "FFmpeg was not found." -ForegroundColor Red
        Write-Host "Install FFmpeg and add it to PATH, or place ffmpeg.exe at tools\ffmpeg\ffmpeg.exe."
        exit 1
    }
    $ffmpeg = $cmd.Source
}

$cacheDir = Join-Path $env:LOCALAPPDATA "sanjiaozhou_luzhi\cache"
$outputDir = Join-Path $env:USERPROFILE "Videos\sanjiaozhou_luzhi"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

if (-not (Test-Path $cacheDir)) {
    Write-Host "Cache directory does not exist: $cacheDir" -ForegroundColor Red
    exit 1
}

$segments = Get-ChildItem -Path $cacheDir -Filter "cache_*.ts" |
    Sort-Object LastWriteTime |
    Select-Object -Last $MaxSegments

if ($segments.Count -eq 0) {
    Write-Host "No cache segments found." -ForegroundColor Red
    exit 1
}

$listPath = Join-Path $cacheDir "concat-list.txt"
$segments | ForEach-Object {
    $safePath = $_.FullName.Replace("'", "''")
    "file '$safePath'"
} | Set-Content -Encoding ASCII -Path $listPath

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputPath = Join-Path $outputDir "Replay_$timestamp.mp4"

Write-Host "Saving replay to: $outputPath"

& $ffmpeg `
    -hide_banner `
    -y `
    -f concat `
    -safe 0 `
    -i $listPath `
    -c copy `
    $outputPath

if (Test-Path $outputPath) {
    Write-Host "Replay saved: $outputPath" -ForegroundColor Green
} else {
    Write-Host "Replay save failed." -ForegroundColor Red
    exit 1
}

param(
    [int]$FrameRate = 60,
    [string]$VideoBitrate = "20M",
    [int]$SegmentSeconds = 4,
    [int]$SegmentCount = 17,
    [string]$Encoder = "h264_nvenc",
    [int]$DurationSeconds = 0
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
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

$outputPattern = Join-Path $cacheDir "cache_%03d.ts"
$keyframeInterval = $FrameRate * 2
$durationArgs = @()

if ($DurationSeconds -gt 0) {
    $durationArgs = @("-t", $DurationSeconds)
}

Write-Host "Starting replay cache recording..."
Write-Host "Cache directory: $cacheDir"
if ($DurationSeconds -gt 0) {
    Write-Host "Duration: $DurationSeconds seconds"
} else {
    Write-Host "Press Ctrl+C to stop."
}

& $ffmpeg `
    -hide_banner `
    -y `
    -f gdigrab `
    -framerate $FrameRate `
    -i desktop `
    @durationArgs `
    -c:v $Encoder `
    -preset p5 `
    -rc vbr `
    -b:v $VideoBitrate `
    -g $keyframeInterval `
    -an `
    -f segment `
    -segment_time $SegmentSeconds `
    -segment_wrap $SegmentCount `
    -reset_timestamps 1 `
    $outputPattern

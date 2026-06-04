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

Write-Host "Using FFmpeg: $ffmpeg"

$encoders = & $ffmpeg -hide_banner -encoders 2>&1
$nvencLines = $encoders | Select-String -Pattern "nvenc"

if ($null -eq $nvencLines) {
    Write-Host "No NVENC encoder was found in this FFmpeg build." -ForegroundColor Red
    exit 1
}

Write-Host "Detected NVENC encoders:" -ForegroundColor Green
$nvencLines | ForEach-Object { Write-Host $_.Line }

if (($nvencLines | Select-String -Pattern "h264_nvenc").Count -eq 0) {
    Write-Host "h264_nvenc is required for the MVP, but it was not found." -ForegroundColor Red
    exit 1
}

Write-Host "h264_nvenc is available. Step 1 can continue." -ForegroundColor Green

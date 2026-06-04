param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\sanjiaozhou_luzhi"),
    [switch]$NoSelfDeleteDelay
)

$ErrorActionPreference = "Stop"

$installDir = [Environment]::ExpandEnvironmentVariables($InstallDir)
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "sanjiaozhou_luzhi.lnk"
$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "sanjiaozhou_luzhi"

if (Test-Path $desktopShortcut) {
    Remove-Item -LiteralPath $desktopShortcut -Force
}

if (Test-Path $startMenuDir) {
    Remove-Item -LiteralPath $startMenuDir -Recurse -Force
}

if (Test-Path $installDir) {
    $currentScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ((Resolve-Path $currentScriptDir).Path -eq (Resolve-Path $installDir).Path -and -not $NoSelfDeleteDelay) {
        $cleanup = Join-Path $env:TEMP ("sanjiaozhou_luzhi_uninstall_" + [guid]::NewGuid().ToString("N") + ".cmd")
        $lines = @(
            "@echo off",
            "timeout /t 2 /nobreak >nul",
            "rmdir /s /q `"$installDir`"",
            "del /q `"%~f0`""
        )
        Set-Content -Path $cleanup -Value $lines -Encoding ASCII
        Start-Process -FilePath $cleanup -WindowStyle Hidden
    } else {
        Remove-Item -LiteralPath $installDir -Recurse -Force
    }
}

Write-Host "Removed sanjiaozhou_luzhi shortcuts and install directory."

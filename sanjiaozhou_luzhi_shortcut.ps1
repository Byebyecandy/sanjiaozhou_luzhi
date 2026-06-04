param(
    [ValidateSet("Install", "Uninstall", "Launch", "Test", "OpenInstallFolder")]
    [string]$Action = "Install",
    [ValidateSet("Desktop", "StartMenu", "Both")]
    [string]$Target = "Both",
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN",
    [string]$Name = "sanjiaozhou_luzhi",
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $projectRoot "sanjiaozhou_luzhi_run.vbs"
$controller = Join-Path $projectRoot "sanjiaozhou_luzhi.ps1"
$icon = Join-Path $projectRoot "assets\sanjiaozhou_luzhi.ico"
$startMenuFolderName = "sanjiaozhou_luzhi"

function Write-Info {
    param([string]$Message)

    if (-not $Quiet) {
        Write-Host $Message
    }
}

function Assert-LaunchFiles {
    if (-not (Test-Path $launcher)) {
        throw "Launcher not found: $launcher"
    }
    if (-not (Test-Path $controller)) {
        throw "Controller not found: $controller"
    }
    if (-not (Test-Path $icon)) {
        throw "Icon not found: $icon"
    }
}

function Join-ProcessArguments {
    param([object[]]$Items)

    $quoted = foreach ($item in $Items) {
        $value = [string]$item
        if ($value -match '[\s"]') {
            '"' + ($value -replace '"', '\"') + '"'
        } else {
            $value
        }
    }

    return ($quoted -join " ")
}

function Get-ShortcutPaths {
    param(
        [ValidateSet("Desktop", "StartMenu", "Both")]
        [string]$ShortcutTarget
    )

    $paths = @()

    if ($ShortcutTarget -eq "Desktop" -or $ShortcutTarget -eq "Both") {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $paths += [pscustomobject]@{
            Path = Join-Path $desktop "$Name.lnk"
            Kind = "Desktop"
        }
    }

    if ($ShortcutTarget -eq "StartMenu" -or $ShortcutTarget -eq "Both") {
        $programs = [Environment]::GetFolderPath("Programs")
        $startMenuDir = Join-Path $programs $startMenuFolderName
        $paths += [pscustomobject]@{
            Path = Join-Path $startMenuDir "$Name.lnk"
            Kind = "StartMenu"
        }
    }

    return $paths
}

function New-QuickShortcut {
    param([string]$ShortcutPath)

    $shortcutDir = Split-Path -Parent $ShortcutPath
    New-Item -ItemType Directory -Force -Path $shortcutDir | Out-Null

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $shortcut.Arguments = Join-ProcessArguments @($launcher, "-Language", $Language)
    $shortcut.WorkingDirectory = $projectRoot
    $shortcut.IconLocation = "$icon,0"
    $shortcut.Description = "Launch sanjiaozhou_luzhi without a console window."
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}

function Install-QuickShortcuts {
    Assert-LaunchFiles

    $created = @()
    foreach ($shortcut in Get-ShortcutPaths $Target) {
        New-QuickShortcut $shortcut.Path
        $created += $shortcut.Path
    }

    Write-Info "Quick launch shortcut(s) created:"
    foreach ($path in $created) {
        Write-Info " - $path"
    }
}

function Uninstall-QuickShortcuts {
    $removed = @()

    foreach ($shortcut in Get-ShortcutPaths $Target) {
        if (Test-Path $shortcut.Path) {
            Remove-Item -LiteralPath $shortcut.Path -Force
            $removed += $shortcut.Path
        }
    }

    $programs = [Environment]::GetFolderPath("Programs")
    $startMenuDir = Join-Path $programs $startMenuFolderName
    if (Test-Path $startMenuDir) {
        $remaining = @(Get-ChildItem -LiteralPath $startMenuDir -Force -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) {
            Remove-Item -LiteralPath $startMenuDir -Force
        }
    }

    if ($removed.Count -eq 0) {
        Write-Info "No quick launch shortcut was found for target: $Target"
    } else {
        Write-Info "Quick launch shortcut(s) removed:"
        foreach ($path in $removed) {
            Write-Info " - $path"
        }
    }
}

function Start-QuickLauncher {
    Assert-LaunchFiles

    $wscript = Join-Path $env:WINDIR "System32\wscript.exe"
    Start-Process -FilePath $wscript -ArgumentList (Join-ProcessArguments @($launcher, "-Language", $Language)) -WorkingDirectory $projectRoot -WindowStyle Hidden
    Write-Info "Launcher started."
}

function Test-QuickLauncher {
    Assert-LaunchFiles

    $arguments = Join-ProcessArguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $controller,
        "-Language", $Language,
        "-UiSmokeTestSeconds", "1"
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = $arguments
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()

    if (-not $process.WaitForExit(15000)) {
        try {
            $process.Kill()
        } catch {
        }
        throw "Quick launcher test timed out."
    }

    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()
    $exitCode = $process.ExitCode
    $process.Dispose()

    if ($exitCode -ne 0) {
        if (-not [string]::IsNullOrWhiteSpace($stdErr)) {
            Write-Info $stdErr.Trim()
        } elseif (-not [string]::IsNullOrWhiteSpace($stdOut)) {
            Write-Info $stdOut.Trim()
        }
        throw "Quick launcher test failed with exit code $exitCode."
    }

    Write-Info "Quick launcher test passed."
}

function Open-InstallFolder {
    Start-Process explorer.exe $projectRoot
    Write-Info "Opened install folder: $projectRoot"
}

switch ($Action) {
    "Install" { Install-QuickShortcuts }
    "Uninstall" { Uninstall-QuickShortcuts }
    "Launch" { Start-QuickLauncher }
    "Test" { Test-QuickLauncher }
    "OpenInstallFolder" { Open-InstallFolder }
}

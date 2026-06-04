param(
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN",
    [switch]$Launch,
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Test
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installScript = Join-Path $projectRoot "Install-QuickLaunch.ps1"

function Invoke-QuickLaunchAction {
    param(
        [ValidateSet("Install", "Uninstall", "Launch", "Test", "OpenInstallFolder")]
        [string]$Action,
        [ValidateSet("Desktop", "StartMenu", "Both")]
        [string]$Target = "Both"
    )

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -Action $Action -Target $Target -Language $Language
    if ($LASTEXITCODE -ne 0) {
        throw "Action failed: $Action"
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "Hatch Replay Pet Quick Launch"
    Write-Host ""
    Write-Host "1. Launch app"
    Write-Host "2. Install Desktop and Start Menu shortcuts"
    Write-Host "3. Install Desktop shortcut only"
    Write-Host "4. Uninstall shortcuts"
    Write-Host "5. Test launcher"
    Write-Host "6. Open app folder"
    Write-Host "0. Exit"
    Write-Host ""
}

if (-not (Test-Path $installScript)) {
    throw "Install script not found: $installScript"
}

if ($Launch) {
    Invoke-QuickLaunchAction -Action Launch
    exit 0
}
if ($Install) {
    Invoke-QuickLaunchAction -Action Install
    exit 0
}
if ($Uninstall) {
    Invoke-QuickLaunchAction -Action Uninstall
    exit 0
}
if ($Test) {
    Invoke-QuickLaunchAction -Action Test
    exit 0
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Select"

    switch ($choice) {
        "1" { Invoke-QuickLaunchAction -Action Launch; return }
        "2" { Invoke-QuickLaunchAction -Action Install -Target Both }
        "3" { Invoke-QuickLaunchAction -Action Install -Target Desktop }
        "4" { Invoke-QuickLaunchAction -Action Uninstall -Target Both }
        "5" { Invoke-QuickLaunchAction -Action Test }
        "6" { Invoke-QuickLaunchAction -Action OpenInstallFolder }
        "0" { return }
        default { Write-Host "Invalid selection: $choice" }
    }

    Write-Host ""
    Read-Host "Press Enter to return to the menu" | Out-Null
}

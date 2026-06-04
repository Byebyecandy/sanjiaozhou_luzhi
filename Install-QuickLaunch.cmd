@echo off
setlocal
title Hatch Replay Pet Shortcut Installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-QuickLaunch.ps1" %*
pause

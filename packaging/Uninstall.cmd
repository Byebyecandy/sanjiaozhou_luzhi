@echo off
setlocal
title Hatch Replay Pet Uninstaller
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1" %*
if errorlevel 1 (
  echo.
  echo Uninstall failed.
  pause
  exit /b 1
)
echo.
echo Uninstall finished.
pause

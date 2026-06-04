@echo off
setlocal
title sanjiaozhou_luzhi shortcut installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sanjiaozhou_luzhi_shortcut.ps1" %*
pause

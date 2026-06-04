@echo off
setlocal
title Hatch Replay Pet Quick Launch
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0QuickLaunch.ps1" %*

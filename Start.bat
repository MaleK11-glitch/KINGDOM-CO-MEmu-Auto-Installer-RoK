@echo off
chcp 65001 >nul
title KINGDOM ^& CO
echo.
echo  ============================================
echo    KINGDOM BOTS ^& CO - Checking for updates...
echo  ============================================
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0UpdateFiles.ps1"
echo.
echo  Starting KINGDOM ^& CO...
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0KingROK.ps1"
pause

@echo off
chcp 65001 >nul
title KINGDOM CO - Upload Update to GitHub
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0UpdateToGitHub.ps1"
pause

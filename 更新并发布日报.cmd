@echo off
chcp 65001 >nul
title ALUX AI 智能体情报日报发布
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\publish.ps1"
echo.
pause

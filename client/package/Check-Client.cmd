@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-Client.ps1"
set "checkResult=%errorlevel%"
pause
exit /b %checkResult%

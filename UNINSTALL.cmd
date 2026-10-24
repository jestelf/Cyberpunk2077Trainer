@echo off
setlocal
set "PSModulePath="
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" -Action Uninstall
set "setupResult=%errorlevel%"
echo.
pause
exit /b %setupResult%

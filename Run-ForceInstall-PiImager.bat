@echo off
REM Run-ForceInstall-PiImager.bat - one-click force installer for Pi Imager.
REM
REM Tries winget (multiple ids), then direct download from raspberrypi.org.
REM Captures full log to .\logs\pi-imager-install-*.log.

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Force-Install-PiImager.ps1" -Silent

echo.
echo Log saved to .\logs\pi-imager-install-*.log
pause >nul

@echo off
REM ---------------------------------------------------------------------------
REM Run-Install.bat — one-click launcher for Install-UAPStation.ps1.
REM
REM Double-click this file in File Explorer. It opens a PowerShell window in
REM this folder with the right execution policy, runs the full installer
REM (-RunAll), and captures a transcript to .\logs\install-<timestamp>.log.
REM
REM If you need to override Pi hostnames, edit the line below.
REM ---------------------------------------------------------------------------

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-UAPStation.ps1" -RunAll

echo.
echo ===========================================================================
echo Install run complete. Transcript saved to .\logs\
echo Press any key to close this window.
echo ===========================================================================
pause >nul

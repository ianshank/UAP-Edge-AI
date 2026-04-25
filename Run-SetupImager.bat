@echo off
REM Run-SetupImager.bat - one-click launcher for Setup-PiImager.ps1.
REM
REM Installs Pi Imager (winget) and prepares an SSH key + the Advanced
REM Options values to paste into Pi Imager's settings pane.
REM
REM Run this BEFORE inserting an SD card.

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Setup-PiImager.ps1"

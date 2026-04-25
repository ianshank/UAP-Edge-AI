@echo off
REM Same as Run-Install.bat but with -DryRun: prints every action without
REM executing it, so you can see what the installer would do.

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-UAPStation.ps1" -RunAll -DryRun

echo.
echo Dry run complete. Transcript saved to .\logs\
pause >nul

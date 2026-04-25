@echo off
REM Direct-Install-PiImager.bat - bypass winget; download installer from
REM raspberrypi.org and run it silently.

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; $u='https://downloads.raspberrypi.org/imager/imager_latest.exe'; $d=\"$env:TEMP\imager_latest.exe\"; Write-Host 'Downloading Pi Imager...'; Invoke-WebRequest -Uri $u -OutFile $d -UseBasicParsing; Write-Host 'Installing silently...'; Start-Process -FilePath $d -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait; Write-Host 'Done. Verifying...'; if (Test-Path \"$env:ProgramFiles\Raspberry Pi Imager\rpi-imager.exe\") { Write-Host '[OK] Pi Imager installed at Program Files\Raspberry Pi Imager\rpi-imager.exe' -ForegroundColor Green } else { Write-Host '[!!] rpi-imager.exe not found in default location. Search Start menu for Raspberry Pi Imager.' -ForegroundColor Yellow }"

echo.
pause

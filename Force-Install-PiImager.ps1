<#
.SYNOPSIS
    Force-install Raspberry Pi Imager on Windows, trying multiple paths.

.DESCRIPTION
    Tries, in order:
      1. winget install with the canonical package id
      2. winget install with the alternate package id
      3. winget install with --source winget --silent flags
      4. Direct download of the installer from raspberrypi.org
      5. Run the downloaded installer (silent if /SILENT supported)

    Captures full output to .\logs\pi-imager-install-<timestamp>.log so
    failures can be diagnosed.

    Exits 0 on success (rpi-imager.exe present), nonzero on total failure.

.PARAMETER Silent
    Run the fallback installer with /SILENT (no UI). Default: prompt.
#>
[CmdletBinding()]
param(
    [switch] $Silent
)

$ErrorActionPreference = 'Continue'

# Logging
$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$log = Join-Path $logDir "pi-imager-install-$stamp.log"
Start-Transcript -Path $log -Append | Out-Null

function Write-Sec { param([string]$m) Write-Host ""; Write-Host ("=== " + $m + " ===") -ForegroundColor Cyan }
function Write-Ok  { param([string]$m) Write-Host ("[OK] " + $m) -ForegroundColor Green }
function Write-Wn  { param([string]$m) Write-Host ("[!!] " + $m) -ForegroundColor Yellow }
function Write-Er  { param([string]$m) Write-Host ("[XX] " + $m) -ForegroundColor Red }

function Test-ImagerInstalled {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Raspberry Pi Imager\rpi-imager.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Raspberry Pi Imager\rpi-imager.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Raspberry Pi Imager\rpi-imager.exe')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    if (Get-Command rpi-imager -ErrorAction SilentlyContinue) {
        return (Get-Command rpi-imager).Source
    }
    return $null
}

# ---------- short-circuit: already installed? ----------
$existing = Test-ImagerInstalled
if ($existing) {
    Write-Ok ("Pi Imager already installed at: " + $existing)
    Stop-Transcript | Out-Null
    Write-Host ""
    Write-Host "  Press any key to close." -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
    exit 0
}

# ---------- attempt 1: winget canonical id ----------
Write-Sec 'Attempt 1: winget RaspberryPiFoundation.RaspberryPiImager'
if (Get-Command winget -ErrorAction SilentlyContinue) {
    & winget install --id RaspberryPiFoundation.RaspberryPiImager `
        --accept-package-agreements --accept-source-agreements --silent --source winget 2>&1 |
        Tee-Object -Variable wo
    $existing = Test-ImagerInstalled
    if ($existing) { Write-Ok ("Installed via winget canonical at: " + $existing); Stop-Transcript | Out-Null; exit 0 }
} else {
    Write-Wn 'winget not found on this system'
}

# ---------- attempt 2: winget alternate ids ----------
Write-Sec 'Attempt 2: winget alternate package ids'
$altIds = @(
    'RaspberryPi.RaspberryPiImager',
    '9PNJWRK3RKHN'
)
foreach ($id in $altIds) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host ("    Trying: winget install --id " + $id)
        & winget install --id $id --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
        $existing = Test-ImagerInstalled
        if ($existing) { Write-Ok ("Installed via winget (" + $id + ") at: " + $existing); Stop-Transcript | Out-Null; exit 0 }
    }
}

# ---------- attempt 3: winget search-and-pick ----------
Write-Sec 'Attempt 3: winget search'
if (Get-Command winget -ErrorAction SilentlyContinue) {
    & winget search 'raspberry pi imager' 2>&1
    Write-Wn 'If you see a package above, run: winget install --id <Id>'
}

# ---------- attempt 4: direct download installer ----------
Write-Sec 'Attempt 4: direct download from raspberrypi.org'
$downloadUrl = 'https://downloads.raspberrypi.org/imager/imager_latest.exe'
$installerPath = Join-Path $env:TEMP 'imager_latest.exe'

try {
    Write-Host ("    Downloading " + $downloadUrl)
    Write-Host ("    -> " + $installerPath)
    # Use TLS 1.2 minimum
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    $size = (Get-Item $installerPath).Length
    Write-Ok ("Downloaded " + [math]::Round($size/1MB,1) + " MB")
} catch {
    Write-Er ("Download failed: " + $_.Exception.Message)
    Write-Wn 'Falling back to manual download instructions:'
    Write-Host '    1. Open https://www.raspberrypi.com/software/ in your browser'
    Write-Host '    2. Click "Download for Windows"'
    Write-Host '    3. Run the .exe and follow the prompts'
    Stop-Transcript | Out-Null
    Write-Host ''
    Write-Host '  Press any key to close.' -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
    exit 1
}

# ---------- attempt 5: run the downloaded installer ----------
Write-Sec 'Attempt 5: run the downloaded installer'

# Pi Imager uses an Inno Setup installer; /VERYSILENT works.
$installerArgs = if ($Silent) { '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' } else { @() }

Write-Host ("    Launching: " + $installerPath + ' ' + ($installerArgs -join ' '))
$proc = Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait -PassThru
Write-Host ("    Installer exit code: " + $proc.ExitCode)

# Refresh PATH to pick up the new install
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

$existing = Test-ImagerInstalled
if ($existing) {
    Write-Ok ("Pi Imager installed at: " + $existing)
    Stop-Transcript | Out-Null
    Write-Host ''
    Write-Host '  All done. Pi Imager is ready.' -ForegroundColor Green
    Write-Host ''
    Write-Host '  Press any key to close.' -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
    exit 0
}

Write-Er 'Installation completed without throwing, but rpi-imager.exe still not found in standard locations.'
Write-Wn 'Try launching from the Start menu (search "Raspberry Pi Imager"). If it works, the auto-detect is just looking in the wrong place.'
Write-Host ''
Write-Host ("  Full log: " + $log) -ForegroundColor DarkGray
Stop-Transcript | Out-Null
Write-Host ''
Write-Host '  Press any key to close.' -ForegroundColor DarkGray
[void][System.Console]::ReadKey($true)
exit 1

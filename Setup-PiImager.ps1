<#
.SYNOPSIS
    UAP Station - prepare Pi Imager and credentials for SD card flashing.

.DESCRIPTION
    Run this BEFORE imaging the Pi 2 and Pi 5 SD cards. It will:
      * Install Raspberry Pi Imager via winget if not already present.
      * Create an ed25519 SSH key pair in ~/.ssh/ if none exists.
      * Print the public key plus the Wi-Fi credentials and recommended
        hostnames in a single copy-paste block. Paste those values into
        Pi Imager's "Edit Settings" / Advanced Options pane (Ctrl-Shift-X).

    The Wi-Fi values are baked in from your earlier setup:
        SSID:     Mango_Tango
        Password: N3ll!3_06902

    For instructions, see docs/SD_CARD_IMAGING.md.
#>
[CmdletBinding()]
param(
    [switch] $SkipInstall,
    [switch] $RegenerateKey
)

$ErrorActionPreference = 'Stop'

function Write-Sec { param([string]$M)
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host (">>> " + $M) -ForegroundColor Cyan
    Write-Host "==============================================================="  -ForegroundColor Cyan
}
function Write-Ok { param([string]$M) Write-Host ("[OK] " + $M) -ForegroundColor Green }
function Write-Wn { param([string]$M) Write-Host ("[!!] " + $M) -ForegroundColor Yellow }

Write-Sec 'Step 1 - Pi Imager'
$imagerExe = "$env:ProgramFiles\Raspberry Pi Imager\rpi-imager.exe"
if (Test-Path $imagerExe) {
    Write-Ok "Pi Imager already installed at $imagerExe"
} elseif ($SkipInstall) {
    Write-Wn 'SkipInstall set - assuming Pi Imager is installed somewhere on PATH'
} else {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Wn 'winget not found. Install App Installer from MS Store, or grab the installer from https://www.raspberrypi.com/software/'
    } else {
        Write-Host '    Installing Raspberry Pi Imager via winget...'
        winget install --id RaspberryPiFoundation.RaspberryPiImager `
            --accept-package-agreements --accept-source-agreements --silent
        Write-Ok 'Pi Imager install attempted (verify by launching it from Start menu)'
    }
}

Write-Sec 'Step 2 - SSH key'
$sshDir = Join-Path $env:USERPROFILE '.ssh'
$keyPath = Join-Path $sshDir 'id_ed25519'
$pubPath = "$keyPath.pub"

if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

if ((Test-Path $pubPath) -and -not $RegenerateKey) {
    Write-Ok "Existing key at $keyPath - reusing"
} else {
    if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
        Write-Wn 'ssh-keygen not found. Installing OpenSSH client capability...'
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
    }
    Write-Host "    Generating new ed25519 key at $keyPath ..."
    & ssh-keygen -t ed25519 -N '""' -f $keyPath -C "uap-station-$env:USERNAME"
    Write-Ok 'Key generated'
}

$pubKey = (Get-Content $pubPath -Raw).Trim()

Write-Sec 'Step 3 - Pi Imager Advanced Options - copy these values'
Write-Host ""
Write-Host "  Open Pi Imager. Choose Device, OS (Pi OS Lite), and Storage."
Write-Host "  Click Next - in the dialog click Edit Settings (or press"
Write-Host "  Ctrl-Shift-X). Then enter the following values in the matching"
Write-Host "  fields:"
Write-Host ""
Write-Host "  ----- Pi 2 -----" -ForegroundColor Yellow
Write-Host "    Hostname:                uap-pi2"
Write-Host "    Username:                pi"
Write-Host "    Password:                (set a strong password you remember)"
Write-Host "    Wireless LAN SSID:       Mango_Tango"
Write-Host "    Wireless LAN password:   N3ll!3_06902"
Write-Host "    Wireless LAN country:    (your country code, e.g. US)"
Write-Host "    Locale:                  (your timezone)"
Write-Host "    SSH:                     enable, public-key only"
Write-Host "    Authorized SSH key:"
Write-Host ""
Write-Host ("      " + $pubKey) -ForegroundColor White
Write-Host ""
Write-Host "  ----- Pi 5 -----" -ForegroundColor Yellow
Write-Host "    Same as Pi 2 except:"
Write-Host "    Hostname:                uap-pi5"
Write-Host "    OS choice:               Raspberry Pi OS (64-bit) Lite"
Write-Host "    After first boot, SSH in and add this line to /boot/firmware/config.txt:"
Write-Host "      dtparam=pciex1_gen=3"
Write-Host "    (PCIe Gen 3 for the Hailo-8L HAT+)"
Write-Host ""

# Also write the values to a file so the user can refer back later
$creds = @"
# Pi Imager Advanced Options - generated $(Get-Date -Format s)

PI 2
  Hostname:           uap-pi2
  Username:           pi
  Wi-Fi SSID:         Mango_Tango
  Wi-Fi password:     N3ll!3_06902
  SSH:                public-key only
  Authorized key:
    $pubKey

PI 5 (same as Pi 2 except)
  Hostname:           uap-pi5
  OS:                 Raspberry Pi OS (64-bit) Lite
  Post-boot config:   add 'dtparam=pciex1_gen=3' to /boot/firmware/config.txt
"@
$out = Join-Path (Split-Path -Parent $PSCommandPath) 'logs\pi-imager-settings.txt'
$dir = Split-Path -Parent $out
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
Set-Content -Path $out -Value $creds
Write-Ok ("Settings written to: " + $out)
Write-Host ""
Write-Host "  Press any key to close." -ForegroundColor DarkGray
[void][System.Console]::ReadKey($true)

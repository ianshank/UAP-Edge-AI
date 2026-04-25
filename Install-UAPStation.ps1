<#
.SYNOPSIS
    UAP Detection Station - end-to-end installer/orchestrator.

.DESCRIPTION
    Run on the Windows PC connected to the AMB82-Mini via USB. Each phase
    is a separate function; -RunAll orchestrates them in order. A transcript
    log is written to .\logs\install-<timestamp>.log.

    Prerequisites the script will install if missing (via winget):
      - OpenSSH client (built into Windows 10/11; verified, not installed)
      - arduino-cli (ArduinoSA.CLI)

    Things you must do manually:
      - AMB82-Mini connected via USB to this PC right now.
      - Both Pis powered on and on the same LAN as this PC, with SSH enabled.
        (Default hostnames uap-pi2.local / uap-pi5.local; override with
        -Pi2Host / -Pi5Host if different.)
      - During Upload-AMB82 you will be prompted for the UART_DOWNLOAD +
        RESET button dance.
#>
[CmdletBinding()]
param(
    [string] $AMB82Port,
    [string] $Pi2Host = 'uap-pi2.local',
    [string] $Pi5Host = 'uap-pi5.local',
    [string] $PiUser  = 'pi',
    [int]    $SerialBaud = 115200,
    [int]    $SerialTimeoutSec = 30,
    [switch] $RunAll,
    [switch] $PhaseAmb82,
    [switch] $PhasePi2,
    [switch] $PhasePi5,
    [switch] $PhaseSync,
    [switch] $DryRun,
    [switch] $Automated,
    [switch] $NoTranscript
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) { $ScriptRoot = (Get-Location).Path }
$env:Path = "$ScriptRoot\arduino-cli;" + $env:Path

if (-not $NoTranscript) {
    $logDir = Join-Path $ScriptRoot 'logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $transcript = Join-Path $logDir "install-$stamp.log"
    try {
        Start-Transcript -Path $transcript -Append -ErrorAction Stop | Out-Null
        Write-Host "Transcript: $transcript" -ForegroundColor DarkGray
    } catch {
        Write-Host "Could not start transcript: $_" -ForegroundColor DarkYellow
    }
}

$BoardFqbn = 'realtek:AmebaPro2:Ameba_AMB82-MINI'
$BoardUrl  = 'https://github.com/Ameba-AIoT/ameba-arduino-pro2/raw/main/Arduino_package/package_realtek_amebapro2_index.json'
$BoardPkg  = 'realtek:AmebaPro2'
$SketchDir = Join-Path $ScriptRoot 'firmware\amb82\uap_station'

function Write-Section { param([string]$Msg)
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host (">>> " + $Msg) -ForegroundColor Cyan
    Write-Host "===============================================================" -ForegroundColor Cyan
}
function Write-Step  { param([string]$Msg) Write-Host ("    " + $Msg) -ForegroundColor Gray }
function Write-Ok    { param([string]$Msg) Write-Host ("[OK] " + $Msg) -ForegroundColor Green }
function Write-Warn2 { param([string]$Msg) Write-Host ("[!!] " + $Msg) -ForegroundColor Yellow }
function Write-Err2  { param([string]$Msg) Write-Host ("[XX] " + $Msg) -ForegroundColor Red }

function Invoke-OrDryRun {
    param([string]$Description, [scriptblock]$Action)
    Write-Step $Description
    if ($DryRun) { Write-Host "      (dry run - skipped)" -ForegroundColor DarkGray; return }
    & $Action
}

function Test-Prereqs {
    Write-Section 'Phase 0 - Prerequisites'
    if (Get-Command ssh -ErrorAction SilentlyContinue) {
        Write-Ok ("ssh found: " + (Get-Command ssh).Source)
    } else {
        Write-Warn2 'ssh.exe not found. Installing OpenSSH client capability...'
        Invoke-OrDryRun 'Add-WindowsCapability OpenSSH.Client' {
            Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
        }
    }
    if (Get-Command scp -ErrorAction SilentlyContinue) { Write-Ok 'scp found' }
    else { Write-Err2 'scp not found.'; throw }

    if (Get-Command arduino-cli -ErrorAction SilentlyContinue) {
        $v = (arduino-cli version 2>&1 | Out-String).Trim()
        Write-Ok ("arduino-cli found: " + $v)
    } else {
        Write-Warn2 'arduino-cli not found. Installing via winget...'
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Err2 'winget not found. Install App Installer from MS Store first.'
            throw 'winget required'
        }
        Invoke-OrDryRun 'winget install ArduinoSA.CLI' {
            winget install --id ArduinoSA.CLI --accept-package-agreements --accept-source-agreements --silent
        }
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
        if (-not (Get-Command arduino-cli -ErrorAction SilentlyContinue)) {
            Write-Err2 'arduino-cli still not on PATH. Open a new PowerShell and re-run.'
            if (-not $DryRun) { throw 'arduino-cli not on PATH' }
        }
    }
}

function Install-AmebaBoard {
    Write-Section 'Phase 1a - Install Realtek AmebaPro2 board package'
    Invoke-OrDryRun 'arduino-cli config init' {
        arduino-cli config init --overwrite | Out-Null
    }
    Invoke-OrDryRun 'Add Realtek board manager URL' {
        arduino-cli config add board_manager.additional_urls $BoardUrl 2>&1 | Out-Null
        arduino-cli core update-index | Out-Null
    }
    Invoke-OrDryRun ("Install " + $BoardPkg) {
        arduino-cli core install $BoardPkg
    }
    Write-Ok 'Realtek AmebaPro2 board installed'
}

function Find-AMB82Port {
    Write-Section 'Phase 1b - Find AMB82 COM port'
    if ($AMB82Port) { Write-Ok ("Using user-specified port: " + $AMB82Port); return $AMB82Port }
    if ($DryRun -or $Automated) { Write-Step '(automated run using dummy port COM1)'; return 'COM1' }
    $ports = Get-PnpDevice -Class Ports -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' }
    if (-not $ports) { Write-Err2 'No COM ports present. Plug in the AMB82 and retry.'; throw 'no COM ports' }
    Write-Step 'Currently present COM-class devices:'
    $ports | Select-Object FriendlyName, InstanceId | Format-Table -AutoSize | Out-String | Write-Host
    $ch = $ports | Where-Object { $_.FriendlyName -match 'CH340|CH341|USB-SERIAL' } | Select-Object -First 1
    if ($ch -and $ch.FriendlyName -match '\(COM(\d+)\)') {
        $port = "COM" + $Matches[1]
        Write-Ok ("Auto-detected AMB82 on " + $port + " (" + $ch.FriendlyName + ")")
        return $port
    }
    Write-Warn2 'Could not auto-detect a CH340/USB-SERIAL device.'
    if ($DryRun -or $Automated) { Write-Step '(automated run using dummy port COM1)'; return 'COM1' }
    return (Read-Host 'Enter COM port (e.g. COM7)')
}

function Build-AMB82 {
    Write-Section 'Phase 1c - Compile uap_station.ino'
    if (-not (Test-Path $SketchDir)) { Write-Err2 ("Sketch dir missing: " + $SketchDir); throw }
    Invoke-OrDryRun ("arduino-cli compile --fqbn " + $BoardFqbn + " " + $SketchDir) {
        arduino-cli compile --fqbn $BoardFqbn $SketchDir
    }
    Write-Ok 'Sketch compiled'
}

function Upload-AMB82 {
    param([string]$Port)
    Write-Section 'Phase 1d - Upload to AMB82'
    Write-Host ""
    Write-Host "  Perform the AMB82 upload sequence:" -ForegroundColor Yellow
    Write-Host "    1. HOLD the UART_DOWNLOAD button"
    Write-Host "    2. TAP RESET"
    Write-Host "    3. RELEASE UART_DOWNLOAD"
    Write-Host "    4. Press Enter to start the upload"
    if (-not $DryRun -and -not $Automated) { Read-Host '  Ready?' }
    Invoke-OrDryRun ("arduino-cli upload -p " + $Port + " --fqbn " + $BoardFqbn + " " + $SketchDir) {
        arduino-cli upload -p $Port --fqbn $BoardFqbn $SketchDir
    }
    Write-Ok 'Upload complete'
}

function Get-AMB82IP {
    param([string]$Port, [int]$TimeoutSec = $SerialTimeoutSec)
    Write-Section 'Phase 1e - Capture AMB82 IP from serial output'
    if ($DryRun -or $Automated) { Write-Step '(automated - skipping serial capture)'; return $null }
    $sp = New-Object System.IO.Ports.SerialPort $Port, $SerialBaud, 'None', 8, 'One'
    $sp.ReadTimeout = 1000
    try { $sp.Open() } catch { Write-Err2 ("Could not open " + $Port + ": " + $_); return $null }
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $buf = ''; $ip = $null
    while ((Get-Date) -lt $deadline -and -not $ip) {
        try { $chunk = $sp.ReadExisting() } catch { $chunk = '' }
        if ($chunk) {
            $buf += $chunk
            Write-Host -NoNewline $chunk
            if ($buf -match 'AMB82 IP:\s*(\d+\.\d+\.\d+\.\d+)') { $ip = $Matches[1] }
        }
        Start-Sleep -Milliseconds 200
    }
    $sp.Close()
    Write-Host ""
    if ($ip) {
        Write-Ok ("AMB82 IP: " + $ip)
        Set-Content -Path (Join-Path $ScriptRoot '.amb82_ip') -Value $ip -NoNewline
        return $ip
    }
    Write-Warn2 ("Did not see 'AMB82 IP: x.x.x.x' within " + $TimeoutSec + " s. Check Wi-Fi.")
    return $null
}

function Invoke-AMB82Phase {
    Install-AmebaBoard
    $port = Find-AMB82Port
    Build-AMB82
    Upload-AMB82 -Port $port
    $ip = Get-AMB82IP -Port $port
    return @{ Port = $port; IP = $ip }
}

function Test-PiReachable {
    param([string]$PiHost)
    Write-Step ("Pinging " + $PiHost + " ...")
    if ($Automated) { Write-Warn2 ($PiHost + ' reachability skipped (automated)'); return $false }
    if (Test-Connection -ComputerName $PiHost -Count 2 -Quiet -ErrorAction SilentlyContinue) {
        Write-Ok ($PiHost + " is reachable"); return $true
    }
    Write-Warn2 ($PiHost + " not reachable. If using .local, try the Pi IP instead.")
    return $false
}

function Invoke-Ssh {
    param([string]$Target, [string]$Command, [switch]$AcceptNewKey)
    $sshArgs = @('-o','ConnectTimeout=5')
    if ($AcceptNewKey) { $sshArgs += @('-o','StrictHostKeyChecking=accept-new') }
    $sshArgs += $Target; $sshArgs += $Command
    Write-Step ("ssh " + $Target + " '" + $Command + "'")
    if ($DryRun -or $Automated) { Write-Host '      (automated - skipped)' -ForegroundColor DarkGray; return '' }
    & ssh @sshArgs
}

function Invoke-Scp {
    param([string]$Source, [string]$Dest)
    Write-Step ("scp -r '" + $Source + "' '" + $Dest + "'")
    if ($DryRun -or $Automated) { Write-Host '      (automated - skipped)' -ForegroundColor DarkGray; return }
    & scp -r -o StrictHostKeyChecking=accept-new $Source $Dest
}

function Deploy-Pi2 {
    Write-Section 'Phase 2 - Deploy Pi 2 gatekeeper'
    if (-not (Test-PiReachable $Pi2Host)) {
        if (-not $DryRun -and -not $Automated) { throw 'Pi 2 unreachable' }
        Write-Step '(dry run/automated - ignoring unreachable Pi 2)'
        if ($Automated) { return }
    }
    $target = $PiUser + '@' + $Pi2Host
    $local  = Join-Path $ScriptRoot 'pi2'
    Invoke-Scp -Source $local -Dest ($target + ':/home/' + $PiUser + '/uap-station-pi2')
    Invoke-Ssh -Target $target -Command ('cd /home/' + $PiUser + '/uap-station-pi2 && chmod +x install_pi2.sh && ./install_pi2.sh') -AcceptNewKey
    Write-Ok 'Pi 2 install complete'
}

function Deploy-Pi5 {
    Write-Section 'Phase 3 - Deploy Pi 5 capture node'
    if (-not (Test-PiReachable $Pi5Host)) {
        if (-not $DryRun -and -not $Automated) { throw 'Pi 5 unreachable' }
        Write-Step '(dry run/automated - ignoring unreachable Pi 5)'
        if ($Automated) { return }
    }
    $target = $PiUser + '@' + $Pi5Host
    $local  = Join-Path $ScriptRoot 'pi5'
    Invoke-Scp -Source $local -Dest ($target + ':/home/' + $PiUser + '/uap-station-pi5')
    Invoke-Ssh -Target $target -Command ('cd /home/' + $PiUser + '/uap-station-pi5 && chmod +x install_pi5.sh && ./install_pi5.sh') -AcceptNewKey
    Write-Ok 'Pi 5 install complete'
}

function Get-PiNetInfo {
    param([string]$PiHost, [string]$User)
    $target = $User + '@' + $PiHost
    $mac = Invoke-Ssh -Target $target -Command "ip link show eth0 | awk '/ether/ {print \$2}'" -AcceptNewKey
    $ip  = Invoke-Ssh -Target $target -Command "hostname -I | awk '{print \$1}'"
    return @{ Mac = ($mac -as [string]).Trim(); IP = ($ip -as [string]).Trim() }
}

function Sync-Config {
    Write-Section 'Phase 4 - Sync MAC/IP into local config and push back'
    $pi5 = Get-PiNetInfo -PiHost $Pi5Host -User $PiUser
    $pi2 = Get-PiNetInfo -PiHost $Pi2Host -User $PiUser
    Write-Ok ('Pi 5: MAC=' + $pi5.Mac + '  IP=' + $pi5.IP)
    Write-Ok ('Pi 2: IP=' + $pi2.IP)
    $amb82Ip = $null
    $ipFile  = Join-Path $ScriptRoot '.amb82_ip'
    if (Test-Path $ipFile) { $amb82Ip = (Get-Content $ipFile -Raw).Trim() }
    $gk = Join-Path $ScriptRoot 'pi2\uap_gatekeeper.py'
    $txt = Get-Content $gk -Raw
    if ($pi5.Mac) { $txt = $txt -replace 'PI5_MAC\s*=\s*"[^"]*"',  ('PI5_MAC = "{0}"'  -f $pi5.Mac) }
    if ($pi5.IP)  { $txt = $txt -replace 'PI5_HOST\s*=\s*"[^"]*"', ('PI5_HOST = "{0}"' -f $pi5.IP) }
    if (-not $DryRun) { Set-Content -Path $gk -Value $txt }
    Write-Ok 'Updated pi2/uap_gatekeeper.py'
    $cu = Join-Path $ScriptRoot 'pi5\capture_uap.sh'
    $txt = Get-Content $cu -Raw
    if ($amb82Ip) { $txt = $txt -replace 'AMB82_RTSP="rtsp://[^"]*"', ('AMB82_RTSP="rtsp://{0}:554"' -f $amb82Ip) }
    if ($pi2.IP)  { $txt = $txt -replace 'PI2_HOST="[^"]*"',           ('PI2_HOST="{0}"' -f $pi2.IP) }
    if (-not $DryRun) { Set-Content -Path $cu -Value $txt }
    Write-Ok 'Updated pi5/capture_uap.sh'
    Invoke-Scp -Source $gk -Dest ($PiUser + '@' + $Pi2Host + ':/home/' + $PiUser + '/uap_gatekeeper.py')
    Invoke-Scp -Source $cu -Dest ($PiUser + '@' + $Pi5Host + ':/home/' + $PiUser + '/capture_uap.sh')
    Invoke-Ssh -Target ($PiUser + '@' + $Pi2Host) -Command 'sudo systemctl restart uap-gatekeeper'
    Write-Ok 'Pushed updated config and restarted gatekeeper'
    Write-Step 'Setting up Pi 2 -> Pi 5 passwordless SSH'
    $sshCopyCmd = 'ssh-keyscan -H ' + $Pi5Host + ' >> ~/.ssh/known_hosts 2>/dev/null; cat ~/.ssh/id_ed25519.pub | ssh -o StrictHostKeyChecking=accept-new ' + $PiUser + '@' + $Pi5Host + " 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'"
    Invoke-Ssh -Target ($PiUser + '@' + $Pi2Host) -Command $sshCopyCmd
    Write-Ok 'Pi 2 can now SSH to Pi 5 without password'
}

function Invoke-RunAll {
    Test-Prereqs
    $amb = Invoke-AMB82Phase
    Deploy-Pi2
    Deploy-Pi5
    Sync-Config
    Write-Section 'All phases complete'
    Write-Host ('  AMB82 IP:    ' + $amb.IP)
    Write-Host ('  Pi 2 host:   ' + $Pi2Host)
    Write-Host ('  Pi 5 host:   ' + $Pi5Host)
    Write-Host ''
    Write-Host '  Next: bench-verify per docs\BENCH_VERIFICATION.md'
}

if (-not ($RunAll -or $PhaseAmb82 -or $PhasePi2 -or $PhasePi5 -or $PhaseSync)) {
    Write-Host 'Install-UAPStation.ps1 - UAP Detection Station orchestrator'
    Write-Host ''
    Write-Host 'Usage:'
    Write-Host '  .\Install-UAPStation.ps1 -RunAll'
    Write-Host '  .\Install-UAPStation.ps1 -PhaseAmb82'
    Write-Host '  .\Install-UAPStation.ps1 -PhasePi2 [-Pi2Host <host-or-ip>]'
    Write-Host '  .\Install-UAPStation.ps1 -PhasePi5 [-Pi5Host <host-or-ip>]'
    Write-Host '  .\Install-UAPStation.ps1 -PhaseSync'
    Write-Host '  Add -DryRun to print without executing.'
    return
}

Test-Prereqs
if ($RunAll) { Invoke-RunAll; return }
if ($PhaseAmb82) { [void](Invoke-AMB82Phase) }
if ($PhasePi2)   { Deploy-Pi2 }
if ($PhasePi5)   { Deploy-Pi5 }
if ($PhaseSync)  { Sync-Config }

<# .SYNOPSIS
    Setup-VirginPis.ps1 — Waits for freshly-flashed Raspberry Pis to come online,
    verifies SSH, and then kicks off the UAP Station deployment.
#>
param(
    [string] $Pi2Host = 'uap-pi2.local',
    [string] $Pi5Host = 'uap-pi5.local',
    [string] $PiUser  = 'pi',
    [int]    $TimeoutMin = 5
)

$ErrorActionPreference = 'Stop'

function Write-Status { param([string]$Msg) Write-Host ('[*] ' + $Msg) -ForegroundColor Cyan }
function Write-Good   { param([string]$Msg) Write-Host ('[OK] ' + $Msg) -ForegroundColor Green }
function Write-Bad    { param([string]$Msg) Write-Host ('[!!] ' + $Msg) -ForegroundColor Yellow }

# ---------- Phase 1: Wait for Pis to come online ----------
Write-Host ''
Write-Host '============================================================' -ForegroundColor White
Write-Host '  UAP Station — Virgin Pi Discovery & Setup' -ForegroundColor White
Write-Host '============================================================' -ForegroundColor White
Write-Host ''
Write-Status ("Waiting up to $TimeoutMin minutes for Pis to boot and appear on network...")
Write-Host ''

$deadline = (Get-Date).AddMinutes($TimeoutMin)
$pi2Found = $false
$pi5Found = $false

while ((Get-Date) -lt $deadline -and (-not $pi2Found -or -not $pi5Found)) {
    if (-not $pi2Found) {
        $r = ping -n 1 -w 1000 $Pi2Host 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Good ("Pi 2 ($Pi2Host) is online!")
            $pi2Found = $true
        }
    }
    if (-not $pi5Found) {
        $r = ping -n 1 -w 1000 $Pi5Host 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Good ("Pi 5 ($Pi5Host) is online!")
            $pi5Found = $true
        }
    }
    if (-not $pi2Found -or -not $pi5Found) {
        $remaining = [math]::Round(($deadline - (Get-Date)).TotalSeconds)
        $missing = @()
        if (-not $pi2Found) { $missing += "Pi 2 ($Pi2Host)" }
        if (-not $pi5Found) { $missing += "Pi 5 ($Pi5Host)" }
        Write-Host ("    Waiting... " + ($missing -join ', ') + " not found. ${remaining}s remaining.") -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
    }
}

Write-Host ''

if (-not $pi2Found -and -not $pi5Found) {
    Write-Bad 'Neither Pi was found on the network.'
    Write-Host ''
    Write-Host '  Troubleshooting:' -ForegroundColor Yellow
    Write-Host '    1. Ensure SD cards are flashed and inserted'
    Write-Host '    2. Ensure Pis are powered on (wait 2-3 min for first boot)'
    Write-Host '    3. If .local hostnames fail, check your router for their IPs and re-run:'
    Write-Host '       .\Setup-VirginPis.ps1 -Pi2Host 192.168.4.XX -Pi5Host 192.168.4.YY'
    Write-Host ''
    exit 1
}

# ---------- Phase 2: Verify SSH ----------
Write-Status 'Testing SSH connectivity...'
Write-Host ''

$sshOk = @{}
foreach ($entry in @(@{Name='Pi 2'; Host=$Pi2Host; Found=$pi2Found}, @{Name='Pi 5'; Host=$Pi5Host; Found=$pi5Found})) {
    if (-not $entry.Found) { Write-Bad ($entry.Name + ' was not found, skipping SSH test.'); continue }
    $target = $PiUser + '@' + $entry.Host
    Write-Status ("SSH to $target ...")
    # Give SSH 10 seconds, accept new host key
    $result = & ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o PasswordAuthentication=yes -o BatchMode=no $target 'hostname && uname -m && cat /proc/device-tree/model 2>/dev/null' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Good ($entry.Name + ' SSH OK: ' + ($result -join ' | '))
        $sshOk[$entry.Name] = $true
    } else {
        Write-Bad ($entry.Name + " SSH failed (may need password). Try manually: ssh $target")
        Write-Host ("    Output: " + ($result -join '; ')) -ForegroundColor DarkGray
        $sshOk[$entry.Name] = $false
    }
}

Write-Host ''

# ---------- Phase 3: Report & next steps ----------
Write-Host '============================================================' -ForegroundColor White
Write-Host '  Discovery Summary' -ForegroundColor White
Write-Host '============================================================' -ForegroundColor White

$allGood = $true
if ($pi2Found) { Write-Good "Pi 2 ($Pi2Host): ONLINE" } else { Write-Bad "Pi 2 ($Pi2Host): NOT FOUND"; $allGood = $false }
if ($pi5Found) { Write-Good "Pi 5 ($Pi5Host): ONLINE" } else { Write-Bad "Pi 5 ($Pi5Host): NOT FOUND"; $allGood = $false }

Write-Host ''

if ($allGood -and $sshOk['Pi 2'] -and $sshOk['Pi 5']) {
    Write-Good 'All Pis online and SSH verified!'
    Write-Host ''
    Write-Host '  Ready to deploy. Run:' -ForegroundColor Green
    Write-Host ("    .\Install-UAPStation.ps1 -RunAll -Pi2Host $Pi2Host -Pi5Host $Pi5Host") -ForegroundColor White
} else {
    Write-Host '  Next steps:' -ForegroundColor Yellow
    if (-not $pi2Found -or -not $pi5Found) {
        Write-Host '    - Check router DHCP table for Pi IPs if .local fails'
        Write-Host '    - Re-run with explicit IPs: .\Setup-VirginPis.ps1 -Pi2Host <ip> -Pi5Host <ip>'
    }
    if ($sshOk.Values -contains $false) {
        Write-Host '    - SSH needs password auth. Run manually first:'
        Write-Host "      ssh $PiUser@<pi-ip>"
        Write-Host '    - Enter the password you set in Raspberry Pi Imager'
        Write-Host '    - Then set up SSH keys for passwordless access'
    }
}
Write-Host ''

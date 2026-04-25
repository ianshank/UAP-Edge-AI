# UAP Detection Station — configuration bundle

[![Status: Active](https://img.shields.io/badge/Status-Active-brightgreen.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)]()

> **Documentation Index**
> - [Architecture (C4 Model)](./ARCHITECTURE.md)
> - [Changelog](./CHANGELOG.md)
> - [Regression & QA Plan](./REGRESSION_PLAN.md)
> - [Next Steps & Roadmap](./NEXT_STEPS.md)

Per-device configuration for the three-tier detection station described in
`UAP_Station_Build_Guide.pdf`. Generated 2026-04-25.

## What's plugged in vs. what this bundle assumes

You listed four USB connections:

| # | Connection                          | What it's for                                         |
|---|-------------------------------------|-------------------------------------------------------|
| 1 | **AMB82 → PC (USB)**                | Flashing firmware via Arduino IDE (CH340 COM port).   |
| 2 | **Pi 2 → PC (USB)**                 | Power for headless first-boot setup.                  |
| 3 | **Pi 5 + Hailo-8L → PC (USB-C)**    | Power input (USB-C is *power*, not data).             |
| 4 | **AMB82 → Pi 2 (GPIO UART)**        | Detection events at 115200 baud (NOT USB).            |

You confirmed #4 is the GPIO UART crossover from §4 of the build guide,
not a USB-USB cable. Configuration below assumes that.

## Layout

```
UAP Station/
├── README.md                  ← you are here
├── firmware/
│   └── amb82/
│       ├── uap_station.ino    ← Arduino sketch (Wi-Fi creds baked in)
│       └── README.md
├── pi2/
│   ├── uap_gatekeeper.py      ← UART reader + escalation daemon
│   ├── uap-gatekeeper.service ← systemd unit
│   ├── install_pi2.sh         ← one-shot setup
│   └── README.md
├── pi5/
│   ├── capture_uap.sh         ← RTSP recorder + Hailo trigger
│   ├── hailo_infer.py         ← Hailo-8L inference template
│   ├── install_pi5.sh         ← one-shot setup
│   └── README.md
└── docs/
    ├── WIRING.md              ← UART crossover diagram
    └── BENCH_VERIFICATION.md  ← desk-side end-to-end test
```

## Step 0 — Image SD cards (only if Pis are fresh)

If your Pi 2 and Pi 5 don't yet have Raspberry Pi OS installed, do this
first. Double-click **`Run-SetupImager.bat`** — it installs Raspberry
Pi Imager via winget, generates an SSH key if you don't have one, and
prints the exact values to paste into Pi Imager's Advanced Options pane
(Ctrl-Shift-X) for each Pi (hostname, Wi-Fi `Mango_Tango`/`N3ll!3_06902`,
authorized SSH key).

Step-by-step instructions: `docs/SD_CARD_IMAGING.md`.

After both SD cards are flashed and both Pis boot, verify:

```powershell
ping uap-pi2.local
ping uap-pi5.local
```

…then proceed to the quick-start below.

## Quick start — one double-click

In File Explorer, navigate to this folder and **double-click
`Run-Install.bat`**. It opens a PowerShell window in this directory with the
right execution policy, runs `.\Install-UAPStation.ps1 -RunAll`, and writes
a full transcript to `.\logs\install-<timestamp>.log`.

If you'd rather see what it would do without making changes, double-click
**`Run-DryRun.bat`** first.

Or, equivalently, from a PowerShell prompt:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Install-UAPStation.ps1 -RunAll
```

That orchestrator will:

1. Verify or install OpenSSH and arduino-cli.
2. Add the Realtek board manager URL and install the AmebaPro2 package.
3. Detect the AMB82's COM port (CH340 device).
4. Compile `uap_station.ino`.
5. Prompt you to do the **UART_DOWNLOAD + RESET** button dance, then upload.
6. Open the serial port and capture the AMB82's IP.
7. SCP the `pi2/` bundle to the Pi 2 (default host `uap-pi2.local`) and run
   `install_pi2.sh` over SSH.
8. SCP the `pi5/` bundle to the Pi 5 (default host `uap-pi5.local`) and run
   `install_pi5.sh` over SSH.
9. Pull each Pi's MAC + IP, write them back into `pi2/uap_gatekeeper.py`
   and `pi5/capture_uap.sh`, push the updated files back, and restart the
   gatekeeper service.
10. Set up passwordless SSH from Pi 2 to Pi 5 for the WoL+capture trigger.

Override hostnames if needed:

```powershell
.\Install-UAPStation.ps1 -RunAll -Pi2Host 192.168.1.41 -Pi5Host 192.168.1.50
```

Run individual phases (useful for debugging):

```powershell
.\Install-UAPStation.ps1 -PhaseAmb82       # just the firmware
.\Install-UAPStation.ps1 -PhasePi2         # just the Pi 2 deploy
.\Install-UAPStation.ps1 -PhasePi5         # just the Pi 5 deploy
.\Install-UAPStation.ps1 -PhaseSync        # just the MAC/IP write-back
.\Install-UAPStation.ps1 -RunAll -DryRun   # show actions without executing
```

## What the installer leaves to you

* The **3-wire UART crossover** between AMB82 and Pi 2 — physical wiring
  per `docs/WIRING.md`. Until those wires are in, the gatekeeper won't see
  any events even though the service runs cleanly.
* **Static DHCP leases** for AMB82, Pi 2, and Pi 5 in your router. Without
  them, IPs can drift and break the WoL/SSH targets.
* **Bench verification** per `docs/BENCH_VERIFICATION.md`.
* **Three nights of field tuning** per build guide §11.

## Manual fallback (no PowerShell installer)

1. **AMB82 first.** Flash `firmware/amb82/uap_station/uap_station.ino`
   from the PC over USB. Note the IP printed on the Serial Monitor.
2. **Pi 2 second.** Run `pi2/install_pi2.sh`, set `PI5_MAC`/`PI5_HOST`
   placeholders aside until the Pi 5 is on the network.
3. **Pi 5 third.** Run `pi5/install_pi5.sh`. It prints the Pi 5's MAC + IP.
4. **Wire UART, push SSH key, edit values.** Three-wire UART crossover
   between AMB82 and Pi 2; `ssh-copy-id` from Pi 2 to Pi 5; fill in
   `PI5_MAC`, `PI5_HOST`, `AMB82_RTSP`, `PI2_HOST` in the relevant scripts.
5. **Bench-verify.** Follow `docs/BENCH_VERIFICATION.md` step-by-step.
6. **Field tune** for three nights per build guide §11 before sealing the
   enclosure.

## Credentials baked into the bundle

* Wi-Fi SSID:  `Mango_Tango`
* Wi-Fi pass:  `N3ll!3_06902`

These appear in plaintext in `firmware/amb82/uap_station.ino`. Because
this folder lives in OneDrive, the password syncs to Microsoft's cloud.
If that's a concern, move the `firmware/` directory outside OneDrive, or
keep the file in OneDrive but with `YOUR_PASS` as a placeholder and only
fill in the real password temporarily before each flash.

## Cleaning up verification artifacts

Two small directories were left behind by the syntax-check pass on my side:

* `.mypy_cache/` (~8 MB of Python typeshed JSON)
* `pi2/__pycache__/`, `pi5/__pycache__/` (compiled `.pyc` files)

They're harmless but bloat OneDrive sync. Delete from PowerShell:

```powershell
Remove-Item -Recurse -Force "C:\Users\iansh\OneDrive\Documents\UAP Station\.mypy_cache"
Remove-Item -Recurse -Force "C:\Users\iansh\OneDrive\Documents\UAP Station\pi2\__pycache__"
Remove-Item -Recurse -Force "C:\Users\iansh\OneDrive\Documents\UAP Station\pi5\__pycache__"
```

## What this bundle deliberately leaves blank

Three values that depend on your network and are easier to fill in once
everything is on the LAN:

| Value         | Where it lives                  | Source                               |
|---------------|----------------------------------|--------------------------------------|
| `PI5_MAC`     | `pi2/uap_gatekeeper.py`          | `ip link show eth0` on the Pi 5      |
| `PI5_HOST`    | `pi2/uap_gatekeeper.py`          | `hostname -I` on the Pi 5            |
| `AMB82_RTSP` IP | `pi5/capture_uap.sh`           | AMB82 Serial Monitor on first boot   |
| `PI2_HOST`    | `pi5/capture_uap.sh`             | `hostname -I` on the Pi 2            |

Reserve **static DHCP leases** for all three devices in your router so
those values don't drift.

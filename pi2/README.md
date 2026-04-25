# Raspberry Pi 2 — gatekeeper setup

Tier 2 of the UAP detection station. The Pi 2 reads CSV detection events
from the AMB82-Mini over GPIO UART, clusters them in a 5-second window,
filters out mundane labels (airplane, bird, kite), and when something
non-mundane crosses thresholds it wakes the Pi 5 and triggers a capture.

## Files

| File                       | Purpose                                          |
|----------------------------|--------------------------------------------------|
| `uap_gatekeeper.py`        | Main daemon — reads UART, decides, escalates.    |
| `uap-gatekeeper.service`   | systemd unit (Restart=always).                   |
| `install_pi2.sh`           | One-shot setup — apt deps, UART, SSH key, unit.  |
| `README.md`                | This file.                                       |

## Hardware checklist

* **USB → PC:** the USB cable from the Pi 2 to your Windows PC is for
  initial setup (e.g. flashing Raspberry Pi OS via Imager, or as a USB
  Ethernet gadget for headless first boot). Once the Pi is on the network,
  the USB-to-PC link is no longer needed for runtime — the station talks
  to the Pi 2 over Ethernet.
* **GPIO UART:** the *only* electrical link between AMB82 and Pi 2 at
  runtime. 3 wires:

  | Wire   | AMB82 pin              | Pi 2 physical pin     |
  |--------|------------------------|-----------------------|
  | yellow | D21 (PA2 / SERIAL1_TX) | 10 (GPIO15 / RXD)     |
  | green  | D22 (PA3 / SERIAL1_RX) |  8 (GPIO14 / TXD)     |
  | black  | GND                    |  6 (GND)              |

  **TX/RX must crossover.** If parsing fails, swap yellow and green.

## First-boot, headless via USB

If you're using the USB cable to set up a fresh Pi 2:

1. Flash Raspberry Pi OS Lite with the **Imager** tool. In Imager's
   advanced options (gear icon), pre-set:
   * hostname (e.g. `uap-pi2`)
   * username `pi`
   * Wi-Fi: SSID `Mango_Tango`, password `N3ll!3_06902`
   * Enable SSH with a public key (paste your PC's `~/.ssh/id_ed25519.pub`).
2. Boot the Pi. Find it on the network: `ping uap-pi2.local`.
3. SSH in: `ssh pi@uap-pi2.local`.

The Pi 2 doesn't have a USB-Ethernet gadget mode like the Pi Zero, so the
USB cable is purely for power during initial setup. For runtime you'll use
the Cat5e Ethernet specified in the build guide.

## Install

Copy this folder to the Pi:

```bash
scp -r pi2 pi@uap-pi2.local:/home/pi/uap-station-pi2
ssh pi@uap-pi2.local
cd uap-station-pi2
chmod +x install_pi2.sh
./install_pi2.sh
sudo reboot
```

After reboot, edit `/home/pi/uap_gatekeeper.py` and fill in:

```python
PI5_MAC  = "XX:XX:XX:XX:XX:XX"  # from `ip link show eth0` on the Pi 5
PI5_HOST = "192.168.1.50"       # from `hostname -I` on the Pi 5
```

Then:

```bash
ssh-copy-id pi@<PI5_HOST>          # passwordless SSH for capture trigger
sudo systemctl start uap-gatekeeper
tail -f /home/pi/uap_logs/gatekeeper.log
```

## Tunables (top of the script)

| Constant                 | Default | Meaning                                    |
|--------------------------|---------|--------------------------------------------|
| `WINDOW_SEC`             | 5       | Sliding window for event clustering.       |
| `MIN_EVENTS`             | 3       | Min interesting events in window to fire.  |
| `MIN_INTERESTING_SCORE`  | 0.50    | At least one event must clear this score.  |
| `WAKE_COOLDOWN_SEC`      | 60      | Don't wake Pi 5 more than once per minute. |
| `EXCLUDE_LABELS`         | airplane, bird, kite | Mundane COCO classes to ignore. |

For the first 3 nights of field tuning, **comment out the call to
`wake_pi5(...)`** and just log everything. See §11 of the build guide.

## Bench verification

See `docs/BENCH_VERIFICATION.md` at the workspace root.

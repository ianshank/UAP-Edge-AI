# Raspberry Pi 5 + Hailo-8L — capture node setup

Tier 3 of the UAP detection station. The Pi 5 stays awake (Phase 1) or
suspended (Phase 2), receives a Wake-on-LAN magic packet from the Pi 2 on
confirmed escalation, then pulls the AMB82's RTSP stream and runs heavier
inference on the 26 TOPS Hailo-8L AI HAT+.

## Files

| File              | Purpose                                                     |
|-------------------|-------------------------------------------------------------|
| `capture_uap.sh`  | RTSP recorder + Hailo trigger. Called by Pi 2 over SSH.     |
| `hailo_infer.py`  | Hailo-8L inference wrapper around the AMB82 RTSP source.    |
| `install_pi5.sh`  | One-shot setup — apt deps, Hailo runtime, WoL, deploy.      |
| `README.md`       | This file.                                                  |

## Hardware checklist

* **USB-C → PC:** the Pi 5's USB-C port is its **27 W power input**, not a
  data link to your PC. If the port is currently plugged into your PC,
  the Pi 5 is being powered from the PC's USB-C output — that may or may
  not deliver the full 5 V / 5 A the Pi 5 wants under load. For runtime,
  use the official Raspberry Pi 27 W USB-C PSU.
  * If you also want a *data* link from the Pi 5 to the PC, use a USB-A
    cable on one of the Pi 5's USB-A ports as a USB-Ethernet gadget, or
    just SSH in over the same Ethernet network the Pi 2 is on.
* **Hailo-8L AI HAT+:** sits on the Pi 5's PCIe FFC ribbon. The
  `hailo-all` apt package on Raspberry Pi OS Bookworm wires up the kernel
  module, firmware, and Python bindings.
* **Ethernet:** required. WoL targets a specific MAC + IP, so the Pi 5
  needs a **static DHCP lease** on your router.

## Install

Copy this folder to the Pi:

```bash
scp -r pi5 pi@uap-pi5.local:/home/pi/uap-station-pi5
ssh pi@uap-pi5.local
cd uap-station-pi5
chmod +x install_pi5.sh
./install_pi5.sh
```

The script prints the Pi 5's MAC and IP at the end — copy those into the
Pi 2's gatekeeper as `PI5_MAC` and `PI5_HOST`.

Then:

1. Reserve a **static DHCP lease** for the Pi 5 in your router.
2. Edit `/home/pi/capture_uap.sh`:
   ```bash
   AMB82_RTSP="rtsp://<AMB82_IP>:554"   # from AMB82 serial monitor
   PI2_HOST="<PI2_IP>"                  # from `hostname -I` on Pi 2
   ```
3. From the Pi 2: `ssh-copy-id pi@<PI5_IP>`.
4. Replace the `run_pipeline()` stub in `hailo_infer.py` with the real
   Hailo example (see comments — it's ~5 lines from
   `hailo-rpi5-examples`).

## Wake-on-LAN

`install_pi5.sh` enables WoL with `ethtool -s eth0 wol g` and persists it
via a `networkd-dispatcher` hook. Verify with:

```bash
sudo ethtool eth0 | grep Wake-on   # expect: Wake-on: g
```

For Phase 1 the Pi 5 is left running; the WoL packet is a no-op safety
net. To exercise it from the Pi 2:

```bash
wakeonlan <PI5_MAC>
```

…and on the Pi 5, watch for the magic packet:

```bash
sudo tcpdump -i eth0 udp port 9
```

## Capture folder layout

Each escalation produces:

```
/home/pi/uap_captures/<UTC_timestamp>/
├── raw.mp4           # 60s of H.264 from the AMB82 RTSP stream
├── burst.json        # detection events that triggered the wake
├── detections.jsonl  # Hailo inference results
├── ffmpeg.log
└── hailo.log
```

Mount a USB drive at `/home/pi/uap_captures` if you want months of
storage. With 1–2% capture duty cycle, a 1 TB drive lasts effectively
forever for a single station.

## Phase 2 — actual suspend

The build guide §12 calls for `sudo systemctl suspend` at the end of
`capture_uap.sh` plus `IdleAction=suspend` in `logind.conf`. That moves
the Pi 5 from "always on, ~10 W" to "asleep until WoL, ~0.5 W idle".
Don't enable this until WoL has been verified working end-to-end.

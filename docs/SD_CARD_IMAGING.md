# SD card imaging — Pi 2 and Pi 5

Use **Raspberry Pi Imager** on your Windows PC to write Raspberry Pi OS to
two SD cards (one per Pi) with Wi-Fi, SSH, and hostname pre-configured.
The orchestrator `Install-UAPStation.ps1` then deploys to both Pis over
SSH without any extra typing on the Pis themselves.

## 1. Install Pi Imager

From an elevated PowerShell window, or just a regular one if `winget` is
already on your PATH:

```powershell
winget install --id RaspberryPiFoundation.RaspberryPiImager `
    --accept-package-agreements --accept-source-agreements
```

Or download the installer manually from
<https://www.raspberrypi.com/software/>.

The bundled helper `Setup-PiImager.ps1` (in this folder) does the install
plus generates an SSH key for you. See section 5.

## 2. Hardware checklist

* Two microSD cards. Recommended: 32 GB Class 10 / A1 or better.
  * The Pi 2 will live in the outdoor enclosure and rarely write — small
    is fine.
  * The Pi 5 records H.264 captures during escalations — bigger is better,
    or mount a USB drive at `/home/pi/uap_captures`.
* USB SD-card reader for your PC.
* (For the Pi 5) the Hailo-8L AI HAT+ stays unplugged while imaging — fit
  it after first boot.

## 3. Pi 2 — Imaging steps

1. Insert the SD card into your PC.
2. Open **Raspberry Pi Imager**.
3. **Choose Device:** Raspberry Pi 2.
4. **Choose OS:** Raspberry Pi OS (Other) → **Raspberry Pi OS Lite (32-bit)**.
   Lite is correct here — the Pi 2 has no display and only runs the
   gatekeeper Python script.
5. **Choose Storage:** your SD card.
6. Click **Next**, then **Edit Settings** (or press Ctrl-Shift-X before
   clicking write).

### Pi 2 — Advanced Options pane

| Field                              | Value                                       |
|------------------------------------|---------------------------------------------|
| Set hostname                       | `uap-pi2`                                   |
| Set username and password          | username `pi`, password (anything strong)   |
| Configure wireless LAN             | SSID `Mango_Tango`, password `N3ll!3_06902` |
| Wireless LAN country               | (your country, e.g. US)                     |
| Set locale settings                | (your timezone)                             |
| Enable SSH                         | **Use public-key authentication only**      |
| Set authorized_keys                | paste the contents of `~/.ssh/id_ed25519.pub` (`Setup-PiImager.ps1` prints this for you) |

Click **Save**, then **Yes** to apply, then **Yes** to write.

7. Wait for verify to finish, eject the card, insert into the Pi 2, power up.
8. From your PC, after ~60 seconds: `ping uap-pi2.local` should succeed.

## 4. Pi 5 — Imaging steps

Same as Pi 2 with three differences:

1. **Choose Device:** Raspberry Pi 5.
2. **Choose OS:** Raspberry Pi OS (other) → **Raspberry Pi OS (64-bit)**.
   The Pi 5 wants 64-bit and Lite is fine — the capture pipeline is
   headless.
3. **Hostname:** `uap-pi5`.
4. (Same Wi-Fi, same user, same SSH key.)

### Pi 5 — extra step after first boot (Hailo HAT+)

The Hailo HAT+ uses PCIe Gen 3 on the Pi 5. By default Bookworm boots
with Gen 2; switch to Gen 3 once for full Hailo bandwidth. SSH in:

```bash
ssh pi@uap-pi5.local
sudo nano /boot/firmware/config.txt
```

Add at the bottom:

```
dtparam=pciex1_gen=3
```

Reboot:

```bash
sudo reboot
```

The `pi5/install_pi5.sh` step (run by the orchestrator later) installs
the `hailo-all` package which loads the kernel module and firmware.

## 5. Helper script — `Setup-PiImager.ps1`

A small PowerShell helper that does the boring parts:

* Checks for / installs Pi Imager via winget.
* Generates an ed25519 SSH key pair at `~/.ssh/id_ed25519` if absent.
* Prints the public key, Wi-Fi credentials, and recommended hostnames in
  a copy-paste-friendly block so you can drop them straight into Pi
  Imager's Advanced Options pane.

Double-click `Run-SetupImager.bat` or run:

```powershell
.\Setup-PiImager.ps1
```

## 6. After both cards are flashed

1. Power on both Pis.
2. Verify connectivity from your PC:

   ```powershell
   ping uap-pi2.local
   ping uap-pi5.local
   ssh pi@uap-pi2.local 'uname -a'
   ssh pi@uap-pi5.local 'uname -a'
   ```

3. Reserve **static DHCP leases** for both Pis (and the AMB82) in your
   router so the IPs in `pi2/uap_gatekeeper.py` and `pi5/capture_uap.sh`
   stay valid across reboots.
4. Run the orchestrator:

   ```
   Run-Install.bat
   ```

   It deploys the gatekeeper bundle to the Pi 2 and the capture bundle to
   the Pi 5, then writes the discovered MAC + IP back into the local
   files and pushes them back.

## Common imaging gotchas

| Symptom                                 | Likely cause / fix                                   |
|-----------------------------------------|------------------------------------------------------|
| `ping uap-pi2.local` fails              | mDNS not resolving on Windows. Install Bonjour Print Services, or find the Pi by IP via your router's DHCP page and use that IP with `-Pi2Host` / `-Pi5Host`. |
| SSH refuses with "permission denied"    | Pi Imager's "use public-key authentication only" was checked but the wrong pubkey was pasted. Re-image, or temporarily enable password auth. |
| Pi 5 doesn't see the Hailo HAT+         | `dtparam=pciex1_gen=3` not set, or HAT FFC ribbon orientation. Re-seat the ribbon, set the dtparam, reboot. |
| Wi-Fi country missing                   | Modern Pi OS won't bring up Wi-Fi without a country code. Set it in Pi Imager's Advanced Options. |
| Pi can join Wi-Fi but ssh times out     | Some routers isolate Wi-Fi clients from each other. Check "AP Isolation" / "Client Isolation" is OFF. |

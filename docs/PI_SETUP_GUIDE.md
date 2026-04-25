# Raspberry Pi Virgin Setup Guide — UAP Station

This guide walks through flashing and configuring two fresh Raspberry Pis for the UAP Station pipeline.

## Prerequisites

- [x] Raspberry Pi Imager v2.0.8 (already installed)
- [ ] 2x microSD cards (32 GB+ recommended)
- [ ] microSD card reader connected to PC
- [ ] Your Wi-Fi SSID and password

## Device Assignments

| Role | Hardware | Hostname | OS |
|------|----------|----------|----|
| Gatekeeper (UART listener) | Raspberry Pi 2 | `uap-pi2` | Raspberry Pi OS Lite (32-bit) |
| Capture/Inference Node | Raspberry Pi 5 | `uap-pi5` | Raspberry Pi OS (64-bit) |

---

## Step 1 — Flash Pi 2 SD Card

1. Insert the **Pi 2's microSD card** into your PC card reader.
2. Open **Raspberry Pi Imager** (Start Menu → "Raspberry Pi Imager").
3. Click **CHOOSE DEVICE** → select **Raspberry Pi 2**.
4. Click **CHOOSE OS** → **Raspberry Pi OS (other)** → **Raspberry Pi OS Lite (32-bit)**.
5. Click **CHOOSE STORAGE** → select your microSD card.
6. Click **NEXT**, then click **EDIT SETTINGS** when prompted.

### Settings to configure (OS Customisation):

**GENERAL tab:**
- ✅ Set hostname: `uap-pi2`
- ✅ Set username and password:
  - Username: `pi`
  - Password: choose a password (write it down!)
- ✅ Configure wireless LAN:
  - SSID: `Mango_Tango`
  - Password: `N3ll!3_06902`
  - Wireless LAN country: `US`
- ✅ Set locale settings:
  - Time zone: `America/New_York`
  - Keyboard layout: `us`

**SERVICES tab:**
- ✅ Enable SSH → Use password authentication

7. Click **SAVE**, then **YES** to apply settings.
8. Click **YES** to confirm writing (this erases the SD card).
9. Wait for write + verify to complete.
10. Remove the SD card and insert it into the Pi 2.

---

## Step 2 — Flash Pi 5 SD Card

1. Insert the **Pi 5's microSD card** into your PC card reader.
2. Open **Raspberry Pi Imager**.
3. Click **CHOOSE DEVICE** → select **Raspberry Pi 5**.
4. Click **CHOOSE OS** → **Raspberry Pi OS (64-bit)** (the default/top option).
5. Click **CHOOSE STORAGE** → select your microSD card.
6. Click **NEXT**, then click **EDIT SETTINGS**.

### Settings to configure (OS Customisation):

**GENERAL tab:**
- ✅ Set hostname: `uap-pi5`
- ✅ Set username and password:
  - Username: `pi`
  - Password: same password as Pi 2
- ✅ Configure wireless LAN:
  - SSID: `Mango_Tango`
  - Password: `N3ll!3_06902`
  - Wireless LAN country: `US`
- ✅ Set locale settings:
  - Time zone: `America/New_York`
  - Keyboard layout: `us`

**SERVICES tab:**
- ✅ Enable SSH → Use password authentication

7. Click **SAVE**, then **YES** to apply, then **YES** to write.
8. Wait for write + verify to complete.
9. Remove the SD card and insert it into the Pi 5.

---

## Step 3 — Boot Both Pis

1. Insert the flashed SD cards into each Pi.
2. Connect both Pis to power (and ethernet if available — faster than Wi-Fi for initial setup).
3. Wait **2-3 minutes** for first boot (the Pi will resize its filesystem, configure settings, and reboot once).

---

## Step 4 — Verify Connectivity

After both Pis have booted (~3 minutes), run from this PC:

```powershell
# Test mDNS resolution
ping uap-pi2.local
ping uap-pi5.local

# If .local doesn't work, check your router's DHCP client list for IPs
# Then test SSH:
ssh pi@uap-pi2.local
ssh pi@uap-pi5.local
```

> **Note:** If `.local` hostnames don't resolve, you can find the Pi IPs from your
> router admin page (typically http://192.168.4.1) under DHCP/Connected Devices.
> Then use IP addresses directly:
> ```powershell
> .\Install-UAPStation.ps1 -RunAll -Pi2Host 192.168.4.XX -Pi5Host 192.168.4.YY
> ```

---

## Step 5 — Run the Full Deployment

Once both Pis respond to SSH:

```powershell
cd "c:\Users\iansh\OneDrive\Documents\UAP Station"
.\Install-UAPStation.ps1 -RunAll
```

This will:
1. Compile and upload firmware to the AMB82-Mini
2. Deploy the gatekeeper daemon to Pi 2
3. Deploy the capture/inference pipeline to Pi 5
4. Sync IPs, MACs, and SSH keys across all devices

---

## AMB82-Mini Setup

The AMB82-Mini connects via **USB** to your PC for firmware upload.

### Troubleshooting "No boards found"
1. Ensure the USB cable is a **data cable** (not charge-only).
2. Try a different USB port.
3. Check Device Manager → **Ports (COM & LPT)** for a CH340/USB-Serial entry.
4. If no COM port appears, install the [CH340 driver](https://www.wch-ic.com/downloads/CH341SER_EXE.html).
5. After driver install, re-plug the AMB82 and verify a COM port appears.

### Verify AMB82 Detection
```powershell
.\arduino-cli\arduino-cli.exe board list
```
You should see a line with a COM port and "Unknown" or "AMB82-MINI" board type.

---

## Network Diagram

```
                    Wi-Fi (Mango_Tango)
                    ┌──────────────────┐
                    │    Router         │
                    │  192.168.4.1     │
                    └──┬───┬───┬───────┘
                       │   │   │
              ┌────────┘   │   └────────┐
              │            │            │
         ┌────┴────┐  ┌────┴────┐  ┌────┴────┐
         │  PC     │  │ Pi 2    │  │ Pi 5    │
         │ .4.43   │  │ uap-pi2 │  │ uap-pi5 │
         └────┬────┘  └────┬────┘  └─────────┘
              │            │
         USB  │       UART │ (GPIO wires)
              │            │
         ┌────┴────────────┴────┐
         │      AMB82-Mini      │
         │   (Camera + NPU)     │
         └──────────────────────┘
```

# AMB82-Mini firmware — setup & flashing

This directory contains the firmware for tier 1 of the UAP station: the Realtek
AMB82-Mini IoT AI camera. It runs YOLOv4-tiny on the on-chip 0.4 TOPS NPU,
streams H.264 over RTSP, and emits detection events as CSV over GPIO UART.

## Files

| File              | Purpose                                                  |
|-------------------|----------------------------------------------------------|
| `uap_station.ino` | Arduino sketch — Wi-Fi join, RTSP server, UART emitter.  |
| `README.md`       | This file.                                               |

## One-time PC setup (Windows)

1. **Install Arduino IDE 2.x.** https://www.arduino.cc/en/software
2. **Add the Realtek board manager URL.**
   File → Preferences → *Additional boards manager URLs* → paste:

   ```
   https://github.com/Ameba-AIoT/ameba-arduino-pro2/raw/main/Arduino_package/package_realtek_amebapro2_index.json
   ```

3. **Install the board package.** Tools → Board → Boards Manager → search
   "Realtek Ameba" → install *AmebaPro2 ARM (32-bits) Boards*.
4. **Select the board.** Tools → Board → AmebaPro2 ARM → **AMB82-MINI**.
5. **Plug the AMB82 into a PC USB port.** Windows usually mounts it as a
   COM device. If it doesn't appear, install the **CH341SER** driver
   (search "CH341SER driver" — Realtek's bootloader exposes a CH340/CH341
   USB-serial bridge).

### Finding which COM port is the AMB82 on Windows

Open PowerShell:

```powershell
Get-PnpDevice -Class Ports -PresentOnly |
    Select-Object Status, FriendlyName, InstanceId
```

Look for a `USB-SERIAL CH340 (COMx)` entry — that's the AMB82's bootloader.
Pick that COM port in Tools → Port in the Arduino IDE.

## Editing the sketch before flashing

Both credentials are already baked in:

```cpp
char ssid[] = "Mango_Tango";
char pass[] = "N3ll!3_06902";
```

No edits required — flash as-is.

> **Security note.** This file lives in OneDrive, which means your Wi-Fi
> password syncs to Microsoft's cloud and any other device signed into the
> same account. If you don't want that, either (a) move the firmware folder
> outside OneDrive, (b) replace the password with `YOUR_PASS` here and only
> fill it in temporarily before each flash, or (c) add `firmware/` to a
> `.gitignore` if you ever push this to a repo.

## Flashing

1. Connect AMB82 via USB to the PC.
2. In Arduino IDE: Tools → Port → pick the CH340 COM port.
3. **Hold UART_DOWNLOAD** on the board.
4. **Tap RESET.**
5. **Release UART_DOWNLOAD.**
6. Click **Upload** in the IDE (right-arrow icon).

(After the first successful upload, enable Tools → Auto Flash Mode to skip
the button dance on subsequent flashes.)

## Verifying

After flashing, open Serial Monitor at **115200 baud**. You should see:

```
WiFi connect retry...   (zero or more times, then)
AMB82 IP: 192.168.x.y
UAP station ready.
```

Write that IP down — `pi5/capture_uap.sh` needs it as `AMB82_RTSP`.

Test the RTSP stream from the PC with VLC:

* Media → Open Network Stream → `rtsp://<AMB82_IP>:554`
* You should see live camera video.

If RTSP doesn't open on `:554` directly, try `rtsp://<AMB82_IP>:554/live`.

## Wiring to Pi 2 (after bench upload is verified)

Once flashing works on a USB-connected PC, you can move to the field wiring.
The AMB82 keeps its own micro-USB power supply; the only wires between the
AMB82 and the Pi 2 are the **3-wire GPIO UART crossover**:

| Wire   | AMB82 pin              | Pi 2 physical pin     |
|--------|------------------------|-----------------------|
| yellow | D21 (PA2 / SERIAL1_TX) | 10 (GPIO15 / RXD)     |
| green  | D22 (PA3 / SERIAL1_RX) |  8 (GPIO14 / TXD)     |
| black  | GND                    |  6 (GND)              |

**TX/RX must crossover.** If the gatekeeper logs garbage or nothing, swap
the yellow and green wires — that's the most common bench failure.

## Phase 2 — motion delta path

The current sketch only emits YOLO events. The build guide §12 calls for an
additional motion-delta path on the RGB channel, emitting `MOTION,unknown`
events for things YOLO doesn't recognize. That's the whole point of the
system — keep this in mind when expanding the firmware.

# Bench verification

End-to-end smoke test before sealing anything in the enclosure. Each step
depends on the previous, so run them in order.

## 0. Prerequisites

* AMB82 flashed with `firmware/amb82/uap_station.ino`.
* Pi 2 set up via `pi2/install_pi2.sh` and rebooted.
* Pi 5 set up via `pi5/install_pi5.sh`.
* UART wiring per `docs/WIRING.md` (yellow/green/black).
* `PI5_MAC`, `PI5_HOST` filled in on Pi 2's gatekeeper.
* `AMB82_RTSP`, `PI2_HOST` filled in on Pi 5's `capture_uap.sh`.
* `ssh-copy-id pi@<PI5_HOST>` done from the Pi 2.

## 1. AMB82 boots and joins Wi-Fi

```
1. Power AMB82 (micro-USB).
2. Open Arduino IDE Serial Monitor at 115200 baud (or any serial term).
3. Expect:
       AMB82 IP: 192.168.x.y
       UAP station ready.
4. From the PC: open VLC -> Media -> Open Network Stream:
       rtsp://<AMB82_IP>:554
   Live camera video should appear.
```

If RTSP doesn't open, try `rtsp://<AMB82_IP>:554/live`.

## 2. Pi 2 sees UART events

Stop the systemd service and run the gatekeeper in the foreground so you
can see events live:

```bash
sudo systemctl stop uap-gatekeeper
sudo python3 /home/pi/uap_gatekeeper.py
```

In the AMB82's view, **wave a hand or hold up an object**. You should
see `EVT YOLO ...` lines in the gatekeeper output. The log file
`/home/pi/uap_logs/gatekeeper.log` accumulates them too.

If the gatekeeper sees garbage or nothing:
* TX/RX swap — swap yellow and green wires.
* Confirm both sides at 115200.
* Confirm AMB82 sketch uses `Serial1`, not `Serial`.

## 3. Force escalation

Edit `/home/pi/uap_gatekeeper.py` temporarily:

```python
MIN_EVENTS = 1
```

Wave again. Expect a `WAKE -> XX:XX:XX:XX:XX:XX` line.

## 4. Pi 5 receives the magic packet

On the Pi 5, in another terminal:

```bash
sudo tcpdump -i eth0 udp port 9
```

Trigger another wake from the AMB82 side. `tcpdump` should print one
packet line per wake. (Phase 1 the Pi 5 is already awake, so the WoL
packet is a confirmation rather than a true wake.)

## 5. Capture folder appears

After escalation:

```bash
ls /home/pi/uap_captures/
```

The latest folder should contain:

```
raw.mp4           # ~60s of H.264 from AMB82 RTSP
burst.json        # the events that triggered the wake
detections.jsonl  # Hailo output (empty until you wire the real pipeline)
ffmpeg.log
hailo.log
```

## 6. Restore production thresholds

Set `MIN_EVENTS` back to `3` in `/home/pi/uap_gatekeeper.py` and restart
the service:

```bash
sudo systemctl start uap-gatekeeper
sudo systemctl status uap-gatekeeper
tail -f /home/pi/uap_logs/gatekeeper.log
```

## Common bench failures

| Symptom                                   | Fix                                                              |
|-------------------------------------------|------------------------------------------------------------------|
| No EVT lines, just garbage characters     | TX/RX swap — swap yellow and green wires.                        |
| EVT lines arrive but parse() returns None | Both sides at 115200. AMB82 must use `Serial1`, not `Serial`.    |
| WoL sent but Pi 5 doesn't react           | Phase 1 expected: Pi 5 already awake. tcpdump confirms arrival.  |
| ffmpeg can't open RTSP                    | Try `rtsp://<ip>:554/live` instead of `rtsp://<ip>:554`.         |
| Hailo script errors on RTSP               | Most examples expect /dev/video* — use rtspsrc GStreamer or v4l2loopback. |

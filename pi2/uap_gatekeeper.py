#!/usr/bin/env python3
"""UAP gatekeeper — tier 2 of the detection station.

Reads CSV detection events from the AMB82-Mini over GPIO UART (`/dev/serial0`),
clusters them in a sliding window, filters out mundane labels, and on confirmed
escalation:
  * sends a Wake-on-LAN magic packet to the Pi 5
  * SSHes into the Pi 5 to launch the capture script with the burst metadata

Wiring assumed:
    AMB82 D21 (TX) -> Pi 2 phys pin 10 (GPIO15 / RXD)
    AMB82 D22 (RX) -> Pi 2 phys pin  8 (GPIO14 / TXD)
    AMB82 GND      -> Pi 2 phys pin  6 (GND)

Before running, on the Pi:
    sudo raspi-config
        Interface Options -> Serial Port
            login shell over serial?     -> No
            serial port hardware enabled? -> Yes
        sudo reboot
    sudo apt install -y python3-pip python3-serial wakeonlan ffmpeg

Then fill in PI5_MAC and PI5_HOST below from the Pi 5's `ip link show eth0`
and `hostname -I` output.
"""
from __future__ import annotations

import json
import logging
import subprocess
import time
import typing
from collections import deque
from pathlib import Path

import serial  # type: ignore

class DetectionEvent(typing.TypedDict):
    ts: int
    src: str
    score: float
    x: int
    y: int
    w: int
    h: int
    label: str

# --- configuration --------------------------------------------------------
SERIAL_PORT = "/dev/serial0"
BAUD = 115200

# >>> EDIT THESE TWO once the Pi 5 is on your network <<<
PI5_MAC = "XX:XX:XX:XX:XX:XX"
PI5_HOST = "192.168.1.50"
# -------------------------------------------------------

WAKE_COOLDOWN_SEC = 60
WINDOW_SEC = 5
MIN_EVENTS = 3
MIN_INTERESTING_SCORE = 0.50
EXCLUDE_LABELS = {"airplane", "bird", "kite"}

LOG_DIR = Path("/home/pi/uap_logs")
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    filename=LOG_DIR / "gatekeeper.log",
    level=logging.INFO,
    format="%(asctime)s %(message)s",
)
# --------------------------------------------------------------------------


def parse(line: str) -> DetectionEvent | None:
    """Parse one CSV detection line. Returns None on malformed input."""
    parts = line.strip().split(",")
    if len(parts) != 9 or parts[0] != "EVT":
        return None
    try:
        return {
            "ts": int(parts[1]),
            "src": parts[2],
            "score": float(parts[3]),
            "x": int(parts[4]),
            "y": int(parts[5]),
            "w": int(parts[6]),
            "h": int(parts[7]),
            "label": parts[8],
        }
    except ValueError:
        return None


def should_escalate(events: list[DetectionEvent]) -> bool:
    """Decide whether the current sliding-window burst warrants waking Pi 5."""
    interesting = [e for e in events if e["label"] not in EXCLUDE_LABELS]
    if len(interesting) < MIN_EVENTS:
        return False
    return any(e["score"] >= MIN_INTERESTING_SCORE for e in interesting)


def wake_pi5(events: list[DetectionEvent], state: dict[str, float]) -> None:
    """Send WoL magic packet, then SSH-trigger the capture script on Pi 5."""
    now = time.time()
    if now - state["last_wake"] < WAKE_COOLDOWN_SEC:
        logging.info("Skipping wake: cooldown")
        return
    state["last_wake"] = now

    subprocess.run(["wakeonlan", PI5_MAC], check=False)
    logging.info("WAKE -> %s", PI5_MAC)

    burst_file = LOG_DIR / f"burst_{int(now)}.json"
    burst_file.write_text(json.dumps(events, indent=2))

    # Give the Pi 5 a moment to come back from suspend (Phase 2). On Phase 1,
    # the Pi 5 is awake; this sleep just means we don't race the script.
    time.sleep(8)

    subprocess.run(
        [
            "ssh",
            "-o", "ConnectTimeout=5",
            "-o", "StrictHostKeyChecking=accept-new",
            f"pi@{PI5_HOST}",
            f"/home/pi/capture_uap.sh {burst_file.name}",
        ],
        check=False,
    )


def main() -> None:
    ser = serial.Serial(SERIAL_PORT, BAUD, timeout=1)
    recent: deque[tuple[float, DetectionEvent]] = deque()
    state = {"last_wake": 0.0}

    logging.info("Gatekeeper started on %s @ %d baud", SERIAL_PORT, BAUD)

    while True:
        line = ser.readline().decode(errors="ignore")
        if not line:
            continue

        evt = parse(line)
        if not evt:
            continue

        now = time.time()
        recent.append((now, evt))
        # Slide the window forward.
        while recent and now - recent[0][0] > WINDOW_SEC:
            recent.popleft()

        logging.info(
            "EVT %s %s score=%.2f", evt["src"], evt["label"], evt["score"]
        )

        events_in_window = [e for _, e in recent]
        if should_escalate(events_in_window):
            logging.info("ESCALATING %d events", len(recent))
            wake_pi5(events_in_window, state)
            recent.clear()


if __name__ == "__main__":
    main()


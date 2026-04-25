# Regression & Quality Assurance Plan

This document outlines the testing and validation criteria required before merging code into `main` for the **UAP Edge AI Station**.

## 1. Static Analysis & Linting
All Python scripts must adhere to strict type checking and PEP8 styling.

- **Type Checking:** `mypy --strict pi2/uap_gatekeeper.py pi5/hailo_infer.py`
- **Linting:** `flake8 pi2/ pi5/`
- **Formatting:** `black --check pi2/ pi5/`

*Criteria:* 0 Errors. Any `type: ignore` exceptions must be heavily documented.

## 2. Unit Testing Strategy
Target an **80% Minimum Coverage** metric. Tests should use `pytest`.

- **Tier 2 (Gatekeeper):**
  - Verify sliding window logic (`WINDOW_SEC`, `MIN_EVENTS`).
  - Verify exclusion filtering (`EXCLUDE_LABELS`).
  - Verify Wake-on-LAN cooldown timing logic.
- **Tier 3 (Hailo Inference):**
  - Mock RTSP inputs to ensure the bounding box JSON generation operates correctly.
  - Verify that GStreamer exception handling prevents system lockup.

## 3. Integration & Hardware Tests
Hardware integration testing is required before field deployment.

- **UART Cross-Over Verification:** 
  - *Goal:* Ensure the Pi 2 receives the exact CSV line emitted by the AMB82 without bit corruption.
  - *Test:* Inject mock anomalies on the AMB82, read `/dev/serial0` on the Pi 2.
- **Magic Packet Trigger:**
  - *Goal:* Verify Pi 5 transitions from `S5` (suspended) to fully booted via Pi 2 Wake-on-LAN.
  - *Test:* Run `wakeonlan <MAC>` on Pi 2 and ping Pi 5 until success.
- **SSH Escalation:**
  - *Goal:* Ensure the Pi 2 can execute remote commands on the Pi 5 without manual password prompts.
  - *Test:* `ssh pi@pi5.local "echo 'Authorized'"`

## 4. End-to-End User Journey (E2E)
- Flash both Pi 2 and Pi 5 with Virgin images using `Install-UAPStation.ps1`.
- Run the full PowerShell automated setup.
- Manually wave an anomalous test object (e.g., Drone) in front of the AMB82-Mini.
- Verify:
  1. AMB82 logs the detection.
  2. Pi 2 receives >3 events in 5 seconds and triggers Wake-on-LAN.
  3. Pi 5 wakes, starts the RTSP capture stream, and generates a valid `detections.jsonl` file via Hailo.

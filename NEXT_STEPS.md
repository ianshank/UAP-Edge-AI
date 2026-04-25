# Next Steps & Roadmap

This document captures the remaining technical objectives to reach full production stabilization for the **UAP Edge AI Station**.

## Phase 1: Pipeline Fortification
- [ ] **Hailo Inference Integration:** Replace the stub code in `pi5/hailo_infer.py` with the actual GStreamer bindings (`hailo_apps_infra.detection_pipeline.GStreamerDetectionApp`).
- [ ] **Unit Tests:** Construct the `tests/unit/` folder with Pytest modules for the Gatekeeper (`pi2`) logic, targeting 80% coverage.
- [ ] **Type-Driven Fortification:** Resolve any missing Mypy types or ambiguous Return signatures in the core Python execution loops.

## Phase 2: Hardware Stabilization
- [ ] **Network Rigidity:** Configure static DHCP leases or Avahi zero-conf stability to ensure `uap-pi5.local` and `uap-pi2.local` do not drift IP addresses, which breaks the SSH Escalation logic.
- [ ] **Power Management:** Confirm the Pi 5 sleep transition configurations so it actively suspends (and draws <0.5W) when the capture loop expires.

## Phase 3: Field Deployment
- [ ] **Field Tuning:** Follow `docs/BENCH_VERIFICATION.md` and complete the three-night tuning cycle.
- [ ] **Telemetry Dashboard:** Investigate publishing the JSONL events into a central metrics platform (e.g., Prometheus/Grafana or W&B) for remote performance monitoring without requiring shell access.
- [ ] **Enclosure Thermal Validation:** Ensure the Hailo-8L does not thermal throttle during extended bursts inside the sealed case.

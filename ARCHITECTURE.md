# Architecture

This document describes the architectural layout of the **UAP Edge AI Station**, using the C4 Model.

## C4 Context

The UAP Edge AI Station is a multi-tier physical detection mesh designed to capture, classify, and record anomalous aerial phenomena while minimizing idle power usage.

```mermaid
C4Context
    title System Context diagram for UAP Edge AI Station

    Person(user, "User / Operator", "Monitors and tunes the UAP Edge AI system.")
    System(uap_station, "UAP Edge AI Station", "Detects anomalies, triggers recordings, and runs deep inference.")
    
    Rel(user, uap_station, "Deploys, monitors logs, and reviews recorded captures")
```

## C4 Container

The core system consists of three distinct hardware tiers operating in a staggered, event-driven escalation pipeline to conserve power while maximizing inference performance during bursts.

```mermaid
C4Container
    title Container diagram for UAP Edge AI Station

    Container_Boundary(tier1, "Tier 1: Edge Sensor") {
        Container(amb82, "AMB82-Mini Vision Node", "C++ / Arduino", "Runs initial, lightweight YOLO detection. Broadcasts raw events via GPIO UART.")
    }

    Container_Boundary(tier2, "Tier 2: Gatekeeper") {
        Container(pi2, "Raspberry Pi 2 W", "Python / systemd", "Always-on, low-power listener. Aggregates UART events in a sliding window. Sends WoL if criteria met.")
    }

    Container_Boundary(tier3, "Tier 3: Heavy Analytics") {
        Container(pi5, "Raspberry Pi 5 + Hailo-8L", "Python / GStreamer", "Usually suspended. Wakes on WoL, captures RTSP stream, and runs heavy Hailo inference.")
    }

    Rel(amb82, pi2, "Sends CSV detection events", "GPIO UART (115200 baud)")
    Rel(pi2, pi5, "Triggers Wake-on-LAN", "Magic Packet")
    Rel(pi2, pi5, "Invokes Capture Script", "SSH")
    Rel(pi5, amb82, "Pulls RTSP Video Stream", "TCP/UDP")
```

## Hardware Interfaces
- **AMB82-Mini ↔ Pi 2 W:** 3-Wire GPIO Crossover (`D21 -> RXD`, `D22 -> TXD`, `GND -> GND`).
- **Pi 2 ↔ Pi 5:** Local Network (Ethernet / WiFi) with Static DHCP for Magic Packet target consistency.
- **Power Delivery:** Separate 5V/3A+ delivery to Pi 5; low-current draw for AMB82 and Pi 2 W.

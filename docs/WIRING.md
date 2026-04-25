# Wiring

## UART crossover — AMB82-Mini ↔ Raspberry Pi 2

Both boards run 3.3 V logic. **No level shifter required.** TX/RX must
crossover (TX on one side connects to RX on the other).

```
                  AMB82-Mini                   Raspberry Pi 2
                ┌───────────────┐              ┌─────────────────────┐
                │               │              │  Physical pin layout │
                │           D21 ●──── yellow ──● 10  GPIO15 / RXD     │
                │           D22 ●──── green  ──●  8  GPIO14 / TXD     │
                │           GND ●──── black  ──●  6  GND              │
                │               │              │                     │
                │ (powered via  │              │ (powered via        │
                │  micro-USB)   │              │  micro-USB,         │
                │               │              │  Cat5e to router)   │
                └───────────────┘              └─────────────────────┘

   yellow = AMB82 TX -> Pi 2 RX  (events flowing AMB → Pi)
   green  = AMB82 RX <- Pi 2 TX  (commands future-use)
   black  = common ground

   *** TX/RX must crossover. Swap yellow & green if logs are garbage. ***
```

## Power domains

Three independent 5 V rails. **Do not share rails between boards.** The
only electrical link between AMB82 and Pi 2 is the shared UART ground.

```
   12 V outdoor PSU
        │
        ├─[ buck 12→5V ]──► AMB82 micro-USB (≈1 W)
        │
        └─[ buck 12→5V ]──► Pi 2 micro-USB  (≈3 W)

   Indoors:
        Wall ──► Pi 5 official 27 W USB-C PSU (≈10 W active, ≈0.5 W idle)
```

## Network topology

```
          ┌──────────────┐                          ┌──────────────┐
          │   AMB82      │  Wi-Fi 2.4GHz            │  Your router │
          │  (outdoor)   │ ────────────────────────►│              │
          └──────┬───────┘                          │              │
                 │ UART                             │              │
                 │ (3 wires)                        │              │
                 ▼                                  │              │
          ┌──────────────┐  Cat5e                   │              │
          │   Pi 2       │──────────────────────────►              │
          │  (outdoor)   │                          │              │
          └──────────────┘                          │              │
                                                    │              │
          ┌──────────────┐  Cat5e                   │              │
          │   Pi 5 +     │◄─────────────────────────┤              │
          │   Hailo-8L   │      (WoL targets MAC)   │              │
          │  (indoor)    │                          └──────────────┘
          └──────────────┘
```

Pi 2 and Pi 5 must have **static DHCP leases** so the gatekeeper's
hardcoded `PI5_HOST` and the capture script's hardcoded `PI2_HOST` keep
resolving correctly across reboots.

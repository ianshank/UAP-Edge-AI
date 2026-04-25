#!/bin/bash
# install_pi2.sh — one-shot setup for the UAP gatekeeper on a fresh Pi 2.
#
# Run as the `pi` user with sudo available:
#   chmod +x install_pi2.sh
#   ./install_pi2.sh
#
# This script:
#   1. Frees the GPIO UART by disabling the serial login shell (idempotent).
#   2. Installs apt deps.
#   3. Drops uap_gatekeeper.py into /home/pi/.
#   4. Generates an SSH key (if missing) for the Pi 2 -> Pi 5 hop.
#   5. Installs and enables the systemd unit.
#
# It does NOT edit PI5_MAC / PI5_HOST in the gatekeeper for you — you'll be
# prompted to do that at the end before the service can usefully escalate.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_HOME="/home/pi"

echo "==> Updating apt and installing dependencies"
sudo apt update
sudo apt install -y python3-pip python3-serial wakeonlan ffmpeg openssh-client

echo "==> Configuring UART (disable serial login shell, keep hardware UART on)"
# raspi-config nonint commands are stable across recent Pi OS releases.
#   do_serial_hw 0  = enable hardware UART
#   do_serial_cons 1 = disable login shell on serial
if command -v raspi-config >/dev/null 2>&1; then
    sudo raspi-config nonint do_serial_hw 0   || true
    sudo raspi-config nonint do_serial_cons 1 || true
else
    echo "   raspi-config not found — edit /boot/firmware/config.txt manually:"
    echo "     enable_uart=1"
    echo "   and remove 'console=serial0,115200' from /boot/firmware/cmdline.txt."
fi

echo "==> Installing gatekeeper script"
install -m 0755 "$HERE/uap_gatekeeper.py" "$PI_HOME/uap_gatekeeper.py"
mkdir -p "$PI_HOME/uap_logs"
chown -R pi:pi "$PI_HOME/uap_logs" "$PI_HOME/uap_gatekeeper.py"

echo "==> Ensuring SSH key exists for pi -> Pi 5 hop"
if [[ ! -f "$PI_HOME/.ssh/id_ed25519" ]]; then
    sudo -u pi ssh-keygen -t ed25519 -N "" -f "$PI_HOME/.ssh/id_ed25519"
    echo "   New key generated. After Pi 5 is up, run:"
    echo "     ssh-copy-id pi@<PI5_HOST>"
else
    echo "   SSH key already present at $PI_HOME/.ssh/id_ed25519"
fi

echo "==> Installing systemd unit"
sudo cp "$HERE/uap-gatekeeper.service" /etc/systemd/system/uap-gatekeeper.service
sudo systemctl daemon-reload
sudo systemctl enable uap-gatekeeper

cat <<'EOF'

==> install_pi2.sh complete.

Next steps (manual):
  1. Reboot:                 sudo reboot
  2. Find the Pi 5's MAC/IP and put them into:
                             /home/pi/uap_gatekeeper.py
       (PI5_MAC and PI5_HOST near the top)
  3. Push your SSH key:      ssh-copy-id pi@<PI5_HOST>
  4. Bench-verify per docs/BENCH_VERIFICATION.md.
  5. Start the service:      sudo systemctl start uap-gatekeeper
  6. Watch logs:             tail -f /home/pi/uap_logs/gatekeeper.log
EOF

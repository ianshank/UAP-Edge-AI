#!/bin/bash
# install_pi5.sh — one-shot setup for the Pi 5 + Hailo-8L capture node.
#
# Run as the `pi` user with sudo available:
#   chmod +x install_pi5.sh
#   ./install_pi5.sh
#
# This script:
#   1. Installs apt deps (ffmpeg, ethtool, openssh-server, python3-gi).
#   2. Installs the Hailo HAT+ runtime via the official Raspberry Pi
#      AI HAT+ packages.
#   3. Enables Wake-on-LAN on eth0 and persists across reboots.
#   4. Drops capture_uap.sh and hailo_infer.py into /home/pi/.
#   5. Prints the MAC address and IP for entry into the Pi 2's gatekeeper.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_HOME="/home/pi"

echo "==> Updating apt and installing dependencies"
sudo apt update
sudo apt install -y \
    ffmpeg ethtool openssh-server \
    python3-pip python3-gi gir1.2-gstreamer-1.0 \
    gstreamer1.0-tools gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav

echo "==> Installing Hailo HAT+ runtime"
# Raspberry Pi OS Bookworm carries the hailo packages directly. If you're
# on a slightly older image the package names may differ; in that case
# follow https://github.com/hailo-ai/hailo-rpi5-examples for the manual
# install path.
sudo apt install -y hailo-all || {
    echo "   hailo-all not in apt — falling back to manual instructions:"
    echo "   1) git clone https://github.com/hailo-ai/hailo-rpi5-examples"
    echo "   2) cd hailo-rpi5-examples && ./install.sh"
}

echo "==> Enabling Wake-on-LAN on eth0"
sudo ethtool -s eth0 wol g || true

# Persist across reboots — networkd-dispatcher hook fires on every link
# (re)configuration.
sudo install -d /etc/networkd-dispatcher/configuring.d
sudo tee /etc/networkd-dispatcher/configuring.d/wol >/dev/null <<'EOF'
#!/bin/sh
/usr/sbin/ethtool -s eth0 wol g
EOF
sudo chmod +x /etc/networkd-dispatcher/configuring.d/wol

echo "==> Verifying WoL setting"
sudo ethtool eth0 | grep -E "Wake-on" || true

echo "==> Installing capture script and Hailo wrapper"
install -m 0755 "$HERE/capture_uap.sh"  "$PI_HOME/capture_uap.sh"
install -m 0755 "$HERE/hailo_infer.py"  "$PI_HOME/hailo_infer.py"
mkdir -p "$PI_HOME/uap_captures"
chown -R pi:pi "$PI_HOME/uap_captures" \
               "$PI_HOME/capture_uap.sh" \
               "$PI_HOME/hailo_infer.py"

echo "==> Network info to copy into the Pi 2 gatekeeper"
echo
echo "   MAC (PI5_MAC):  $(ip link show eth0 | awk '/ether/ {print $2}')"
echo "   IP  (PI5_HOST): $(hostname -I | awk '{print $1}')"
echo

cat <<'EOF'
==> install_pi5.sh complete.

Next steps (manual):
  1. Reserve a static DHCP lease on your router for the Pi 5
     (WoL packets target a specific MAC + IP).
  2. From the Pi 2: ssh-copy-id pi@<this Pi 5 IP>.
  3. Edit /home/pi/capture_uap.sh on this Pi:
       AMB82_RTSP -> the AMB82's IP from its serial monitor
       PI2_HOST   -> the Pi 2's IP
  4. Replace the stub in /home/pi/hailo_infer.py with a real Hailo
     pipeline call (see comments in the file).
  5. From the Pi 2, run a test:
       /home/pi/capture_uap.sh test_burst.json
     A new folder under /home/pi/uap_captures/ should appear.
EOF

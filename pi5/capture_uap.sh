#!/bin/bash
# capture_uap.sh — tier 3 capture trigger.
#
# Called by the Pi 2 gatekeeper over SSH on confirmed escalation. Pulls the
# burst metadata from the Pi 2, records 60 s of RTSP from the AMB82, and
# runs the Hailo-8L inference pipeline against the same RTSP source.
#
# Args:
#   $1 — burst filename (e.g. burst_1714061234.json) — looked up under
#        pi@${PI2_HOST}:/home/pi/uap_logs/
#
# Usage from gatekeeper:
#   ssh pi@<PI5_HOST> "/home/pi/capture_uap.sh burst_1714061234.json"

set -e

BURST="$1"
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT=/home/pi/uap_captures/$TS
mkdir -p "$OUT"

# >>> EDIT THESE TWO to match your network <<<
AMB82_RTSP="rtsp://192.168.1.42:554"
PI2_HOST="192.168.1.41"
# --------------------------------------------

DURATION=60   # seconds

# Pull the burst metadata from the Pi 2 (best effort — don't fail capture
# if the metadata file is missing).
if [[ -n "$BURST" ]]; then
    scp -o StrictHostKeyChecking=accept-new \
        "pi@${PI2_HOST}:/home/pi/uap_logs/${BURST}" \
        "$OUT/burst.json" || true
fi

# Record raw H.264 from the AMB82 RTSP stream.
ffmpeg -y -rtsp_transport tcp -i "$AMB82_RTSP" \
    -t "$DURATION" -c copy "$OUT/raw.mp4" >>"$OUT/ffmpeg.log" 2>&1 &
FFPID=$!

# Run the Hailo inference path against the same RTSP source. Output is
# JSONL, one detection per line: {ts, label, score, bbox}.
python3 /home/pi/hailo_infer.py \
    --rtsp "$AMB82_RTSP" \
    --duration "$DURATION" \
    --out "$OUT/detections.jsonl" >>"$OUT/hailo.log" 2>&1

wait $FFPID
echo "Capture complete: $OUT" | systemd-cat -t uap-capture

# Phase 2: re-enable suspend after a quiet period.
#   sudo systemctl suspend


#!/usr/bin/env python3
"""hailo_infer.py — Hailo-8L inference over an RTSP source.

Template script. The Hailo apps repo ships an ``rtsp_source`` example —
this file is structured to be the smallest reasonable wrapper around it
that produces JSONL output suitable for archival alongside the recorded
clip.

Inputs:
  --rtsp     RTSP URL of the AMB82 stream
  --duration seconds to run (matches capture_uap.sh)
  --out      JSONL output path: {ts, label, score, bbox} per detection

Notes / TODO:
  * Most Hailo examples expect /dev/video* — to feed RTSP you typically
    use a GStreamer pipeline with `rtspsrc location=<url> ! ...`. The
    simplest path is to plug the URL into the example pipeline string.
  * Alternatively, pipe ffmpeg into v4l2loopback (creates /dev/video10),
    then point the example at that loopback device.
  * The skeleton below uses GStreamer through the Hailo Python bindings.
    Replace ``run_pipeline`` with whatever the Hailo repo's RTSP example
    looks like at the time you set this up.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--rtsp", required=True, help="RTSP URL of AMB82 stream")
    p.add_argument("--duration", type=int, default=60,
                   help="Seconds to run inference")
    p.add_argument("--out", required=True, help="JSONL output path")
    p.add_argument("--model", default="yolov8s",
                   help="Hailo model name (yolov8s, yolov8m, custom, ...)")
    return p.parse_args()


def emit(out_fh, label: str, score: float, bbox: tuple[int, int, int, int]):
    """Write one detection as a JSON line."""
    out_fh.write(json.dumps({
        "ts": time.time(),
        "label": label,
        "score": float(score),
        "bbox": list(bbox),  # [x, y, w, h]
    }) + "\n")
    out_fh.flush()


def run_pipeline(args: argparse.Namespace, out_fh) -> None:
    """Drop-in point for the Hailo example pipeline.

    Replace this stub with a real pipeline call. A working starting point
    is the ``detection_app`` example from the hailo-rpi5-examples repo:

        from hailo_apps_infra.detection_pipeline import GStreamerDetectionApp
        app = GStreamerDetectionApp(
            input_source=args.rtsp,
            user_callback=lambda buf, det: emit(out_fh, det.label,
                                                det.score, det.bbox),
            hef_path=f"/usr/share/hailo/{args.model}.hef",
        )
        app.run(timeout=args.duration)
    """
    # Until the real pipeline is wired up, just log the intent and exit
    # cleanly so capture_uap.sh still produces a coherent capture folder
    # (raw.mp4 + burst.json + an empty detections.jsonl).
    sys.stderr.write(
        f"[hailo_infer] Stub running for {args.duration}s on {args.rtsp}.\n"
        f"[hailo_infer] Replace run_pipeline() with the real Hailo app.\n"
    )
    time.sleep(args.duration)


def main() -> int:
    args = parse_args()
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w") as fh:
        run_pipeline(args, fh)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

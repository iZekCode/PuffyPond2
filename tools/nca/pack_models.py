"""Pack trained NCA models into the one file the app loads (PuffyPond/NCA/octopus.bin).

Layout (float32, little-endian): the weights of every model in order (each 5856 floats, as nca.bin), then every
model's mean colour as 4 floats (r, g, b, 0). The order must match Paint.colors in Toybox.swift.

Usage:
  python pack_models.py PuffyPond/NCA/octopus.bin runs/octopus/red runs/octopus/blue runs/octopus/yellow \
      runs/octopus/pink runs/octopus/green runs/octopus/purple
"""
import json
import sys
from pathlib import Path

import numpy as np

WEIGHTS = 5856


def main():
    out, runs = Path(sys.argv[1]), [Path(p) for p in sys.argv[2:]]
    weights, means = [], []
    for run in runs:
        w = np.fromfile(run / "nca.bin", dtype="<f4")
        if w.size != WEIGHTS:
            sys.exit(f"{run}: expected {WEIGHTS} floats, got {w.size}")
        weights.append(w)
        mean = json.loads((run / "nca.json").read_text())["meanRGB"]
        means.append(np.array([*mean, 0.0], dtype="<f4"))
    blob = np.concatenate(weights + means).astype("<f4")
    out.write_bytes(blob.tobytes())
    print(f"{len(runs)} models -> {out} ({blob.size} floats, {out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()

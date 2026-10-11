#!/usr/bin/env python3
"""Compare rendered screenshots against blessed references.

Usage:
  nix-shell --run "tests/compare.py [--reference tests/reference] [--current out] [--threshold 0.02]"

Metric: normalized RMSE over RGB (0.0 = identical, 1.0 = black vs white).
Fails (exit 1) if any image is missing, size differs, or RMSE > threshold.
Writes diff images next to the current file as diff-<name>.png on failure.
"""
import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def rmse(a: Image.Image, b: Image.Image) -> float:
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
    stat = ImageStat.Stat(diff)
    # mean square across bands, then root, normalized to 0..1
    mse = sum(v * v for v in stat.mean) / len(stat.mean)
    return math.sqrt(mse) / 255.0


def diff_ratio(a: Image.Image, b: Image.Image, tol: int = 8) -> float:
    """Fraction of pixels whose per-pixel max channel diff exceeds tol."""
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
    px = diff.load()
    w, h = diff.size
    bad = 0
    for y in range(h):
        for x in range(w):
            if max(px[x, y]) > tol:
                bad += 1
    return bad / (w * h)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--reference", default="tests/reference")
    ap.add_argument("--current", default="out")
    ap.add_argument("--threshold", type=float, default=0.01)
    args = ap.parse_args()

    ref_dir = Path(args.reference)
    cur_dir = Path(args.current)
    refs = sorted(ref_dir.glob("*.png"))
    if not refs:
        print(f"no reference PNGs in {ref_dir}", file=sys.stderr)
        return 1

    failed = 0
    for ref in refs:
        cur = cur_dir / ref.name
        if not cur.exists():
            print(f"FAIL {ref.name}: missing {cur}")
            failed += 1
            continue
        with Image.open(ref) as ri, Image.open(cur) as ci:
            if ri.size != ci.size:
                print(f"FAIL {ref.name}: size {ri.size} != {ci.size}")
                failed += 1
                continue
            score = rmse(ri, ci)
            ratio = diff_ratio(ri, ci)
            status = "PASS" if score <= args.threshold else "FAIL"
            print(f"{status} {ref.name}: RMSE={score:.4f} diff-pixels={ratio*100:.2f}%")
            if score > args.threshold:
                failed += 1
                # red-amplified diff for eyeballing
                diff = ImageChops.difference(ri.convert("RGB"), ci.convert("RGB"))
                diff.save(cur_dir / f"diff-{ref.name}")
                print(f"  wrote {cur_dir / ('diff-' + ref.name)}")
    print(f"{len(refs)-failed}/{len(refs)} passed (threshold RMSE<={args.threshold})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

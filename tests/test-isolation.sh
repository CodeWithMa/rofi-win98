#!/usr/bin/env bash
# Verify host desktop entries cannot affect either backend's fixture renders.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

for backend in x11 wayland; do
  out="$REPO_ROOT/out/isolation-$backend"
  XDG_DATA_HOME="$SCRIPT_DIR/fixtures/user-data" \
    "$SCRIPT_DIR/render.sh" --backend "$backend" --out "$out"
  "$SCRIPT_DIR/compare.py" --reference "$SCRIPT_DIR/reference" --current "$out"
done

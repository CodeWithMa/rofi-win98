#!/usr/bin/env bash
# Render win98.rasi under a virtual X server and screenshot it.
# Usage:
#   nix-shell --run "tests/render.sh [--out DIR] [--theme FILE]"
# If $DISPLAY is unset the script re-execs itself under xvfb-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
THEME="$REPO_ROOT/win98.rasi"
OUT="$REPO_ROOT/out"
ENTRIES="$SCRIPT_DIR/entries.txt"
FIXTURES="$SCRIPT_DIR/fixtures"
RES="1280x800x24"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Re-exec under Xvfb when there is no display (local runs, CI without X).
if [[ -z "${DISPLAY:-}" && -z "${UNDER_XVFB:-}" ]]; then
  exec xvfb-run -a -s "-screen 0 $RES" env UNDER_XVFB=1 "$0" --out "$OUT" --theme "$THEME"
fi

mkdir -p "$OUT"

echo "== lint theme =="
rofi -no-config -theme "$THEME" -dump-theme > /dev/null
echo "theme parses OK: $THEME"

# Centered location needs a WM; start openbox if none is running.
STARTED_OPENBOX=""
if ! pgrep -x openbox > /dev/null 2>&1; then
  echo "== starting openbox =="
  openbox > "$OUT/openbox.log" 2>&1 &
  STARTED_OPENBOX=$!
  sleep 1
fi

cleanup() {
  pkill -x rofi 2>/dev/null || true
  if [[ -n "$STARTED_OPENBOX" ]]; then
    kill "$STARTED_OPENBOX" 2>/dev/null || true
  fi
}
trap cleanup EXIT

wait_for_render() {
  # Rofi's window is not reliably found via xdotool (override-redirect /
  # unnamed in v2.0), so wait a fixed beat for map + font settle.
  # Rendering is deterministic; 1.5s is plenty under Xvfb.
  sleep 1.5
}

render_case() {
  local name="$1"; shift
  local title="rofi-test-$name"
  echo "== rendering $name =="
  pkill -x rofi 2>/dev/null || true
  sleep 0.2
  # shellcheck disable=SC2086
  rofi -no-config -theme "$THEME" \
    -dmenu -i -no-custom -sync -l 5 -p "Run" \
    -show-icons false -normal-window \
    -window-title "$title" $* < "$ENTRIES" > /dev/null 2> "$OUT/rofi-$name.log" &
  local pid=$!
  wait_for_render
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "rofi exited early for $name, log:" >&2
    cat "$OUT/rofi-$name.log" >&2 || true
    return 1
  fi
  maim -u "$OUT/$name.png"
  echo "wrote $OUT/$name.png"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  sleep 0.3
}

render_drun_case() {
  local name="$1"; shift
  local title="rofi-test-$name"
  echo "== rendering $name (drun) =="
  pkill -x rofi 2>/dev/null || true
  sleep 0.2
  # Isolate desktop entries so renders are deterministic: fixtures only,
  # plus icon theme dirs (chicago95) for icons, excluding host applications.
  # -drun-categories excludes the Nix wrapper's own category-less
  # rofi.desktop entries, which --prefix injects via XDG_DATA_DIRS.
  local drun_data_dirs="$FIXTURES"
  local IFS=':'
  for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    case "$d" in
      *chicago95*|*hicolor*|*Adwaita*|*adwaita*)
        drun_data_dirs="$drun_data_dirs:$d"
        ;;
    esac
  done
  unset IFS
  # shellcheck disable=SC2086
  XDG_DATA_DIRS="$drun_data_dirs" \
  XDG_CACHE_HOME="$OUT/cache-$name" \
    rofi -no-config -theme "$THEME" \
    -show drun -modi drun -i -l 5 \
    -show-icons -disable-history -sort \
    -drun-categories Utility,Network \
    -cache-dir "$OUT/cache-$name" -normal-window \
    -window-title "$title" $* > /dev/null 2> "$OUT/rofi-$name.log" &
  local pid=$!
  wait_for_render
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "rofi exited early for $name, log:" >&2
    cat "$OUT/rofi-$name.log" >&2 || true
    return 1
  fi
  maim -u "$OUT/$name.png"
  echo "wrote $OUT/$name.png"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  sleep 0.3
}

render_case dmenu -selected-row 0
render_case dmenu-selected -selected-row 2
render_drun_case drun -selected-row 0
render_drun_case drun-selected -selected-row 2

echo "done. screenshots in $OUT"
ls -lh "$OUT"/*.png

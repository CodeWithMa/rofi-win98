#!/usr/bin/env bash
# Render win98.rasi under a virtual X server and screenshot it.
# Usage:
#   nix-shell --run "tests/render.sh [--out DIR] [--theme FILE]"
# Always re-exec under a dedicated xvfb-run display.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
THEME="$REPO_ROOT/win98.rasi"
OUT="$REPO_ROOT/out"
ENTRIES="$SCRIPT_DIR/entries.txt"
FIXTURES="$SCRIPT_DIR/fixtures"
RES="1280x800x24"
UNDER_XVFB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --under-xvfb) UNDER_XVFB=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Use a fresh X display even when launched from an existing desktop session.
if [[ -z "$UNDER_XVFB" ]]; then
  exec xvfb-run -a -s "-screen 0 $RES" env -u WAYLAND_DISPLAY "$0" --under-xvfb --out "$OUT" --theme "$THEME"
fi

mkdir -p "$OUT"

echo "== lint theme =="
rofi -no-config -theme "$THEME" -dump-theme > /dev/null
echo "theme parses OK: $THEME"

ROFI_PID=""
STARTED_OPENBOX=""
# Each renderer uses an output-local pidfile so a desktop launcher can stay open.

stop_rofi() {
  if [[ -n "$ROFI_PID" ]]; then
    kill "$ROFI_PID" 2>/dev/null || true
    wait "$ROFI_PID" 2>/dev/null || true
    ROFI_PID=""
  fi
}

cleanup() {
  stop_rofi
  if [[ -n "$STARTED_OPENBOX" ]]; then
    kill "$STARTED_OPENBOX" 2>/dev/null || true
    wait "$STARTED_OPENBOX" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Centered location needs a WM on this test display.
echo "== starting openbox =="
openbox > "$OUT/openbox.log" 2>&1 &
STARTED_OPENBOX=$!
sleep 1

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
  rofi -no-config -theme "$THEME" \
    -pid "$OUT/rofi.pid" \
    -dmenu -i -no-custom -sync -l 5 -p "Run" \
    -show-icons false -normal-window \
    -window-title "$title" "$@" < "$ENTRIES" > /dev/null 2> "$OUT/rofi-$name.log" &
  local pid=$!
  ROFI_PID="$pid"
  wait_for_render
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "rofi exited early for $name, log:" >&2
    cat "$OUT/rofi-$name.log" >&2 || true
    return 1
  fi
  maim -u "$OUT/$name.png"
  echo "wrote $OUT/$name.png"
  stop_rofi
  sleep 0.3
}

render_drun_case() {
  local name="$1"; shift
  local title="rofi-test-$name"
  echo "== rendering $name (drun) =="
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
      *)
        # Keep font-only dirs so Pango still resolves the theme fonts
        # (e.g. Terminus from nix-shell): fontconfig discovers Nix fonts
        # via XDG_DATA_DIRS, and stripping them makes drun renders fall
        # back to DejaVu Sans. Skip dirs shipping .desktop entries so the
        # listing stays deterministic (fixtures only).
        # shellcheck disable=SC2086
        if [[ -d "$d/fonts" ]] && ! compgen -G "$d/applications/*.desktop" > /dev/null; then
          drun_data_dirs="$drun_data_dirs:$d"
        fi
        ;;
    esac
  done
  unset IFS
  XDG_DATA_DIRS="$drun_data_dirs" \
  XDG_CACHE_HOME="$OUT/cache-$name" \
    rofi -no-config -theme "$THEME" \
    -pid "$OUT/rofi.pid" \
    -show drun -modi drun -i -l 5 \
    -show-icons -disable-history -sort \
    -drun-categories Utility,Network \
    -cache-dir "$OUT/cache-$name" -normal-window \
    -window-title "$title" "$@" > /dev/null 2> "$OUT/rofi-$name.log" &
  local pid=$!
  ROFI_PID="$pid"
  wait_for_render
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "rofi exited early for $name, log:" >&2
    cat "$OUT/rofi-$name.log" >&2 || true
    return 1
  fi
  maim -u "$OUT/$name.png"
  echo "wrote $OUT/$name.png"
  stop_rofi
  sleep 0.3
}

render_case dmenu -selected-row 0
render_case dmenu-selected -selected-row 2
render_drun_case drun -selected-row 0
render_drun_case drun-selected -selected-row 2

echo "done. screenshots in $OUT"
ls -lh "$OUT"/*.png

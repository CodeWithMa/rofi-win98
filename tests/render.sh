#!/usr/bin/env bash
# Render win98.rasi under an isolated X11 or Wayland display and screenshot it.
# Usage:
#   nix-shell --run "tests/render.sh [--backend x11|wayland] [--out DIR] [--theme FILE]"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
THEME="$REPO_ROOT/win98.rasi"
OUT=""
BACKEND=x11
ENTRIES="$SCRIPT_DIR/entries.txt"
FIXTURES="$SCRIPT_DIR/fixtures"
RES="1280x800x24"
UNDER_XVFB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --backend) BACKEND="$2"; shift 2 ;;
    --under-xvfb) UNDER_XVFB=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$BACKEND" in
  x11) OUT="${OUT:-$REPO_ROOT/out}" ;;
  wayland) OUT="${OUT:-$REPO_ROOT/out/wayland}" ;;
  *) echo "unknown backend: $BACKEND (expected x11 or wayland)" >&2; exit 2 ;;
esac

# Use a fresh X display even when launched from an existing desktop session.
if [[ "$BACKEND" == x11 && -z "$UNDER_XVFB" ]]; then
  exec xvfb-run -a -s "-screen 0 $RES" env -u WAYLAND_DISPLAY "$0" --under-xvfb --out "$OUT" --theme "$THEME"
fi

mkdir -p "$OUT"

ROFI_PID=""
DISPLAY_PID=""
RUNTIME_DIR=""
ROFI_DISPLAY_ARGS=()
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
  if [[ -n "$DISPLAY_PID" ]]; then
    kill "$DISPLAY_PID" 2>/dev/null || true
    wait "$DISPLAY_PID" 2>/dev/null || true
  fi
  if [[ -n "$RUNTIME_DIR" ]]; then
    rm -rf "$RUNTIME_DIR"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$BACKEND" == x11 ]]; then
  # Centered location needs a WM on this test display.
  echo "== starting openbox =="
  openbox > "$OUT/openbox.log" 2>&1 &
  DISPLAY_PID=$!
  ROFI_DISPLAY_ARGS=(-normal-window)
  sleep 1
else
  echo "== starting headless sway =="
  RUNTIME_DIR=$(mktemp -d)
  export XDG_RUNTIME_DIR="$RUNTIME_DIR"
  unset DISPLAY WAYLAND_DISPLAY SWAYSOCK
  WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_HEADLESS_OUTPUTS=1 \
    WLR_LIBINPUT_NO_DEVICES=1 \
    sway --unsupported-gpu -c "$SCRIPT_DIR/sway.conf" > "$OUT/sway.log" 2>&1 &
  DISPLAY_PID=$!
  # Wait for this compositor's socket, never the caller's Wayland session.
  for ((attempt=0; attempt<100; attempt++)); do
    for socket in "$RUNTIME_DIR"/wayland-*; do
      if [[ -S "$socket" ]]; then
        export WAYLAND_DISPLAY="${socket##*/}"
        break 2
      fi
    done
    if ! kill -0 "$DISPLAY_PID" 2>/dev/null; then
      echo "sway exited early, log:" >&2
      cat "$OUT/sway.log" >&2
      exit 1
    fi
    sleep 0.1
  done
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "timed out waiting for sway, log:" >&2
    cat "$OUT/sway.log" >&2
    exit 1
  fi
fi

echo "== lint theme ($BACKEND) =="
rofi -no-config -theme "$THEME" -dump-theme > /dev/null
echo "theme parses OK: $THEME"

screenshot() {
  if [[ "$BACKEND" == x11 ]]; then
    maim -u "$1"
  else
    grim -o HEADLESS-1 "$1"
  fi
}

wait_for_render() {
  # Rofi's window is not reliably found via xdotool (override-redirect /
  # unnamed in v2.0), so wait a fixed beat for map + font settle.
  # Allow map + font settle on either backend before capturing the output.
  sleep 1.5
}

render_case() {
  local name="$1"; shift
  local title="rofi-test-$name"
  echo "== rendering $name =="
  rofi -no-config -theme "$THEME" \
    -pid "$OUT/rofi.pid" \
    -dmenu -i -no-custom -sync -l 5 -p "Run" \
    -show-icons false "${ROFI_DISPLAY_ARGS[@]}" \
    -window-title "$title" "$@" < "$ENTRIES" > /dev/null 2> "$OUT/rofi-$name.log" &
  local pid=$!
  ROFI_PID="$pid"
  wait_for_render
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "rofi exited early for $name, log:" >&2
    cat "$OUT/rofi-$name.log" >&2 || true
    return 1
  fi
  screenshot "$OUT/$name.png"
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
    -cache-dir "$OUT/cache-$name" "${ROFI_DISPLAY_ARGS[@]}" \
    -window-title "$title" "$@" > /dev/null 2> "$OUT/rofi-$name.log" &
  local pid=$!
  ROFI_PID="$pid"
  wait_for_render
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "rofi exited early for $name, log:" >&2
    cat "$OUT/rofi-$name.log" >&2 || true
    return 1
  fi
  screenshot "$OUT/$name.png"
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

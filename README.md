# rofi-win98

A Windows 98–style theme for [rofi](https://github.com/davatorium/rofi), the dmenu
replacement. Pure theme configuration — no forked binary, no patch, no build step.

![Win98 scrollbar arrows](tests/reference/drun.png)

## Features

- Grey dialog chrome with 4-tone raised and sunken bevels
- Title bar with title and working close control
- Sunken white input field with an Open affordance
- Dense result rows: name, generic name, and comment
- Working OK / Cancel controls and a visual-only Browse control
- Scrollbar arrows capping a narrow trough column (visual-only)
- Pixel-level visual regression tests on X11 and native Wayland

## Requirements

| Dependency | Purpose | Install |
| --- | --- | --- |
| `rofi` >= 2.0 | the launcher | distro package, or [releases](https://github.com/davatorium/rofi/releases/latest) |
| `Chicago95` | icon theme (`icon-theme: "Chicago95"`) | distro package, or [grassmunk/Chicago95](https://github.com/grassmunk/Chicago95) |
| Terminus fonts | UI font (`Terminus 12`) | distro package, e.g. `terminus-font` |

The theme falls back gracefully: without Chicago95 icons render as generic
placeholders, and without Terminus text renders in the system default.

## Installation

Copy the theme into your XDG config directory:

```bash
mkdir -p ~/.config/rofi
cp win98.rasi ~/.config/rofi/
```

Then point rofi at it. Either add an `@theme` directive to your `config.rasi`:

```
@theme "~/.config/rofi/win98.rasi"
```

or pass it per-invocation:

```bash
rofi -show drun -theme ~/.config/rofi/win98.rasi
```

## Screenshots

| Case | Preview |
| --- | --- |
| Run dialog, default selection | [`tests/reference/drun.png`](tests/reference/drun.png) |
| Run dialog, moved selection | [`tests/reference/drun-selected.png`](tests/reference/drun-selected.png) |
| Line input, default selection | [`tests/reference/dmenu.png`](tests/reference/dmenu.png) |
| Line input, moved selection | [`tests/reference/dmenu-selected.png`](tests/reference/dmenu-selected.png) |

These same four images are the blessed references for the visual test suite, so
what you see above is exactly what the tests pin.

## Development

The test suite renders the same four cases on isolated X11 and Wayland displays
and diffs the results against the same blessed references with normalized RMSE
(threshold 0.01). Both backends use a 1280×800 output at scale 1.
Development dependencies are provided by `shell.nix`:

X11 (Xvfb and Openbox):

```bash
nix-shell --run "tests/render.sh && tests/compare.py"
```

Native Wayland (headless Sway, software rendering, Xwayland disabled):

```bash
nix-shell --run "tests/render.sh --backend wayland && tests/compare.py --current out/wayland"
```

Both commands create their own display and clean up only their own processes,
so they can run from an existing desktop session. Sway and Grim are included in
`shell.nix` for Wayland testing.

To run the comparator's unit tests:

```bash
nix-shell --run "python3 -B -m unittest discover -s tests"
```

`tests/render.sh` writes X11 screenshots to `out/` and Wayland screenshots to
`out/wayland/`. Use `--out DIR` to choose another output directory.
`tests/compare.py` compares screenshots to `tests/reference/` and writes a
red-amplified diff on failure.

To re-bless references after an intentional visual change, run
`tests/render.sh` and copy the new PNGs over `tests/reference/`, then check both
backends against the updated references.

## Known limitations

- Scrollbar arrows are **visual-only**: the wheel and arrow keys scroll the list,
  but clicking the arrows or dragging the trough does nothing.
- Browse is **visual-only** and does not open a file picker. OK accepts the
  selection; Cancel and the title-bar close control dismiss the launcher.
- The title-bar background and bevels are non-interactive decoration.

## License

GPL-2.0-only. See [LICENSE](LICENSE).

Parts of the Windows 98 visual design are Microsoft's; this project is an
independent reimplementation from scratch and ships no Microsoft code, assets,
or fonts.

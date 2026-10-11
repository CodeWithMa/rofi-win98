# rofi-win98

A Windows 98–style theme for [rofi](https://github.com/davatorium/rofi), the dmenu
replacement. Pure theme configuration — no forked binary, no patch, no build step.

![Win98 scrollbar arrows](tests/reference/drun.png)

## Features

- Grey dialog chrome with 4-tone raised and sunken bevels
- Title bar with title and working close control
- Sunken white input field with an Open affordance
- Dense result rows: name, generic name, and comment
- OK / Cancel / Browse controls
- Scrollbar arrows capping a narrow trough column (visual-only)
- Pixel-level visual regression tests

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

Then point rofi at it. Either set `theme:` in your `config.rasi`:

```
* {
    theme: "~/.config/rofi/win98.rasi";
}
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

The test suite renders the theme under Xvfb and diffs the result against the
blessed references with normalized RMSE (threshold 0.01). Dependencies are
pinned in `shell.nix`:

```bash
nix-shell --run "tests/render.sh && tests/compare.py"
```

`tests/render.sh` writes screenshots to `out/`; `tests/compare.py` compares them
to `tests/reference/` and writes a red-amplified diff on failure.

To re-bless references after an intentional visual change, run
`tests/render.sh` and copy the new PNGs over `tests/reference/`.

## Known limitations

- Scrollbar arrows are **visual-only**: the wheel and arrow keys scroll the list,
  but clicking the arrows or dragging the trough does nothing.
- Title bar, bevels, and controls are non-interactive decoration.

## License

GPL-2.0-only. See [LICENSE](LICENSE).

Parts of the Windows 98 visual design are Microsoft's; this project is an
independent reimplementation from scratch and ships no Microsoft code, assets,
or fonts.
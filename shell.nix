{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    rofi
    xvfb-run
    xorg-server
    openbox
    maim
    xdotool
    imagemagick
    terminus_font
    terminus_font_ttf
    chicago95
    procps
    (python3.withPackages (ps: [ ps.pillow ]))
  ];

  shellHook = ''
    echo "rofi visual test env ready"
    command -v rofi >/dev/null && rofi -v 2>/dev/null | head -1 || true
  '';
}

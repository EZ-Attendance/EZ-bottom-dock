#!/usr/bin/env python3
"""Emit a JSON palette from the current wallpaper plus unique theme colors."""
import json
import math
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
BG_LINK = HOME / ".local/state/omarchy/current/background"
THEME_COLORS = HOME / ".local/state/omarchy/current/theme/colors.toml"
SIZE = 128
MAX_COLORS = 24
NEAR = 22.0
HUE_STEP = 15.0
HUE_NAMES = [
    "apple", "blossom", "peach", "gold", "straw", "leaf",
    "green", "moss", "sage", "teal", "sea", "fogblue",
    "steel", "sky", "indigo", "violet", "lilac", "purple",
    "plum", "magenta", "rose", "pink", "blush", "flush",
]


def current_background():
    if BG_LINK.exists() or BG_LINK.is_symlink():
        return Path(os.path.realpath(BG_LINK))
    return Path()


def read_rgb(path):
    vf = f"scale={SIZE}:{SIZE}:flags=area"
    cmds = [
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
         "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "-frames:v", "1", "pipe:1"],
        ["magick", str(path), "-resize", f"{SIZE}x{SIZE}!", "-alpha", "off", "rgb:-"],
        ["convert", str(path), "-resize", f"{SIZE}x{SIZE}!", "-alpha", "off", "rgb:-"],
    ]
    expected = SIZE * SIZE * 3
    for cmd in cmds:
        try:
            raw = subprocess.check_output(cmd, timeout=20)
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            continue
        if len(raw) >= expected:
            return raw[:expected]
    return b""


def rgb_to_hsl(r, g, b):
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    lum = (mx + mn) / 2.0
    if mx == mn:
        return 0.0, 0.0, lum
    d = mx - mn
    sat = d / (2.0 - mx - mn) if lum > 0.5 else d / (mx + mn)
    if mx == r:
        hue = (g - b) / d + (6.0 if g < b else 0.0)
    elif mx == g:
        hue = (b - r) / d + 2.0
    else:
        hue = (r - g) / d + 4.0
    return hue * 60.0, sat, lum


def hex_of(r, g, b):
    return "#{:02X}{:02X}{:02X}".format(
        int(max(0, min(255, round(r)))),
        int(max(0, min(255, round(g)))),
        int(max(0, min(255, round(b)))),
    )


def dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def avg_rgb(pts):
    n = max(1, len(pts))
    return (
        sum(p[3] for p in pts) / n,
        sum(p[4] for p in pts) / n,
        sum(p[5] for p in pts) / n,
    )


def unique_name(base, used):
    if base not in used:
        used.add(base)
        return base
    n = 2
    while f"{base}-{n}" in used:
        n += 1
    name = f"{base}-{n}"
    used.add(name)
    return name


def add_color(out, used, seen, key, rgb, force=False):
    r, g, b = rgb
    hx = hex_of(r, g, b)
    if hx in seen:
        return False
    if not force:
        for existing in out:
            er = int(existing["hex"][1:3], 16)
            eg = int(existing["hex"][3:5], 16)
            eb = int(existing["hex"][5:7], 16)
            if dist((r, g, b), (er, eg, eb)) < NEAR:
                return False
    seen.add(hx)
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    out.append({"key": unique_name(key, used), "hex": hx, "_lum": lum})
    return True


def parse_theme_colors(path):
    rows = []
    if not path.is_file():
        return rows
    text = path.read_text(encoding="utf-8", errors="replace")
    skip = {"mode", "selection"}
    for line in text.splitlines():
        m = re.match(r'^\s*([A-Za-z0-9_]+)\s*=\s*["\']?(#[0-9A-Fa-f]{6})', line)
        if not m:
            continue
        key = m.group(1)
        if key in skip:
            continue
        hx = m.group(2).upper()
        r = int(hx[1:3], 16)
        g = int(hx[3:5], 16)
        b = int(hx[5:7], 16)
        rows.append((key.replace("_", "-"), (r, g, b)))
    return rows


def palette(raw):
    pixels = []
    for i in range(0, len(raw), 3):
        r, g, b = raw[i], raw[i + 1], raw[i + 2]
        h, s, l = rgb_to_hsl(r, g, b)
        pixels.append((h, s, l, r, g, b))

    out = []
    used = set()
    seen = set()

    # Sky / path: lightest pixels.
    light = sorted(pixels, key=lambda p: -p[2])[: max(40, len(pixels) // 20)]
    add_color(out, used, seen, "cream", avg_rgb(light))

    # Mist neutrals across luminance.
    neut = [p for p in pixels if p[1] < 0.14]
    neut.sort(key=lambda p: p[2])
    bands = 4
    if neut:
        chunk = max(1, len(neut) // bands)
        labels = ["shadow", "shade", "mist", "fog"]
        for i in range(bands):
            sl = neut[i * chunk:(i + 1) * chunk] if i < bands - 1 else neut[i * chunk:]
            if len(sl) < 24:
                continue
            add_color(out, used, seen, labels[i], avg_rgb(sl))

    # Distinct hues: apples, blossom, foliage, trunk, lavender.
    chroma = [p for p in pixels if p[1] >= 0.10]
    by_hue = {}
    for p in chroma:
        sec = int(p[0] / HUE_STEP) % 24
        by_hue.setdefault(sec, []).append(p)
    for sec in sorted(by_hue):
        pts = by_hue[sec]
        if len(pts) < 10:
            continue
        pts.sort(key=lambda p: -p[1] * (0.4 + min(p[2], 1.0 - p[2])))
        take = pts[: max(12, len(pts) // 4)]
        add_color(out, used, seen, HUE_NAMES[sec], avg_rgb(take))

    # Darkest mass (tree trunk).
    dark = sorted(pixels, key=lambda p: p[2])[: max(40, len(pixels) // 24)]
    add_color(out, used, seen, "trunk", avg_rgb(dark))

    # Most saturated splash (fruit / accent in the painting).
    vivid = sorted(pixels, key=lambda p: -p[1])[: max(24, len(pixels) // 40)]
    add_color(out, used, seen, "accent", avg_rgb(vivid))

    # Theme colors.toml extras so the picker covers Monet Apple's fruit/ink too.
    for key, rgb in parse_theme_colors(THEME_COLORS):
        add_color(out, used, seen, key, rgb)

    out.sort(key=lambda c: -c["_lum"])
    cleaned = []
    for row in out:
        cleaned.append({"key": row["key"], "hex": row["hex"]})
        if len(cleaned) >= MAX_COLORS:
            break
    return cleaned


def main():
    path = current_background()
    if not path.is_file():
        print("[]")
        return 0
    raw = read_rgb(path)
    if len(raw) < SIZE * SIZE * 3:
        print("[]")
        return 0
    json.dump(palette(raw), sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

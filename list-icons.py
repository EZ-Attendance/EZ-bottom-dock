#!/usr/bin/env python3
"""Unique icons from the active icon theme for the bottom dock picker.

One row per picture. Names that point at the same file collapse to a single
choice. The current theme is walked first, then the themes it inherits.
"""
import configparser
import json
import os
import subprocess
from pathlib import Path

ICON_ROOTS = [
    Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "icons",
    Path("/usr/share/icons"),
]
SIZES = ("256x256", "48x48", "scalable", "32x32")
# Application icons are other programs' artwork. The picker offers the rest
# of the theme: actions, devices, places, and the other shared contexts.
KEEP = {
    "actions": "Actions",
    "categories": "Categories",
    "devices": "Devices",
    "emblems": "Emblems",
    "mimetypes": "File types",
    "places": "Places",
    "status": "Status",
}


def theme_name():
    try:
        out = subprocess.check_output(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        out = ""
    if out.startswith("'") and out.endswith("'"):
        out = out[1:-1]
    return out or "Yaru-red"


def theme_dir(name):
    for root in ICON_ROOTS:
        path = root / name
        if (path / "index.theme").is_file():
            return path
    return None


def inherits(path):
    parser = configparser.ConfigParser(interpolation=None)
    try:
        parser.read(path / "index.theme", encoding="utf-8")
    except (OSError, configparser.Error):
        return []
    raw = parser.get("Icon Theme", "Inherits", fallback="")
    return [part.strip() for part in raw.split(",") if part.strip()]


def theme_chain(name):
    chain = []
    seen = set()
    pending = [name]
    while pending:
        current = pending.pop(0)
        if not current or current in seen:
            continue
        seen.add(current)
        path = theme_dir(current)
        if path is None:
            continue
        chain.append(path)
        for parent in inherits(path):
            if parent not in seen:
                pending.append(parent)
    return chain


def label_for(name):
    words = name.replace("_", " ").replace("-", " ").split()
    return " ".join(word.capitalize() for word in words)


def name_rank(name):
    return (
        name.endswith("-symbolic"),
        name.startswith("gtk-") or name.startswith("stock_"),
        "-" not in name,
        len(name),
        name,
    )


def usable_name(stem):
    if stem.endswith("-symbolic") or stem.endswith("-symbolic-rtl"):
        return ""
    for suffix in ("-rtl", "-ltr"):
        if stem.endswith(suffix):
            return ""
    # Installed-program names that landed outside the apps context.
    if stem.startswith(("org.", "io.", "com.", "app.")):
        return ""
    return stem


def collect(chain):
    # name -> (realpath, category, path)
    by_name = {}
    for theme in chain:
        for size in SIZES:
            base = theme / size
            if not base.is_dir():
                continue
            for dirpath, _dirs, files in os.walk(base):
                if "symbolic" in Path(dirpath).parts:
                    continue
                category = Path(dirpath).relative_to(base).parts
                cat = category[0] if category else ""
                if cat not in KEEP:
                    continue
                for filename in files:
                    if not filename.endswith((".png", ".svg", ".svgz")):
                        continue
                    stem = usable_name(filename.rsplit(".", 1)[0])
                    if not stem or stem in by_name:
                        continue
                    path = Path(dirpath) / filename
                    try:
                        real = path.resolve()
                    except OSError:
                        continue
                    if not real.is_file():
                        continue
                    by_name[stem] = (str(real), KEEP[cat], str(path))
    # Same picture under several names becomes one row.
    by_file = {}
    for name, (real, category, path) in by_name.items():
        current = by_file.get(real)
        if current is None or name_rank(name) < name_rank(current[0]):
            by_file[real] = (name, category, path)
    rows = [
        {"name": name, "label": label_for(name), "category": category}
        for name, category, _path in by_file.values()
    ]
    rows.sort(key=lambda row: (row["category"], row["label"], row["name"]))
    return rows


def main():
    print(json.dumps(collect(theme_chain(theme_name())), separators=(",", ":")))


if __name__ == "__main__":
    main()

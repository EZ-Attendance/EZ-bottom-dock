#!/usr/bin/env python3
"""List summonable Omarchy shell plugins for the bottom dock picker.

Filesystem-based so it works when invoked from inside omarchy-shell (IPC
listPlugins from a nested Process can hang or return empty).
"""
import json
import os
import re
from pathlib import Path

HOME = Path.home()
OMARCHY = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
SELF_ID = "drace3000.bottom-dock"

EXCLUDED = {
    "omarchy.spacer",
    "omarchy.workspaces",
    "omarchy.tray",
    "omarchy.keyboard-layout",
    "omarchy.indicators",
    "omarchy.active-window",
    "omarchy.bar",
    "omarchy.microphone",
    SELF_ID,
}

ICON_MAP = {
    "omarchy.menu": "application-menu",
    "omarchy.clipboard": "edit-copy",
    "omarchy.emojis": "face-smile",
    "omarchy.reminders": "alarm-symbolic",
    "omarchy.image-picker": "folder-pictures",
    "omarchy.wifiqr": "network-wireless",
    "omarchy.speedtest": "network-workgroup",
    "omarchy.disk-speedtest": "drive-harddisk",
    "omarchy.dev-gallery": "applications-graphics",
    "omarchy.osd": "audio-volume-high",
    "omaplug": "application-x-addon",
    "omarchy.audio": "audio-volume-high",
    "omarchy.bluetooth": "bluetooth",
    "omarchy.network": "network-wireless",
    "omarchy.power": "system-shutdown",
    "omarchy.monitor": "video-display",
    "omarchy.weather": "weather-few-clouds",
    "omarchy.agents": "computer",
    "omarchy.system-update": "system-software-update",
    "omarchy.clock": "preferences-system-time",
    "io.github.twiking.omasettings": "preferences-system",
    "stappmus.activity-monitor": "utilities-system-monitor",
    "drace3000.clock": "preferences-system-time",
}


def load_json(path):
    try:
        return json.loads(path.read_text())
    except Exception:
        return None


LOADER_KINDS = ("panel", "overlay", "menu")


def summonable(kinds):
    kinds = kinds or []
    if any(k in kinds for k in LOADER_KINDS):
        return True
    return "bar-widget" in kinds


def layout_ids(shell_cfg):
    """Every plugin id sitting in the 4.5 bar, including centerBegin, centerEnd, and tray."""
    ids = set()
    layout = (shell_cfg.get("bar") or {}).get("layout") or {}
    if not isinstance(layout, dict):
        return ids
    for entries in layout.values():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if isinstance(entry, dict) and entry.get("id"):
                ids.add(entry["id"])
            elif isinstance(entry, str):
                ids.add(entry)
    return ids


def read_enabled(shell_cfg):
    """Return (third_party_enabled_ids, disabled_ids)."""
    enabled = set(layout_ids(shell_cfg))
    disabled = set(shell_cfg.get("disabledPlugins") or [])
    for entry in shell_cfg.get("plugins") or []:
        if isinstance(entry, dict) and entry.get("id"):
            enabled.add(entry["id"])
        elif isinstance(entry, str):
            enabled.add(entry)
    return enabled, disabled


def widget_popup(manifest_path, data):
    """True when a bar-only widget exposes the open/close pair shell.toggle calls."""
    eps = data.get("entryPoints") or {}
    rel = str(eps.get("barWidget") or "")
    if not rel:
        return False
    qml = manifest_path.parent / rel
    try:
        text = qml.read_text(errors="replace")
    except OSError:
        return False
    # qs.Ui Panel supplies open(), close(), and toggle() on the root, so a
    # widget whose root type is Panel can be summoned without restating them.
    if re.search(r"(?m)^Panel\s*\{", text):
        return True
    return "function open" in text and "function close" in text


def scan_manifests(root, first_party, out):
    if not root.is_dir():
        return
    for path in root.rglob("*.json"):
        name = path.name
        if name != "manifest.json" and not name.endswith(".manifest.json"):
            continue
        if "node_modules" in path.parts or "tests" in path.parts:
            continue
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        pid = str(data.get("id") or "")
        if not pid or pid in EXCLUDED:
            continue
        kinds = data.get("kinds") or []
        if not isinstance(kinds, list) or not summonable(kinds):
            continue
        loader = any(k in kinds for k in LOADER_KINDS)
        out[pid] = {
            "id": pid,
            "name": str(data.get("name") or data.get("barWidget", {}).get("displayName") or pid),
            "kinds": kinds,
            "icon": ICON_MAP.get(pid, "preferences-system"),
            "firstParty": first_party,
            "loader": loader,
            "barToggle": (not loader) and "bar-widget" in kinds and widget_popup(path, data),
        }


def main():
    shell_cfg = load_json(HOME / ".config/omarchy/shell.json") or {}
    enabled_ids, disabled_ids = read_enabled(shell_cfg)

    found = {}
    scan_manifests(OMARCHY / "shell" / "plugins", True, found)
    scan_manifests(HOME / ".config/omarchy/plugins", False, found)

    # omaplug and other user plugins must appear when enabled in the bar layout
    # even if something odd happens in the scan.
    for forced in ("omaplug", "io.github.twiking.omasettings", "stappmus.activity-monitor"):
        if forced in enabled_ids and forced not in found and forced not in EXCLUDED:
            found[forced] = {
                "id": forced,
                "name": forced,
                "kinds": ["bar-widget"],
                "icon": ICON_MAP.get(forced, "preferences-system"),
                "firstParty": False,
                "loader": False,
                "barToggle": True,
            }

    on_bar = layout_ids(shell_cfg)
    rows = []
    for pid, row in found.items():
        if pid in disabled_ids or pid in EXCLUDED:
            continue
        # A panel, overlay, or menu is summoned by the shell loader.
        # A bar-only widget is summoned through the live bar slot, so a pin
        # for one that is not on the bar does nothing in Omarchy 4.5.
        if row.get("loader"):
            offered = row["firstParty"] or pid in enabled_ids
        else:
            offered = row.get("barToggle") and pid in on_bar
        if not offered:
            continue
        rows.append({
            "id": row["id"],
            "name": row["name"],
            "kinds": row["kinds"],
            "icon": row["icon"],
        })

    rows.sort(key=lambda x: x["name"].lower())
    print(json.dumps(rows))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""List summonable Omarchy shell plugins for the bottom dock picker.

Filesystem-based so it works when invoked from inside omarchy-shell (IPC
listPlugins from a nested Process can hang or return empty).
"""
import json
import os
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


def summonable(kinds):
    kinds = kinds or []
    if any(k in kinds for k in ("panel", "overlay", "menu")):
        return True
    return "bar-widget" in kinds


def read_enabled(shell_cfg):
    """Return (third_party_enabled_ids, disabled_ids)."""
    enabled = set()
    disabled = set(shell_cfg.get("disabledPlugins") or [])
    for entry in shell_cfg.get("plugins") or []:
        if isinstance(entry, dict) and entry.get("id"):
            enabled.add(entry["id"])
        elif isinstance(entry, str):
            enabled.add(entry)
    bar = shell_cfg.get("bar") or {}
    layout = bar.get("layout") or {}
    for section in ("left", "center", "right"):
        for entry in layout.get(section) or []:
            if isinstance(entry, dict) and entry.get("id"):
                enabled.add(entry["id"])
            elif isinstance(entry, str):
                enabled.add(entry)
    return enabled, disabled


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
        out[pid] = {
            "id": pid,
            "name": str(data.get("name") or data.get("barWidget", {}).get("displayName") or pid),
            "kinds": kinds,
            "icon": ICON_MAP.get(pid, "preferences-system"),
            "firstParty": first_party,
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
            }

    rows = []
    for pid, row in found.items():
        if pid in disabled_ids or pid in EXCLUDED:
            continue
        if row["firstParty"]:
            rows.append(row)
            continue
        if pid in enabled_ids:
            rows.append(row)

    rows.sort(key=lambda x: x["name"].lower())
    print(json.dumps(rows))


if __name__ == "__main__":
    main()

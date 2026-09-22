#!/usr/bin/env python3
"""Print Omarchy Super+K keybindings as JSON: name, combo, dispatcher, arg."""
import json
import subprocess
import sys

SCRIPT = "/usr/bin/omarchy-menu-keybindings"
MARKER = 'if [[ $1 == "--print"'


def records():
    text = open(SCRIPT, encoding="utf-8").read()
    cut = text.find(MARKER)
    if cut < 0:
        raise SystemExit("keybindings menu script has no print hook")
    proc = subprocess.run(
        ["bash", "-c", text[:cut] + "\noutput_binding_records\n"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0 and not proc.stdout:
        sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode or 1)
    rows = []
    seen = set()
    for raw in proc.stdout.splitlines():
        if not raw.strip():
            continue
        parts = raw.split("\t")
        display = parts[0].rstrip()
        dispatcher = parts[1] if len(parts) > 1 else ""
        arg = "\t".join(parts[2:]) if len(parts) > 2 else ""
        if "→" in display:
            combo, name = display.split("→", 1)
        else:
            combo, name = "", display
        combo = " ".join(combo.split())
        name = " ".join(name.split())
        if not name:
            continue
        key = (name, combo, dispatcher, arg)
        if key in seen:
            continue
        seen.add(key)
        rows.append({
            "name": name,
            "combo": combo,
            "line": f"{combo:<35} → {name}",
            "dispatcher": dispatcher,
            "arg": arg,
        })
    return rows


def main():
    json.dump(records(), sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()

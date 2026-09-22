#!/usr/bin/env python3
"""Fire one shortcut with the same dispatcher the Super+K menu uses."""
import subprocess
import sys

SCRIPT = "/usr/bin/omarchy-menu-keybindings"
MARKER = 'if [[ $1 == "--print"'


def main():
    dispatcher = sys.argv[1] if len(sys.argv) > 1 else ""
    arg = sys.argv[2] if len(sys.argv) > 2 else ""
    text = open(SCRIPT, encoding="utf-8").read()
    cut = text.find(MARKER)
    if cut < 0:
        raise SystemExit("keybindings menu script has no dispatch hook")
    body = text[:cut] + '\ndispatch_binding "$1" "$2"\n'
    subprocess.run(["bash", "-c", body, "dispatch-keybind", dispatcher, arg], check=False)


if __name__ == "__main__":
    main()

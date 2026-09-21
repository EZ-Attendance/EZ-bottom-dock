# EZ Bottom Dock

Easy auto-hiding bottom dock for apps, plugins, and web links — with per-workspace layouts.

Built for [Omarchy](https://omarchy.org) / Quickshell. Plugin id: `drace3000.bottom-dock`.

## Install

```bash
omarchy plugin add https://github.com/EZ-Attendance/EZ-bottom-dock --enable
```

Restart the shell if the dock does not appear:

```bash
omarchy-restart-shell
```

## Remove

```bash
omarchy plugin remove drace3000.bottom-dock
```

## Requirements

- Omarchy 4.x with Quickshell
- Hyprland (workspace-aware layouts and optional hotkeys)
- `python3` (plugin picker catalog helper)

## Quick start

1. Move the pointer to the bottom edge of the screen to reveal the dock.
2. When empty, the dock shows **Hello World**.
3. **Right-click** empty dock space to open the menu.
4. Use **ADD** and **SETTINGS** to customize.

## Features

### Auto-hide

The dock stays hidden until you move the cursor to the bottom of the screen. It stays open while you hover it, use menus, or drag icons.

### Left / Center / Right slots

Icons are grouped into three sections: **Left**, **Center**, and **Right**.

### Add apps, plugins, and web links

Right-click the dock background:

1. In **ADD**, choose **App**, **Plugin**, or **Web**.
2. Pick placement with the **Left / Center / Right** radios.
3. Complete the picker:
   - **App** — search and pick a desktop app
   - **Plugin** — pick a summonable Omarchy shell plugin (panels, menus, overlays, and many bar widgets)
   - **Web** — enter a name and URL

### Per-icon actions

**Right-click an icon** to:

- Move it to Left, Center, or Right
- Remove it from the dock

### Drag and drop

**Click and drag** an icon to reorder it or move it between Left / Center / Right.

### Running and focused indicators

App icons show a small indicator when that app is running. A stronger indicator marks the focused window. Clicking a running app focuses it; clicking again (or when not running) launches it.

### Icon popups (tooltips)

Hover an icon to see its name above the dock (to the right of the cursor). Toggle this under **SETTINGS → Icon popups**.

### Per-workspace layouts

Each Hyprland workspace can have its own dock layout.

- New / untouched workspaces inherit the shared default layout.
- Once you customize a workspace (add, remove, move, or drag icons), that layout is saved for that workspace only.
- Switching workspaces swaps the visible icons to match.

### Icon size

In **SETTINGS**:

- **Icon Size** `[+]` / `[-]`

Also:

- Scroll on the dock to resize icons
- **Super +** / **Super -** (and keypad equivalents) while the pointer is over the dock

### Transparency

In **SETTINGS**:

- **Transparency** `[+]` / `[-]` — more / less transparent dock background

Also:

- **Super + ]** — more opaque (while pointer is over the dock)
- **Super + [** — more transparent (while pointer is over the dock)
- **Alt + scroll** on the dock — adjust opacity

### Empty dock

If a workspace has no icons, the dock shows **Hello World** until you add something.

## Keyboard shortcuts

On first load, the plugin registers these binds in `~/.config/hypr/bindings.lua` (only while the pointer is over the dock):

| Shortcut | Action |
| --- | --- |
| `Super + =` | Larger icons |
| `Super + -` | Smaller icons |
| `Super + ]` | More opaque |
| `Super + [` | More transparent |

These binds are personal overrides. Remove them from `bindings.lua` if you uninstall the plugin and no longer want them.

## Settings summary

Right-click the dock background:

**ADD**

- App / Plugin / Web pills
- Left / Center / Right radio group

**SETTINGS**

- Icon Size `+` / `-`
- Transparency `+` / `-`
- Icon popups (checkbox)

## Notes

- Community plugins run as unsandboxed code. Review source before installing from third parties.
- Layout and settings are stored in Omarchy’s `shell.json` under this plugin’s entry.
- The Omarchy menu item tip shows as **Oma menu** when that plugin is on the dock.

## License

[MIT](LICENSE) © 2026 EZ-Attendance

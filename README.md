# EZ Bottom Dock

## TOP FEATURES

- Pin apps, plugins, web links, keybinds, and system actions on a single task bar
- Split the bar up to eight sections with separator drag to set width.
- Drag a blank part of the bar repositioning to the left, right, or bottom edge.
- Turn on or off auto-hide
- Each workspace keeps its own layout, or Global Changes applies the next edit to all.
- Right-click an icon to rename or mouse drag relocating to another section
- Drag icons along the bar to reposition them
- Open windows show a blinking icon underline
- Set resize icons by mouse scroll wheel
- Set bar background color via theme swatch and transparency level in settings
- Open task bar help from the information icon

Easy dock for apps, plugins, web links, and keybinds — with per-workspace layouts. A new install shows three blank sections. Icon popups are on. Auto-hide and Global Changes are off.

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

1. The dock sits on the bottom of the screen. A new install has three blank sections, icon popups on, and both auto-hide and Global Changes off.
2. When empty, the dock shows **Right click to start customization**.
3. **Right-click** empty dock space to open the menu.
4. Use **ADD** and **SETTINGS** to customize.

## Features

### Auto-hide

Auto-hide starts off, so the dock stays on screen. Turn on **Auto hide task bar** and it stays hidden until you move the cursor to its screen edge. It stays open while you hover it, use menus, or drag icons. Drag a blank part of the bar off the strip to move it to the left, the right, or the bottom. Holding Super and dragging does the same. An empty bar also shows a short welcome: **Select gear icon to customize task bar**. The first time the dock is installed it stays up for two minutes, so it is still there after other windows, or until you click its X. On a later startup, if every section is still blank, it stays up for 15 seconds, or until you click its X. It stays closed until the bar is empty again on another workspace or the next login.

### Numbered sections

Each workspace can have up to eight numbered sections, or none. **+** adds an empty section at the end. Click a section number to press it in, then **−** removes it. An empty section is removed at once. A section that still has icons asks before it is deleted.

Drag a separator to widen or narrow the section in front of it, including the separator beside the globe. A press that starts on a separator resizes that section and does not move the bar. The section moves only while **Super** is held or the mouse button is down, and it stops if the pointer leaves the strip. A section will not shrink smaller than its icons. This resize stays on the workspace you are changing, even when Global Changes is on. Saved section widths and the bar’s screen edge are applied when the shell starts.

### Add apps, plugins, web links, and keybinds

Right-click the dock background, or click the **gear**:

1. Choose **App**, **Plugin**, **Web**, **KeyBind**, or **System**.
2. The numbers under those buttons choose which section receives the new icon.
3. Complete the picker:
   - **App** — search and pick a desktop app
   - **Plugin** — pick a summonable Omarchy shell plugin (panels, menus, overlays, and many bar widgets)
   - **Web** — enter a name and URL
   - **KeyBind** — pick an Omarchy shortcut. The icon shows up to three letters. Hover shows the name. Left-click runs the shortcut.
   - **System** — pick Logout, Lock, or Shutdown. The choice adds that icon to the numbered section and does not run the action. Left-click the icon on the bar to open its check. The action name is the title, the warnings sit under it, and **Cancel** and **Proceed** are the buttons. Cancel leaves the computer as it is. Proceed runs the action.

### Per-icon actions

**Right-click an icon** to edit its label, choose its section, choose its workspaces, or remove it. The information icon opens help for that icon. The circled **X** closes the menu.

### Drag and drop

**Click and drag** an icon to move it along the bar, including into another numbered section. Drag a blank part of the bar off the strip, or hold **Super** and drag it, to move the bar to the left, the right, or the bottom. A click that stays on an icon still launches that icon.

### Running and focused indicators

App icons and keybind badges show a blinking underline while that window is open on the workspace this dock is showing. The underline is wider when that window is focused. Closing the window clears the underline. A keybind that does not open a window stays unmarked. Clicking an app launches it on this workspace. Clicking a keybind runs its shortcut.

### Icon popups (tooltips)

Hover an icon to see its name. If that icon has a blinking underline, the popup also shows **(n)** for how many of that item are open on this workspace. Turn popups off from the bar menu.

### Global Changes

The **globe** after the last section is the Global Changes switch. Neon green is on. Neon red is off. When it is on, the next edit applies to every workspace: icons added, moved, or removed, and the bar's edge, size, color, popups, and auto-hide. Adding or moving an icon into a section number another workspace does not have yet adds empty sections there until that number exists. The globe and the **gear** beside it are shared. They cannot be moved or removed. The gear opens the same settings menu as a right-click on a blank part of the bar.

### Help

The information icon, with no icon selected, opens task bar help. The search field highlights every match with a yellow background and jumps to the first one. The down arrow jumps to the next match. The circled **X** inside the search field clears the search.

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

If a workspace has no icons, the dock shows **Right click to start customization** until you add something.

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

- App / Plugin / Web / KeyBind
- Section numbers under those buttons

**SETTINGS**

- Section numbers, **+**, and **−**
- Icon Size `+` / `-`
- Transparency `+` / `-`
- Background color swatches, including Theme
- Icon popups
- Global Changes
- Auto hide task bar

## Notes

- Community plugins run as unsandboxed code. Review source before installing from third parties.
- Layout and settings are stored in Omarchy’s `shell.json` under this plugin’s entry.
- The Omarchy menu item tip shows as **Oma menu** when that plugin is on the dock.

## License

[MIT](LICENSE) © 2026 EZ-Attendance

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

// Auto-hiding bottom dock with left / center / right app icons.
// Empty layout shows "Hello World". Right-click to add apps or web links.
// Right-click an icon, then the info button, for help on what the dock does.
// Layouts are stored per Hyprland workspace. Each monitor's dock shows the
// workspace that monitor is displaying, even when the cursor is on another output.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string home: Quickshell.env("HOME")
  property var shell: null
  property var manifest: null
  readonly property string pluginId: "drace3000.bottom-dock"

  property bool autoHide: true
  property bool revealHeld: false
  property int hoverCount: 0
  property bool menuOpen: false
  property bool pickerOpen: false
  property bool webOpen: false
  property bool dragging: false
  property string pickerKind: "app" // "app" | "plugin" | "keybind"
  property var keybindCatalog: []

  property var layout: DockModel.emptyLayout()
  property var defaultLayout: DockModel.emptyLayout()
  property var workspaceLayouts: ({})
  property var workspaceTouched: ({})
  property string workspaceId: "1"
  property int iconSize: DockModel.defaultIconSize()
  property int bgOpacity: DockModel.defaultBgOpacity()
  property string bgColorKey: ""
  property string bgColorHex: ""
  property var themePalette: []
  property bool showTips: true
  property string barEdge: "bottom" // "bottom" | "left" | "right"
  property bool barEdgeDragging: false
  property bool edgeHoldActive: false
  property string edgeHoldSide: ""
  property real edgeHoldLimit: 0
  property real pointerX: 0
  property real pointerY: 0
  property bool pointerKnown: false
  // Omarchy active-window border is cyan #33ccff into green #00ff99.
  property real runMarkPulse: 1
  readonly property string blankBarTip: "RClick customize"
  property bool _loadingConfig: false
  property bool _switchingWorkspace: false

  property var dragItem: null
  property string dropSection: ""
  property int dropIndex: 0
  property string dragGhostSource: ""
  property string dragGhostBadge: ""
  property real dragGhostX: 0
  property real dragGhostY: 0
  property int toplevelRevision: 0
  // Mapped Hyprland clients, refreshed on open/close/move. Keybind underlines
  // follow this list so they clear when the window is gone.
  property var liveClients: []
  property int liveClientGen: 0
  property var closedAddresses: ({})
  property bool clientSyncAgain: false

  property string pendingSection: "center"
  property string itemPlaceSection: "center"
  property var menuItem: null
  property bool helpOpen: false
  property bool helpPosSet: false
  property bool helpDragging: false
  property real helpPosX: 0
  property real helpPosY: 0
  property string helpPosScreen: ""
  property int windowMoveHolds: 0
  readonly property string helpPosPath: {
    var runtime = String(Quickshell.env("XDG_RUNTIME_DIR") || "")
    if (!runtime.length) runtime = "/tmp"
    return runtime + "/drace3000-bottom-dock-help-pos.json"
  }
  readonly property string edgeDragLuaPath: home + "/.config/omarchy/plugins/drace3000.bottom-dock/edge-drag.lua"
  readonly property string windowMoveBindScript:
    "hl.unbind(\"SUPER + mouse:272\")\n" +
    "o.bind(\"SUPER + mouse:272\", \"Move window\", hl.dsp.window.drag(), { mouse = true })\n"
  property string labelDraft: ""
  property bool labelEdit: false
  property string labelEditTarget: ""
  property real menuX: 0
  property real menuY: 0
  property var menuScreen: null
  property string pickerQuery: ""
  property int pickerSelectedIndex: 0
  property string webName: ""
  property string webUrl: ""
  property string webFocus: "name"
  property var pluginCatalog: []

  property bool tipVisible: false
  property string tipText: ""
  property real tipX: 0
  property real tipY: 0
  property var tipScreen: null
  property int tipRequest: 0

  readonly property bool hovered: hoverCount > 0
  readonly property bool uiHeld: menuOpen || pickerOpen || webOpen || dragging || barEdgeDragging
  readonly property bool forceShown: hovered || revealHeld || uiHeld
  readonly property bool revealed: !autoHide || forceShown
  readonly property bool layoutEmpty: DockModel.isEmpty(layout)

  readonly property int dockHeight: DockModel.dockHeightForIcons(iconSize)
  readonly property int edgeSize: 4
  readonly property int hideOffset: dockHeight + 1
  property int slideOffset: revealed ? 0 : hideOffset
  readonly property int iconSlot: iconSize
  readonly property color ink: Color.bar.text
  readonly property color surface: Color.popups.background
  readonly property color barFill: {
    var _pal = root.themePalette
    var hex = DockModel.resolveThemeColor(_pal, root.bgColorKey, root.bgColorHex)
    if (hex && String(hex).charAt(0) === "#")
      return hex
    return root.surface
  }
  readonly property var themeSwatches: {
    var list = [{ key: "", hex: "", label: "Theme" }]
    var pal = root.themePalette || []
    for (var i = 0; i < pal.length; i++) {
      if (pal[i] && pal[i].hex) list.push(pal[i])
    }
    return list
  }
  readonly property color menuBackground: Color.menu.background
  readonly property color menuForeground: Color.menu.text
  readonly property color menuBorder: Color.menu.border
  readonly property color menuScrim: Color.menu.scrim
  readonly property color menuSelectedBackground: Color.menu.selectedBackground
  readonly property color menuSelectedText: Color.menu.selectedText
  readonly property color menuSelectedBorder: Color.menu.selectedBorder
  readonly property color menuMuted: Qt.rgba(menuForeground.r, menuForeground.g, menuForeground.b, 0.55)
  readonly property color menuLine: Qt.rgba(menuForeground.r, menuForeground.g, menuForeground.b, 0.18)
  readonly property color menuFill: Qt.rgba(menuForeground.r, menuForeground.g, menuForeground.b, 0.08)
  readonly property color menuFillHover: Qt.rgba(menuForeground.r, menuForeground.g, menuForeground.b, 0.18)
  readonly property color menuStroke: Qt.rgba(menuForeground.r, menuForeground.g, menuForeground.b, 0.22)
  readonly property color menuStrokeHover: Qt.rgba(menuForeground.r, menuForeground.g, menuForeground.b, 0.45)
  readonly property var menuBorderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  readonly property var menuSelectedBorderSpec: Border.surfaceSpec("menu", "selected-border", Color.menu.selectedBorder, 0)
  readonly property real menuRowPadLeft: Border.left(menuSelectedBorderSpec) + Style.space(8)
  readonly property real menuRowPadRight: Border.right(menuSelectedBorderSpec) + Style.space(8)
  readonly property int menuHeaderHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  readonly property int menuRowHeight: Math.max(Style.space(50), Style.font.body + Style.spacing.rowPaddingX * 2)
  readonly property int menuContentMargin: Style.spacing.panelPadding
  readonly property int menuContentSpacing: Style.spacing.md
  readonly property var desktopApps: DesktopEntries.applications.values || []
  readonly property var pickerApps: DockModel.sortedDesktopEntries(desktopApps, pickerQuery)
  readonly property var pickerPlugins: DockModel.filterPlugins(pluginCatalog, pickerQuery)
  readonly property var pickerKeybinds: DockModel.filterKeybinds(keybindCatalog, pickerQuery)
  readonly property var pickerModel: pickerKind === "plugin"
    ? pickerPlugins
    : pickerKind === "keybind" ? pickerKeybinds : pickerApps
  readonly property var hyprWorkspaces: Hyprland.workspaces
  readonly property var listedWorkspaceIds: {
    var ids = [1, 2, 3, 4, 5]
    var values = []
    try { values = (hyprWorkspaces && hyprWorkspaces.values) ? hyprWorkspaces.values : [] } catch (e) {}
    for (var i = 0; i < values.length; i++) {
      var id = Number(values[i].id)
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    for (var key in workspaceLayouts) {
      if (!Object.prototype.hasOwnProperty.call(workspaceLayouts, key)) continue
      var n = Number(key)
      if (!isNaN(n) && n > 0 && ids.indexOf(n) === -1) ids.push(n)
    }
    ids.sort(function(a, b) { return a - b })
    return ids
  }
  readonly property var otherWorkspaceIds: {
    var cur = Number(DockModel.workspaceKey(workspaceId))
    var ids = listedWorkspaceIds
    var out = []
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] !== cur) out.push(ids[i])
    }
    return out
  }
  readonly property string pickerTitle: pickerKind === "plugin"
    ? ("Add plugin → " + pendingSection)
    : pickerKind === "keybind"
      ? "Keybindings"
      : ("Add app → " + pendingSection)

  Behavior on slideOffset {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  function open(_payload) {}
  function close() { root.closeMenus() }
  function toggle() {}

  function applyHelpPosText(raw) {
    if (helpDragging) return
    var data = null
    try { data = JSON.parse(String(raw || "")) } catch (e) { return }
    if (!data || !isFinite(Number(data.x)) || !isFinite(Number(data.y))) return
    helpPosX = Number(data.x)
    helpPosY = Number(data.y)
    helpPosScreen = String(data.screen || "")
    helpPosSet = true
  }

  function saveHelpPos(screenName) {
    helpPosScreen = String(screenName || helpPosScreen || "")
    helpPosFile.setText(JSON.stringify({
      x: helpPosX,
      y: helpPosY,
      screen: helpPosScreen
    }) + "\n")
  }

  // Hyprland uses Super+left-drag to move windows and swallows that gesture
  // before the help card can see it. Suspend the bind only while help is open.
  function runHyprEval(script) {
    windowMoveBindProc.running = false
    windowMoveBindProc.command = ["hyprctl", "eval", script]
    windowMoveBindProc.running = true
  }

  function holdWindowMove() {
    windowMoveHolds += 1
    if (windowMoveHolds === 1)
      runHyprEval("hl.unbind(\"SUPER + mouse:272\")\n")
  }

  function installEdgeDragBind() {
    windowMoveBindProc.running = false
    windowMoveBindProc.command = ["bash", "-lc", "hyprctl eval \"$(cat '" + edgeDragLuaPath + "')\""]
    windowMoveBindProc.running = true
  }

  function releaseWindowMove() {
    if (windowMoveHolds <= 0) return
    windowMoveHolds -= 1
    if (windowMoveHolds === 0)
      installEdgeDragBind()
  }

  onHelpOpenChanged: {
    if (helpOpen) holdWindowMove()
    else releaseWindowMove()
  }

  Component.onDestruction: {
    if (windowMoveHolds > 0)
      Util.execArgv(["bash", "-lc", "hyprctl eval \"$(cat '" + edgeDragLuaPath + "')\""])
  }

  function monitorAtGlobal(gx, gy) {
    var mons = []
    try { mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [] } catch (e) { mons = [] }
    for (var i = 0; i < mons.length; i++) {
      var m = mons[i]
      if (!m) continue
      var x = Number(m.x) || 0
      var y = Number(m.y) || 0
      var w = Number(m.width) || 0
      var h = Number(m.height) || 0
      if (gx >= x && gy >= y && gx < x + w && gy < y + h)
        return m
    }
    return null
  }

  function screenNamed(name) {
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && String(screens[i].name || "") === String(name || ""))
        return screens[i]
    }
    return null
  }

  // Global pointer positions from the Hyprland Super+drag bind.
  function applyBarDrag(x0, y0, x1, y1, commit) {
    var mon = monitorAtGlobal(x0, y0) || monitorAtGlobal(x1, y1)
    if (!mon) {
      if (commit) {
        barEdgeDragging = false
        hideIconTip()
      }
      return "nomon"
    }
    var originX = Number(mon.x) || 0
    var originY = Number(mon.y) || 0
    var w = Number(mon.width) || 0
    var h = Number(mon.height) || 0
    var edge = edgeFromDrag(barEdge, x0 - originX, y0 - originY, x1 - originX, y1 - originY, w, h)
    var screen = screenNamed(mon.name)
    if (screen)
      showEdgeHint(screen, x1 - originX, y1 - originY, edge)
    if (commit) {
      barEdgeDragging = false
      setBarEdge(edge)
      hideIconTip()
    } else {
      barEdgeDragging = true
      armReveal()
    }
    return edge
  }

  function setBarEdge(edge) {
    var next = edge === "left" || edge === "right" ? edge : "bottom"
    if (next === barEdge) return
    barEdge = next
    edgeHoldActive = false
    persistSettings()
  }

  // Map a point inside a dock panel to that screen. The panel only covers the
  // bar strip, so a Super+drag that leaves the strip still reports scene
  // coordinates relative to the strip.
  function panelPointToScreen(panel, sceneX, sceneY) {
    var screen = panel && panel.screen ? panel.screen : null
    var sw = screen ? Number(screen.width) || 0 : 0
    var sh = screen ? Number(screen.height) || 0 : 0
    var x = Number(sceneX) || 0
    var y = Number(sceneY) || 0
    if (barEdge === "right")
      x = sw - (panel ? panel.width : 0) + x
    else if (barEdge === "bottom")
      y = sh - (panel ? panel.height : 0) + y
    return { x: x, y: y, w: sw, h: sh }
  }

  // The bar already sits on an edge, so "nearest edge" would keep it there.
  // Use the drag direction instead: sideways from the bottom picks a side,
  // and dragging inward or downward from a side returns to the bottom.
  function edgeFromDrag(current, x0, y0, x1, y1, screenW, screenH) {
    var dx = x1 - x0
    var dy = y1 - y0
    var minTravel = 56
    if (Math.abs(dx) < minTravel && Math.abs(dy) < minTravel)
      return current === "left" || current === "right" ? current : "bottom"
    if (current === "left") {
      if (dx >= minTravel && x1 > screenW * 0.55) return "right"
      if (dx >= minTravel || dy >= minTravel) return "bottom"
      return "left"
    }
    if (current === "right") {
      if (dx <= -minTravel && x1 < screenW * 0.45) return "left"
      if (dx <= -minTravel || dy >= minTravel) return "bottom"
      return "right"
    }
    if (dx <= -minTravel && Math.abs(dx) > Math.abs(dy) * 0.75) return "left"
    if (dx >= minTravel && Math.abs(dx) > Math.abs(dy) * 0.75) return "right"
    return "bottom"
  }

  function showEdgeHint(screen, x, y, edge) {
    tipText = edge === "left" ? "Left edge" : edge === "right" ? "Right edge" : "Bottom"
    tipScreen = screen
    tipX = x + Style.space(14)
    tipY = y
    tipVisible = true
  }

  function closeMenus() {
    if (menuItem && labelEdit)
      commitLabelEdit()
    menuOpen = false
    pickerOpen = false
    webOpen = false
    helpOpen = false
    menuItem = null
    labelDraft = ""
    labelEdit = false
    labelEditTarget = ""
    pickerQuery = ""
    pickerSelectedIndex = 0
    pickerKind = "app"
    webName = ""
    webUrl = ""
    webFocus = "name"
    hideIconTip()
    releaseRevealSoon()
  }

  function ensureMenuScreen() {
    if (menuScreen) return
    var name = ""
    try {
      var mon = Hyprland.focusedMonitor
      if (mon && mon.name) name = String(mon.name)
    } catch (e) {
    }
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && name && screens[i].name === name) {
        menuScreen = screens[i]
        return
      }
    }
    if (screens.length) menuScreen = screens[0]
  }

  function appendFilter(current, event) {
    if (!event) return current
    if (Util.editsFilter(event, current))
      return Util.editedFilter(event, current)
    if (event.text && event.text.length === 1
        && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
        && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier))
      return current + event.text
    return current
  }

  function handlePickerKey(event) {
    if (!event) return
    if (event.key === Qt.Key_Escape) {
      if (pickerQuery.length) {
        pickerQuery = ""
        pickerSelectedIndex = 0
      } else {
        closeMenus()
      }
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Up) {
      pickerSelectedIndex = Math.max(0, pickerSelectedIndex - 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Down) {
      var max = pickerModel && pickerModel.length ? pickerModel.length - 1 : 0
      pickerSelectedIndex = Math.min(max, pickerSelectedIndex + 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (pickerModel && pickerModel.length > 0) {
        var idx = Math.min(Math.max(0, pickerSelectedIndex), pickerModel.length - 1)
        acceptPickerRow(pickerModel[idx])
      }
      event.accepted = true
      return
    }
    var next = appendFilter(pickerQuery, event)
    if (next !== pickerQuery) {
      pickerQuery = next
      pickerSelectedIndex = 0
      event.accepted = true
    }
  }

  function handleWebKey(event) {
    if (!event) return
    var current = webFocus === "url" ? webUrl : webName
    if (event.key === Qt.Key_Escape) {
      if (current.length) {
        if (webFocus === "url") webUrl = ""
        else webName = ""
      } else {
        closeMenus()
      }
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
      webFocus = "name"
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
      webFocus = "url"
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (webFocus === "name") webFocus = "url"
      else acceptWeb()
      event.accepted = true
      return
    }
    var next = appendFilter(current, event)
    if (next !== current) {
      if (webFocus === "url") webUrl = next
      else webName = next
      event.accepted = true
    }
  }

  function hideIconTip() {
    tipRequest += 1
    tipDelay.stop()
    tipVisible = false
    tipText = ""
    tipScreen = null
  }

  function showIconTip(screen, globalX, globalY, text) {
    var label = String(text || "")
    if (!showTips || !label.length || dragging || menuOpen || pickerOpen || webOpen) {
      hideIconTip()
      return
    }
    tipText = label
    tipScreen = screen
    // Screen-local coords for the tip panel; sit above the dock, right of cursor.
    tipX = globalX - (screen ? screen.x : 0) + Style.space(12)
    tipY = globalY - (screen ? screen.y : 0)
    if (tipVisible)
      return
    tipDelay.restart()
  }

  function refreshIconTipPosition(screen, globalX, globalY) {
    if (!tipVisible && !tipDelay.running) return
    if (screen) tipScreen = screen
    tipX = globalX - (screen ? screen.x : 0) + Style.space(12)
    tipY = globalY - (screen ? screen.y : 0)
  }

  function setHovered(hovered) {
    hoverCount = Math.max(0, hoverCount + (hovered ? 1 : -1))
    if (hoverCount === 0) {
      if (cursorKeepsBar())
        armReveal()
      else
        hideTimer.restart()
    } else {
      hideTimer.stop()
      revealHeld = true
    }
  }

  function armReveal() {
    hideTimer.stop()
    revealHeld = true
  }

  function releaseRevealSoon() {
    if (cursorKeepsBar()) {
      armReveal()
      return
    }
    if (!hovered && !uiHeld)
      hideTimer.restart()
  }

  function hyprMonitorByName(name) {
    var want = String(name || "")
    if (!want.length) return null
    var mons = []
    try { mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [] } catch (e) { mons = [] }
    for (var i = 0; i < mons.length; i++) {
      if (mons[i] && String(mons[i].name || "") === want)
        return mons[i]
    }
    return null
  }

  // Remember the screen whose edge was just shown. The pointer can slide off
  // that screen, past the bar, and the bar should stay out until the pointer
  // comes back onto the screen on the inner side of the bar.
  function noteEdgeHold(screen) {
    var mon = hyprMonitorByName(screen ? screen.name : "")
    var x = 0
    var y = 0
    var w = 0
    var h = 0
    if (mon) {
      x = Number(mon.x) || 0
      y = Number(mon.y) || 0
      w = Number(mon.width) || 0
      h = Number(mon.height) || 0
    } else if (screen) {
      x = Number(screen.x) || 0
      y = Number(screen.y) || 0
      w = Number(screen.width) || 0
      h = Number(screen.height) || 0
    } else {
      return
    }
    edgeHoldSide = barEdge
    if (barEdge === "left")
      edgeHoldLimit = x + dockHeight
    else if (barEdge === "right")
      edgeHoldLimit = x + w - dockHeight
    else
      edgeHoldLimit = y + h - dockHeight
    edgeHoldActive = true
    if (!pointerProc.running)
      pointerProc.running = true
  }

  function cursorKeepsBar() {
    if (!pointerKnown || !edgeHoldActive || edgeHoldSide !== barEdge)
      return false
    if (barEdge === "left")
      return pointerX <= edgeHoldLimit
    if (barEdge === "right")
      return pointerX >= edgeHoldLimit
    return pointerY >= edgeHoldLimit
  }

  function notePointer(x, y) {
    var wasKeeping = cursorKeepsBar()
    pointerX = x
    pointerY = y
    pointerKnown = true
    if (cursorKeepsBar())
      armReveal()
    else if (wasKeeping && revealHeld && !hovered && !uiHeld)
      hideTimer.restart()
  }

  function persistSettings() {
    if (_loadingConfig || _switchingWorkspace) return
    if (workspaceTouched[DockModel.workspaceKey(workspaceId)])
      workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, workspaceId, layout)
    // Keep a non-empty shared default so new workspaces inherit icons.
    if (!DockModel.isEmpty(layout) && DockModel.isEmpty(defaultLayout))
      defaultLayout = DockModel.cloneLayout(layout)
    if (shell && typeof shell.updateEntryInline === "function") {
      var payload = {
        layout: DockModel.isEmpty(layout) ? DockModel.cloneLayout(defaultLayout) : DockModel.cloneLayout(layout),
        defaultLayout: DockModel.cloneLayout(defaultLayout),
        workspaces: DockModel.pruneEmptyWorkspaceLayouts(workspaceLayouts, defaultLayout),
        iconSize: iconSize,
        bgOpacity: bgOpacity,
        bgColorKey: bgColorKey,
        bgColorHex: bgColorHex,
        showTips: showTips,
        barEdge: barEdge === "left" || barEdge === "right" ? barEdge : "bottom"
      }
      try { payload = JSON.parse(JSON.stringify(payload)) } catch (e) {}
      shell.updateEntryInline(pluginId, payload)
    }
  }

  function persistLayout(next) {
    layout = DockModel.cloneLayout(next)
    var key = DockModel.workspaceKey(workspaceId)
    var touched = Object.assign({}, workspaceTouched)
    touched[key] = true
    workspaceTouched = touched
    workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, key, layout)
    persistSettings()
  }

  function layoutForWorkspaceKey(id) {
    var key = DockModel.workspaceKey(id)
    if (key === DockModel.workspaceKey(workspaceId))
      return layout
    if (Object.prototype.hasOwnProperty.call(workspaceLayouts, key))
      return workspaceLayouts[key]
    return defaultLayout
  }

  function itemPresentOnWorkspace(itemId, id) {
    return !!DockModel.findItem(layoutForWorkspaceKey(id), itemId)
  }

  function setItemPlaceSection(section) {
    var key = section === "left" || section === "right" ? section : "center"
    itemPlaceSection = key
    if (!menuItem) return
    persistLayout(DockModel.moveItem(layout, menuItem.id, key))
  }

  function setItemOnWorkspace(item, id, enabled) {
    if (!item || !item.id) return
    var key = DockModel.workspaceKey(id)
    var copy = DockModel.cloneItem(item)
    if (!copy) return
    var current = DockModel.cloneLayout(layoutForWorkspaceKey(key))
    var next = enabled
      ? DockModel.addItem(current, itemPlaceSection, copy)
      : DockModel.removeItem(current, copy.id)
    if (key === DockModel.workspaceKey(workspaceId)) {
      persistLayout(next)
      return
    }
    var touched = Object.assign({}, workspaceTouched)
    touched[key] = true
    workspaceTouched = touched
    workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, key, next)
    persistSettings()
  }

  function currentHyprWorkspaceId() {
    try {
      var ws = Hyprland.focusedWorkspace
      if (ws && ws.id !== undefined && ws.id !== null)
        return ws.id
    } catch (e) {
    }
    return 1
  }

  // Workspace currently shown on a given Quickshell screen (the monitor's
  // active workspace), not Hyprland.focusedWorkspace. Cursor focus can move
  // to another output while this monitor keeps its workspace.
  function workspaceIdForScreen(screen) {
    var _focus = Hyprland.focusedWorkspace
    var name = screen ? String(screen.name || "") : ""
    if (!name.length) return DockModel.workspaceKey(currentHyprWorkspaceId())
    var mons = []
    try { mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [] } catch (e) { mons = [] }
    for (var i = 0; i < mons.length; i++) {
      var m = mons[i]
      if (!m || String(m.name || "") !== name) continue
      var ws = m.activeWorkspace
      if (ws && ws.id !== undefined && ws.id !== null)
        return DockModel.workspaceKey(ws.id)
    }
    return DockModel.workspaceKey(currentHyprWorkspaceId())
  }

  function syncWorkspaceForScreen(screen) {
    if (!screen) return
    var next = workspaceIdForScreen(screen)
    if (DockModel.workspaceKey(next) === DockModel.workspaceKey(workspaceId))
      return
    _switchingWorkspace = true
    applyWorkspace(next, true)
    _switchingWorkspace = false
  }

  function applyWorkspace(id, persistPrevious) {
    var nextId = DockModel.workspaceKey(id)
    var prevId = DockModel.workspaceKey(workspaceId)
    if (persistPrevious && prevId !== nextId && workspaceTouched[prevId])
      workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, prevId, layout)
    workspaceId = nextId
    if (Object.prototype.hasOwnProperty.call(workspaceLayouts, nextId))
      layout = DockModel.cloneLayout(workspaceLayouts[nextId])
    else
      layout = DockModel.cloneLayout(defaultLayout)
  }

  function syncWorkspaceFromHyprland() {
    var next = focusedWorkspaceKey
    if (DockModel.workspaceKey(next) === DockModel.workspaceKey(workspaceId))
      return
    _switchingWorkspace = true
    applyWorkspace(next, true)
    _switchingWorkspace = false
    // Only persist when a customized workspace changed; avoids writing empties.
    if (workspaceTouched[DockModel.workspaceKey(workspaceId)]
        || workspaceTouched[DockModel.workspaceKey(next)])
      persistSettings()
  }

  function bumpIconSize(delta) {
    iconSize = DockModel.clampIconSize(iconSize + delta)
    persistSettings()
  }

  function bumpBgOpacity(delta) {
    bgOpacity = DockModel.clampBgOpacity(bgOpacity + delta)
    persistSettings()
  }

  function setBarBackground(key, hex) {
    bgColorKey = String(key || "")
    bgColorHex = String(hex || "")
    persistSettings()
  }

  function beginLabelEdit() {
    if (!menuItem || menuItem.kind === "keybind") return
    labelEditTarget = "label"
    labelDraft = DockModel.itemLabel(menuItem)
    labelEdit = true
  }

  function beginKeybindDescEdit() {
    if (!menuItem || menuItem.kind !== "keybind") return
    labelEditTarget = "desc"
    // The description is its own name. Do not seed it from the three-letter mark.
    labelDraft = String(menuItem.label || "").slice(0, 20)
    labelEdit = true
  }

  function beginKeybindBadgeEdit() {
    if (!menuItem || menuItem.kind !== "keybind") return
    labelEditTarget = "badge"
    labelDraft = String(menuItem.badge || "").slice(0, 3)
    labelEdit = true
  }

  function cancelLabelEdit() {
    var target = labelEditTarget
    labelEdit = false
    labelEditTarget = ""
    if (!menuItem) return
    labelDraft = target === "badge"
      ? String(menuItem.badge || "")
      : DockModel.itemLabel(menuItem)
  }

  function commitLabelEdit() {
    if (!menuItem) {
      labelEdit = false
      labelEditTarget = ""
      return
    }
    if (labelEditTarget === "badge") {
      var mark = String(labelDraft || "").replace(/[^A-Za-z0-9]/g, "").toUpperCase().slice(0, 3)
      if (mark.length && mark !== String(menuItem.badge || "").toUpperCase()) {
        persistLayout(DockModel.setItemBadge(layout, menuItem.id, mark))
        var marked = DockModel.findItem(layout, menuItem.id)
        if (marked)
          menuItem = marked
      }
      labelDraft = menuItem ? String(menuItem.badge || "") : ""
      labelEdit = false
      labelEditTarget = ""
      return
    }
    var name = String(labelDraft || "").trim().slice(0, 20)
    if (!name.length) {
      labelDraft = DockModel.itemLabel(menuItem)
      labelEdit = false
      labelEditTarget = ""
      return
    }
    if (name !== DockModel.itemLabel(menuItem)) {
      persistLayout(DockModel.renameItem(layout, menuItem.id, name))
      var found = DockModel.findItem(layout, menuItem.id)
      if (found)
        menuItem = found
    }
    labelDraft = DockModel.itemLabel(menuItem)
    labelEdit = false
    labelEditTarget = ""
  }

  function setShowTips(enabled) {
    showTips = !!enabled
    if (!showTips) hideIconTip()
    persistSettings()
  }

  function toggleShowTips() {
    setShowTips(!showTips)
  }

  function handleDockWheel(wheel) {
    if (!wheel) return
    var mods = wheel.modifiers
    // Alt+wheel → background opacity (also accept Meta/Alt combos that still include Alt).
    if (mods & Qt.AltModifier) {
      if (wheel.angleDelta.y > 0) bumpBgOpacity(5)
      else if (wheel.angleDelta.y < 0) bumpBgOpacity(-5)
      wheel.accepted = true
      return
    }
    if (wheel.angleDelta.y > 0) bumpIconSize(2)
    else if (wheel.angleDelta.y < 0) bumpIconSize(-2)
    wheel.accepted = true
  }

  // Super+Plus / Super+Minus (via Hyprland binds → IPC) only when cursor is on the dock.
  function iconsLargerFromHotkey() {
    if (!hovered) return "ignored"
    bumpIconSize(4)
    return "ok"
  }

  function iconsSmallerFromHotkey() {
    if (!hovered) return "ignored"
    bumpIconSize(-4)
    return "ok"
  }

  function opacityUpFromHotkey() {
    if (!hovered) return "ignored"
    bumpBgOpacity(5)
    return "ok"
  }

  function opacityDownFromHotkey() {
    if (!hovered) return "ignored"
    bumpBgOpacity(-5)
    return "ok"
  }

  function startIconDrag(item, screen) {
    if (!item) return
    syncWorkspaceForScreen(screen)
    closeMenus()
    hideIconTip()
    dragging = true
    dragItem = item
    dropSection = ""
    dropIndex = 0
    dragGhostSource = item.kind === "keybind" ? "" : iconSource(item.icon)
    dragGhostBadge = item.kind === "keybind" ? String(item.badge || "").slice(0, 3) : ""
    armReveal()
  }

  function updateIconDragGhost(chromeX, chromeY) {
    dragGhostX = chromeX - iconSlot / 2
    dragGhostY = chromeY - iconSlot / 2
  }

  function setIconDropTarget(section, index) {
    dropSection = section
    dropIndex = Math.max(0, Math.round(Number(index) || 0))
  }

  function commitIconDrag() {
    if (dragging && dragItem && dropSection)
      persistLayout(DockModel.moveItemAt(layout, dragItem.id, dropSection, dropIndex))
    cancelIconDrag()
  }

  function cancelIconDrag() {
    dragging = false
    dragItem = null
    dropSection = ""
    dropIndex = 0
    dragGhostSource = ""
    dragGhostBadge = ""
    releaseRevealSoon()
  }

  function loadDockConfig(rawText) {
    _loadingConfig = true
    var cfg = DockModel.parseDockConfig(rawText, pluginId)
    workspaceId = DockModel.workspaceKey(currentHyprWorkspaceId())

    var maps = cfg.hasWorkspaceMap ? cfg.workspaces : ({})
    var seed = emptySeed(cfg, maps)
    defaultLayout = DockModel.cloneLayout(seed)
    workspaceLayouts = DockModel.pruneEmptyWorkspaceLayouts(maps, defaultLayout)

    if (!DockModel.isEmpty(defaultLayout)
        && !Object.prototype.hasOwnProperty.call(workspaceLayouts, workspaceId)
        && !cfg.hasWorkspaceMap) {
      workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, workspaceId, defaultLayout)
    }

    if (Object.prototype.hasOwnProperty.call(workspaceLayouts, workspaceId))
      layout = DockModel.cloneLayout(workspaceLayouts[workspaceId])
    else
      layout = DockModel.cloneLayout(defaultLayout)

    var touched = ({})
    for (var key in workspaceLayouts) {
      if (Object.prototype.hasOwnProperty.call(workspaceLayouts, key))
        touched[String(key)] = true
    }
    workspaceTouched = touched

    var nextIcon = cfg.iconSize > 0 ? cfg.iconSize : DockModel.defaultIconSize()
    iconSize = DockModel.clampIconSize(nextIcon)
    bgOpacity = cfg.bgOpacity >= 0
      ? DockModel.clampBgOpacity(cfg.bgOpacity)
      : DockModel.defaultBgOpacity()
    bgColorKey = String(cfg.bgColorKey || "")
    bgColorHex = String(cfg.bgColorHex || "")
    showTips = cfg.showTips !== false
    barEdge = cfg.barEdge === "left" || cfg.barEdge === "right" ? cfg.barEdge : "bottom"
    _loadingConfig = false
    persistSettings()
  }

  function emptySeed(cfg, maps) {
    if (cfg.hasDefaultLayout)
      return cfg.defaultLayout
    return DockModel.firstNonEmptyLayout(maps, cfg.layout)
  }

  function iconSource(name) {
    var value = String(name || "")
    if (!value.length)
      return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("file://") === 0 || value.indexOf("/") === 0)
      return value.indexOf("file://") === 0 ? value : Util.fileUrl(value)
    var themed = Quickshell.iconPath(value, true)
    return themed.length ? themed : Quickshell.iconPath("application-x-executable", true)
  }

  function desktopEntryForItem(item) {
    var want = String((item && (item.desktopId || item.id)) || "")
    if (!want.length) return null
    var wantLower = want.toLowerCase()
    var apps = desktopApps || []
    for (var i = 0; i < apps.length; i++) {
      var app = apps[i]
      if (!app) continue
      var id = String(app.id || "")
      if (id === want || id.toLowerCase() === wantLower) return app
      if (String(app.name || "").toLowerCase() === wantLower) return app
    }
    return null
  }

  function matchKeysForItem(item) {
    var keys = []
    var entry = desktopEntryForItem(item)
    if (!entry) return keys
    if (entry.startupClass) keys.push(String(entry.startupClass))
    var ids = DockModel.chromeWebAppIds(DockModel.webAppUrlFromExec(entry.execString))
    for (var i = 0; i < ids.length; i++) keys.push(ids[i])
    return keys
  }

  function windowMatchesItem(item, toplevel) {
    return DockModel.itemMatchesToplevelKeys(item, toplevel, matchKeysForItem(item))
  }

  function hyprToplevels() {
    var _rev = toplevelRevision
    var values = []
    try { values = Hyprland.toplevels.values || [] } catch (e) { values = [] }
    return values
  }

  function toplevelWorkspaceId(top) {
    if (!top) return ""
    try {
      if (top.workspace && top.workspace.id !== undefined && top.workspace.id !== null)
        return String(top.workspace.id)
    } catch (e) {}
    var ipc = top.lastIpcObject
    if (ipc && ipc.workspace && ipc.workspace.id !== undefined && ipc.workspace.id !== null)
      return String(ipc.workspace.id)
    return ""
  }

  function toplevelView(top) {
    var appId = ""
    try {
      if (top.wayland && top.wayland.appId)
        appId = String(top.wayland.appId)
    } catch (e) {}
    if (!appId.length) {
      var ipc = top.lastIpcObject
      if (ipc && ipc.class)
        appId = String(ipc.class)
    }
    return { appId: appId, activated: !!top.activated, title: String(top.title || "") }
  }

  function findToplevelForItem(item, workspaceId) {
    if (!item) return null
    var want = String(workspaceId || "")
    var values = hyprToplevels()
    var any = null
    for (var i = 0; i < values.length; i++) {
      var raw = values[i]
      if (!raw) continue
      if (want.length && toplevelWorkspaceId(raw) !== want) continue
      var view = toplevelView(raw)
      if (!windowMatchesItem(item, view)) continue
      if (raw.activated) return raw
      if (!any) any = raw
    }
    return any
  }

  function normAddr(value) {
    var s = String(value || "").trim().toLowerCase()
    if (s.slice(0, 2) === "0x") s = s.slice(2)
    return s
  }

  function purgeClosed(now) {
    var map = closedAddresses || {}
    var next = ({})
    var changed = false
    for (var k in map) {
      if (!Object.prototype.hasOwnProperty.call(map, k)) continue
      if (now - Number(map[k]) < 2000) next[k] = map[k]
      else changed = true
    }
    if (changed) closedAddresses = next
    return next
  }

  function publishClients(next) {
    liveClients = next
    liveClientGen++
  }

  function applyClientSnapshot(raw) {
    var rows = []
    try { rows = JSON.parse(String(raw || "")) } catch (e) { return }
    if (!Array.isArray(rows)) return
    var closed = purgeClosed(Date.now())
    var next = []
    for (var i = 0; i < rows.length; i++) {
      var c = rows[i]
      if (!c || c.mapped === false || c.hidden === true) continue
      var addr = normAddr(c.address)
      if (addr && Object.prototype.hasOwnProperty.call(closed, addr)) continue
      var ws = c.workspace || {}
      var wsId = ""
      if (ws.id !== undefined && ws.id !== null) wsId = DockModel.workspaceKey(ws.id)
      else if (ws.name) wsId = DockModel.workspaceKey(ws.name)
      next.push({
        address: addr,
        className: String(c.class || ""),
        initialClass: String(c.initialClass || ""),
        workspaceId: wsId,
        focused: Number(c.focusHistoryID) === 0
      })
    }
    publishClients(next)
  }

  function requestClientSync() {
    if (clientSyncProc.running) {
      clientSyncAgain = true
      return
    }
    clientSyncProc.running = true
  }

  function forgetClient(addr) {
    var key = normAddr(addr)
    if (!key) return
    var map = Object.assign({}, closedAddresses || {})
    map[key] = Date.now()
    closedAddresses = map
    var rows = liveClients || []
    var next = []
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] && rows[i].address === key) continue
      next.push(rows[i])
    }
    publishClients(next)
  }

  function noteOpenedWindow(addr, workspaceName, className) {
    var key = normAddr(addr)
    if (!key) return
    var map = Object.assign({}, closedAddresses || {})
    if (Object.prototype.hasOwnProperty.call(map, key)) {
      delete map[key]
      closedAddresses = map
    }
    var rows = liveClients || []
    var next = []
    for (var i = 0; i < rows.length; i++) {
      var prev = rows[i]
      if (!prev || prev.address === key) continue
      next.push({
        address: prev.address,
        className: prev.className,
        initialClass: prev.initialClass,
        workspaceId: prev.workspaceId,
        focused: false
      })
    }
    next.push({
      address: key,
      className: String(className || ""),
      initialClass: String(className || ""),
      workspaceId: DockModel.workspaceKey(workspaceName),
      focused: true
    })
    publishClients(next)
  }

  function noteMovedWindow(addr, workspaceName) {
    var key = normAddr(addr)
    if (!key) return
    var rows = liveClients || []
    var next = []
    var found = false
    for (var i = 0; i < rows.length; i++) {
      var c = rows[i]
      if (!c) continue
      if (c.address !== key) {
        next.push(c)
        continue
      }
      found = true
      next.push({
        address: c.address,
        className: c.className,
        initialClass: c.initialClass,
        workspaceId: DockModel.workspaceKey(workspaceName),
        focused: c.focused
      })
    }
    if (found) publishClients(next)
  }

  function findKeybindClient(item, workspaceId) {
    var want = String(workspaceId || "")
    var rows = liveClients || []
    var any = null
    for (var i = 0; i < rows.length; i++) {
      var c = rows[i]
      if (!c) continue
      if (want.length && String(c.workspaceId || "") !== want) continue
      var hit = DockModel.keybindMatchesClass(item, c.className)
        || DockModel.keybindMatchesClass(item, c.initialClass)
      if (!hit) continue
      if (c.focused) return c
      if (!any) any = c
    }
    return any
  }

  function itemIsRunning(item, screen, _gen) {
    var ws = workspaceIdForScreen(screen)
    if (item && String(item.kind || "") === "keybind" && liveClientGen)
      return !!findKeybindClient(item, ws)
    return !!findToplevelForItem(item, ws)
  }

  function itemIsFocused(item, screen, _gen) {
    var ws = workspaceIdForScreen(screen)
    if (item && String(item.kind || "") === "keybind" && liveClientGen) {
      var client = findKeybindClient(item, ws)
      return !!(client && client.focused)
    }
    var found = findToplevelForItem(item, ws)
    return !!(found && found.activated)
  }

  function activateOrLaunch(item) {
    launchItem(item)
  }

  function launchItem(item) {
    if (!item) return
    if (item.kind === "keybind") {
      var script = home + "/.config/omarchy/plugins/drace3000.bottom-dock/dispatch-keybind.py"
      Util.execDetached("python3 " + Util.shellQuote(script) + " "
        + Util.shellQuote(String(item.bindDispatcher || "")) + " "
        + Util.shellQuote(String(item.bindArg || "")))
      return
    }
    if (item.kind === "plugin" && item.pluginId) {
      // Host IPC — scoped shell.summon cannot open arbitrary plugins.
      Util.execDetached("omarchy-shell -q shell toggle " + Util.shellQuote(String(item.pluginId)) + " '{}'")
      return
    }
    if (item.kind === "web" && item.url) {
      Util.execArgv(["xdg-open", String(item.url)])
      return
    }
    // Same launch as Super+Space. Every click starts another instance on
    // the current workspace instead of raising a window elsewhere.
    var id = String(item.desktopId || item.id || "")
    if (id && item.kind !== "plugin") {
      if (id.slice(-8) === ".desktop") id = id.slice(0, -8)
      Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(id + ".desktop"))
      return
    }
    if (item.exec) {
      Util.execDetached(String(item.exec))
      return
    }
  }

  function openDockMenu(screen, globalX, globalY) {
    syncWorkspaceForScreen(screen)
    menuItem = null
    helpOpen = false
    menuScreen = screen
    menuX = globalX - (screen ? screen.x : 0)
    menuY = globalY - (screen ? screen.y : 0)
    menuOpen = true
    pickerOpen = false
    webOpen = false
    armReveal()
  }

  function openItemMenu(screen, item, globalX, globalY) {
    syncWorkspaceForScreen(screen)
    helpOpen = false
    menuItem = item
    labelDraft = DockModel.itemLabel(item)
    labelEdit = false
    menuScreen = screen
    menuX = globalX - (screen ? screen.x : 0)
    menuY = globalY - (screen ? screen.y : 0)
    var loc = DockModel.findItemLocation(layout, item ? item.id : "")
    itemPlaceSection = loc && loc.section ? loc.section : "center"
    menuOpen = true
    pickerOpen = false
    webOpen = false
    armReveal()
  }

  function beginAdd(section) {
    pendingSection = section
    pickerKind = "app"
    menuOpen = false
    pickerQuery = ""
    pickerSelectedIndex = 0
    ensureMenuScreen()
    pickerOpen = true
    webOpen = false
    armReveal()
  }

  function beginAddPlugin(section) {
    pendingSection = section
    pickerKind = "plugin"
    menuOpen = false
    pickerQuery = ""
    pickerSelectedIndex = 0
    ensureMenuScreen()
    pickerOpen = true
    webOpen = false
    refreshPluginCatalog()
    armReveal()
  }

  function beginKeybindAdd(section) {
    pendingSection = section || "center"
    pickerKind = "keybind"
    menuOpen = false
    pickerQuery = ""
    pickerSelectedIndex = 0
    ensureMenuScreen()
    pickerOpen = true
    webOpen = false
    refreshKeybinds()
    armReveal()
  }

  function beginWebAdd(section) {
    pendingSection = section || "center"
    menuOpen = false
    pickerOpen = false
    webName = ""
    webUrl = ""
    webFocus = "name"
    ensureMenuScreen()
    webOpen = true
    armReveal()
  }

  function acceptApp(entry) {
    if (!entry) return
    persistLayout(DockModel.addItem(layout, pendingSection, DockModel.makeAppItem(entry)))
    closeMenus()
  }

  function acceptPlugin(plugin) {
    if (!plugin) return
    persistLayout(DockModel.addItem(layout, pendingSection, DockModel.makePluginItem(plugin)))
    closeMenus()
  }

  function acceptKeybind(row) {
    if (!row) return
    persistLayout(DockModel.addItem(layout, pendingSection, DockModel.makeKeybindItem(row, layout)))
    closeMenus()
  }

  function acceptPickerRow(row) {
    if (pickerKind === "plugin") acceptPlugin(row)
    else if (pickerKind === "keybind") acceptKeybind(row)
    else acceptApp(row)
  }

  function acceptWeb() {
    var name = String(webName || "").trim()
    var url = String(webUrl || "").trim()
    if (url && url.indexOf("://") < 0) url = "https://" + url
    if (!name && url)
      name = url.replace(/^https?:\/\//i, "").replace(/\/.*$/, "")
    if (!name || !url || url === "https://") return
    persistLayout(DockModel.addItem(layout, pendingSection, DockModel.makeWebItem(name, url)))
    closeMenus()
  }

  function refreshPluginCatalog() {
    if (!pluginListProc.running)
      pluginListProc.running = true
  }

  function refreshKeybinds() {
    if (!keybindListProc.running)
      keybindListProc.running = true
  }

  Process {
    id: pluginListProc
    command: ["python3", root.home + "/.config/omarchy/plugins/drace3000.bottom-dock/list-summonable-plugins.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var rows = DockModel.parsePluginCatalog(text, root.pluginId)
        // Script already filtered; accept either full listPlugins shape or our rows.
        if (rows.length === 0) {
          try {
            var direct = JSON.parse(String(text || "[]"))
            if (Array.isArray(direct)) {
              rows = []
              for (var i = 0; i < direct.length; i++) {
                var p = direct[i]
                if (!p || !p.id || String(p.id) === root.pluginId) continue
                rows.push({
                  id: String(p.id),
                  name: String(p.name || p.id),
                  kinds: Array.isArray(p.kinds) ? p.kinds : [],
                  icon: String(p.icon || DockModel.pluginIconFor(p.id))
                })
              }
            }
          } catch (e) {
          }
        }
        root.pluginCatalog = rows
      }
    }
  }

  Process {
    id: keybindListProc
    command: ["python3", root.home + "/.config/omarchy/plugins/drace3000.bottom-dock/list-keybinds.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var rows = JSON.parse(String(text || "[]"))
          root.keybindCatalog = Array.isArray(rows) ? rows : []
        } catch (e) {
          root.keybindCatalog = []
        }
      }
    }
  }

  function refreshBackgroundPalette() {
    if (bgPaletteProc.running)
      bgPaletteProc.running = false
    bgPaletteProc.running = true
  }

  Process {
    id: bgPaletteProc
    command: ["python3", root.home + "/.config/omarchy/plugins/drace3000.bottom-dock/extract-background-colors.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var pal = DockModel.parseWallpaperColors(text)
        if (pal.length)
          root.themePalette = pal
        else
          themeColorsFile.reload()
      }
    }
  }

  Process {
    id: clientSyncProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyClientSnapshot(text)
    }
    onRunningChanged: {
      if (running || !root.clientSyncAgain) return
      root.clientSyncAgain = false
      root.requestClientSync()
    }
  }

  Component.onCompleted: {
    root.refreshPluginCatalog()
    root.refreshBackgroundPalette()
    root.requestClientSync()
    // Align with the live workspace once Hyprland IPC is ready.
    Qt.callLater(function() { root.syncWorkspaceFromHyprland() })
  }

  Timer {
    id: tipDelay
    interval: 350
    onTriggered: {
      if (!root.tipText.length || root.dragging || root.menuOpen)
        return
      root.tipVisible = true
    }
  }

  Timer {
    id: hideTimer
    interval: 450
    onTriggered: {
      if (root.hovered || root.uiHeld || root.cursorKeepsBar())
        return
      root.revealHeld = false
    }
  }

  // While the bar is out, follow the pointer so sliding off the outer edge
  // of the screen does not count as leaving the bar.
  Timer {
    interval: 900
    repeat: true
    running: true
    onTriggered: root.runMarkPulse = root.runMarkPulse > 0.7 ? 0.28 : 1
  }

  Timer {
    id: pointerPoll
    interval: 120
    repeat: true
    running: true
    onTriggered: {
      if (root.autoHide && !pointerProc.running)
        pointerProc.running = true
    }
  }

  Process {
    id: pointerProc
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "")
        var parts = raw.split(",")
        if (parts.length < 2) return
        var x = Number(parts[0])
        var y = Number(parts[1])
        if (!isFinite(x) || !isFinite(y)) return
        root.notePointer(x, y)
      }
    }
  }

  property string backgroundStamp: ""
  readonly property color themeWatch: Color.background
  onThemeWatchChanged: root.refreshBackgroundPalette()
  onMenuOpenChanged: if (menuOpen) {
    root.refreshBackgroundPalette()
    bgStampProc.running = true
  }

  Process {
    id: bgStampProc
    command: ["stat", "-c", "%Y", root.home + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var stamp = String(text || "").trim()
        if (stamp && stamp !== root.backgroundStamp) {
          root.backgroundStamp = stamp
          root.refreshBackgroundPalette()
        }
      }
    }
  }

  Timer {
    interval: 1200
    running: root.menuOpen
    repeat: true
    onTriggered: {
      bgStampProc.running = false
      bgStampProc.running = true
    }
  }

  FileView {
    id: themeColorsFile
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: {
      if (!root.themePalette || root.themePalette.length === 0)
        root.themePalette = DockModel.parseThemeColors(text())
    }
    onFileChanged: reload()
  }

  FileView {
    path: root.home + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadDockConfig(text())
    onFileChanged: reload()
    onLoadFailed: {
      root.layout = DockModel.emptyLayout()
      root.defaultLayout = DockModel.emptyLayout()
      root.workspaceLayouts = ({})
      root.workspaceTouched = ({})
      root.iconSize = DockModel.defaultIconSize()
      root.bgOpacity = DockModel.defaultBgOpacity()
      root.bgColorKey = ""
      root.bgColorHex = ""
      root.showTips = true
      root.barEdge = "bottom"
    }
  }

  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  readonly property string focusedWorkspaceKey: DockModel.workspaceKey(
    focusedWorkspace && focusedWorkspace.id !== undefined ? focusedWorkspace.id : 1)

  onFocusedWorkspaceKeyChanged: {
    if (_loadingConfig) return
    root.syncWorkspaceFromHyprland()
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.toplevelRevision++ }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { root.toplevelRevision++ }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event && event.name || "")
      if (name === "openwindow" || name === "closewindow" || name === "movewindow"
          || name === "movewindowv2" || name === "activewindow" || name === "windowtitle"
          || name === "workspace" || name === "focusedmon")
        root.toplevelRevision++
      if (name === "openwindow") {
        var opened = []
        try { opened = event.parse(4) } catch (e) { opened = [] }
        if (opened && opened.length >= 3)
          root.noteOpenedWindow(opened[0], opened[1], opened[2])
        root.requestClientSync()
      } else if (name === "closewindow") {
        var closed = []
        try { closed = event.parse(1) } catch (e) { closed = [] }
        if (closed && closed.length)
          root.forgetClient(closed[0])
        root.requestClientSync()
      } else if (name === "movewindow" || name === "movewindowv2") {
        var moved = []
        try { moved = event.parse(name === "movewindowv2" ? 3 : 2) } catch (e) { moved = [] }
        if (moved && moved.length >= 2)
          root.noteMovedWindow(moved[0], moved[moved.length - 1])
        root.requestClientSync()
      } else if (name === "activewindowv2") {
        root.requestClientSync()
      }
    }
  }

  IpcHandler {
    target: "drace3000.bottom-dock"
    function iconsLarger(): string { return root.iconsLargerFromHotkey() }
    function iconsSmaller(): string { return root.iconsSmallerFromHotkey() }
    function opacityUp(): string { return root.opacityUpFromHotkey() }
    function opacityDown(): string { return root.opacityDownFromHotkey() }
    function previewBarDrag(x0: string, y0: string, x1: string, y1: string): string {
      return root.applyBarDrag(Number(x0), Number(y0), Number(x1), Number(y1), false)
    }
    function moveBarByDrag(x0: string, y0: string, x1: string, y1: string): string {
      return root.applyBarDrag(Number(x0), Number(y0), Number(x1), Number(y1), true)
    }
    function workspaceState(): string {
      var keys = []
      for (var k in root.workspaceLayouts) {
        if (Object.prototype.hasOwnProperty.call(root.workspaceLayouts, k))
          keys.push(String(k))
      }
      keys.sort()
      var monitors = []
      try {
        var mons = Hyprland.monitors.values || []
        for (var i = 0; i < mons.length; i++) {
          var m = mons[i]
          var ws = m ? m.activeWorkspace : null
          var wsKey = ws && ws.id !== undefined && ws.id !== null
            ? DockModel.workspaceKey(ws.id) : ""
          var shown = root.layoutForWorkspaceKey(wsKey || root.workspaceId)
          monitors.push({
            name: String(m && m.name ? m.name : ""),
            focused: !!(m && m.focused),
            workspaceId: String(wsKey),
            left: shown && shown.left ? shown.left.length : 0,
            center: shown && shown.center ? shown.center.length : 0,
            right: shown && shown.right ? shown.right.length : 0
          })
        }
      } catch (e) {
      }
      return JSON.stringify({
        workspaceId: String(root.workspaceId),
        focusedKey: String(root.focusedWorkspaceKey),
        keys: keys,
        monitors: monitors,
        left: root.layout.left ? root.layout.left.length : 0,
        center: root.layout.center ? root.layout.center.length : 0,
        right: root.layout.right ? root.layout.right.length : 0,
        hasShell: !!(root.shell && typeof root.shell.updateEntryInline === "function")
      })
    }
    function syncWorkspace(): string {
      root.syncWorkspaceFromHyprland()
      return workspaceState()
    }
    function closePicker(): string {
      root.closeMenus()
      return "ok"
    }
  }

  FileView {
    id: helpPosFile
    path: root.helpPosPath
    watchChanges: false
    printErrors: false
    atomicWrites: true
    onLoaded: root.applyHelpPosText(text())
  }

  Process {
    id: windowMoveBindProc
  }

  // Super is consumed by Hyprland, so register compositor binds that call IPC.
  // Actions no-op unless the pointer is over the dock.
  Process {
    id: hotkeyBindProc
    running: true
    command: [
      "hyprctl", "eval",
      "hl.unbind(\"SUPER + equal\")\n" +
      "hl.unbind(\"SUPER + SHIFT + equal\")\n" +
      "hl.unbind(\"SUPER + minus\")\n" +
      "hl.unbind(\"SUPER + KP_Add\")\n" +
      "hl.unbind(\"SUPER + KP_Subtract\")\n" +
      "hl.unbind(\"SUPER + bracketleft\")\n" +
      "hl.unbind(\"SUPER + bracketright\")\n" +
      "o.bind(\"SUPER + equal\", \"Larger bottom dock icons\", \"omarchy-shell -q drace3000.bottom-dock iconsLarger\", { repeating = true })\n" +
      "o.bind(\"SUPER + SHIFT + equal\", \"Larger bottom dock icons\", \"omarchy-shell -q drace3000.bottom-dock iconsLarger\", { repeating = true })\n" +
      "o.bind(\"SUPER + minus\", \"Smaller bottom dock icons\", \"omarchy-shell -q drace3000.bottom-dock iconsSmaller\", { repeating = true })\n" +
      "o.bind(\"SUPER + KP_Add\", \"Larger bottom dock icons\", \"omarchy-shell -q drace3000.bottom-dock iconsLarger\", { repeating = true })\n" +
      "o.bind(\"SUPER + KP_Subtract\", \"Smaller bottom dock icons\", \"omarchy-shell -q drace3000.bottom-dock iconsSmaller\", { repeating = true })\n" +
      "o.bind(\"SUPER + bracketright\", \"More opaque bottom dock\", \"omarchy-shell -q drace3000.bottom-dock opacityUp\", { repeating = true })\n" +
      "o.bind(\"SUPER + bracketleft\", \"More transparent bottom dock\", \"omarchy-shell -q drace3000.bottom-dock opacityDown\", { repeating = true })\n"
    ]
    onRunningChanged: if (!running) root.installEdgeDragBind()
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      DockPanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      EdgePanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      MenuPanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      TipPanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  component EdgePanel: PanelWindow {
    id: edgeWindow
    readonly property bool armed: root.autoHide && !root.revealed
    visible: armed
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-edge"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.left: root.barEdge === "left" || root.barEdge === "bottom"
    anchors.right: root.barEdge === "right" || root.barEdge === "bottom"
    anchors.top: root.barEdge !== "bottom"
    anchors.bottom: true
    implicitWidth: root.barEdge === "bottom" ? 0 : root.edgeSize
    implicitHeight: root.barEdge === "bottom" ? root.edgeSize : 0
    HoverHandler {
      enabled: edgeWindow.armed
      onHoveredChanged: {
        if (hovered) {
          if (edgeWindow.screen) root.noteEdgeHold(edgeWindow.screen)
          root.armReveal()
        } else if (!root.revealed) {
          root.releaseRevealSoon()
        }
      }
    }
  }

  component DockPanel: PanelWindow {
    id: dockWindow
    visible: true
    exclusionMode: root.autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock"
    WlrLayershell.layer: WlrLayer.Top
    anchors.left: root.barEdge === "left" || root.barEdge === "bottom"
    anchors.right: root.barEdge === "right" || root.barEdge === "bottom"
    anchors.top: root.barEdge !== "bottom"
    anchors.bottom: true
    margins.left: root.barEdge === "left" ? -root.slideOffset : 0
    margins.right: root.barEdge === "right" ? -root.slideOffset : 0
    margins.bottom: root.barEdge === "bottom" ? -root.slideOffset : 0
    implicitWidth: root.barEdge === "bottom" ? 0 : root.dockHeight
    implicitHeight: root.barEdge === "bottom" ? root.dockHeight : 0

    // Bind icons to this monitor's active workspace, not the globally
    // focused one. Moving the cursor to another output must not rewrite
    // this dock's icons. Match by output name so we do not call
    // Hyprland.monitorFor() from a PanelWindow binding (that loops).
    readonly property string screenWorkspaceId: {
      var _focus = Hyprland.focusedWorkspace
      var name = dockWindow.screen ? String(dockWindow.screen.name || "") : ""
      var mons = []
      try { mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [] } catch (e) { mons = [] }
      for (var i = 0; i < mons.length; i++) {
        var m = mons[i]
        if (!m || String(m.name || "") !== name) continue
        var ws = m.activeWorkspace
        if (ws && ws.id !== undefined && ws.id !== null)
          return DockModel.workspaceKey(ws.id)
      }
      return root.workspaceId
    }
    readonly property var screenLayout: {
      var _live = root.layout
      var _maps = root.workspaceLayouts
      var _fallback = root.defaultLayout
      var _current = root.workspaceId
      return root.layoutForWorkspaceKey(dockWindow.screenWorkspaceId)
    }
    readonly property bool layoutEmpty: DockModel.isEmpty(screenLayout)

    HoverHandler {
      onHoveredChanged: {
        if (hovered && dockWindow.screen)
          root.noteEdgeHold(dockWindow.screen)
        root.setHovered(hovered)
      }
      Component.onDestruction: if (hovered) root.setHovered(false)
    }

    Rectangle {
      id: chrome
      anchors.fill: parent
      color: Qt.rgba(root.barFill.r, root.barFill.g, root.barFill.b, root.bgOpacity / 100)
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
      border.width: 1

      WheelHandler {
        // Grab wheel over the whole chrome, including over icon MouseAreas.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
        onWheel: function(event) { root.handleDockWheel(event) }
      }

      MouseArea {
        id: barBlank
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        preventStealing: true
        property bool edgeDrag: false
        property real dragX0: 0
        property real dragY0: 0
        property real dragX1: 0
        property real dragY1: 0
        property real dragW: 0
        property real dragH: 0

        function superDrag(mouse) {
          return mouse.button === Qt.LeftButton && (mouse.modifiers & Qt.MetaModifier) !== 0
        }

        function trackEdge(localX, localY) {
          var pt = root.panelPointToScreen(dockWindow, localX, localY)
          dragX1 = pt.x
          dragY1 = pt.y
          dragW = pt.w
          dragH = pt.h
          if (dragW < 1 || dragH < 1) return
          var edge = root.edgeFromDrag(root.barEdge, dragX0, dragY0, dragX1, dragY1, dragW, dragH)
          root.showEdgeHint(dockWindow.screen, dragX1, dragY1, edge)
        }

        onEntered: {
          if (!root.showTips) return
          var g = mapToGlobal(mouseX, 0)
          root.showIconTip(dockWindow.screen, g.x, g.y, root.blankBarTip)
        }
        onPressed: function(mouse) {
          if (!superDrag(mouse)) {
            if (mouse.button !== Qt.RightButton)
              mouse.accepted = false
            return
          }
          var pt = root.panelPointToScreen(dockWindow, mouse.x, mouse.y)
          edgeDrag = true
          dragX0 = pt.x
          dragY0 = pt.y
          dragX1 = pt.x
          dragY1 = pt.y
          dragW = pt.w
          dragH = pt.h
          root.barEdgeDragging = true
          root.armReveal()
          root.showEdgeHint(dockWindow.screen, pt.x, pt.y, root.barEdge)
          mouse.accepted = true
        }
        onPositionChanged: function(mouse) {
          if (edgeDrag && (mouse.buttons & Qt.LeftButton)) {
            trackEdge(mouse.x, mouse.y)
            return
          }
          if (!containsMouse || !root.showTips || root.dragging || root.barEdgeDragging || root.menuOpen) return
          var g = mapToGlobal(mouse.x, 0)
          root.refreshIconTipPosition(dockWindow.screen, g.x, g.y)
          if (root.tipVisible && root.tipText === root.blankBarTip) return
          if (!root.tipVisible && tipDelay.running && root.tipText === root.blankBarTip) return
          root.showIconTip(dockWindow.screen, g.x, g.y, root.blankBarTip)
        }
        onReleased: function(mouse) {
          if (!edgeDrag) return
          trackEdge(mouse.x, mouse.y)
          edgeDrag = false
          var edge = root.barEdge
          if (dragW > 1 && dragH > 1)
            edge = root.edgeFromDrag(root.barEdge, dragX0, dragY0, dragX1, dragY1, dragW, dragH)
          root.barEdgeDragging = false
          root.setBarEdge(edge)
          root.hideIconTip()
        }
        onExited: {
          if (root.tipText === root.blankBarTip)
            root.hideIconTip()
        }
        onClicked: function(mouse) {
          if (mouse.button !== Qt.RightButton) return
          root.hideIconTip()
          var g = mapToGlobal(mouse.x, mouse.y)
          root.openDockMenu(dockWindow.screen, g.x, g.y)
        }
        onWheel: function(wheel) { root.handleDockWheel(wheel) }
      }

      Text {
        visible: dockWindow.layoutEmpty
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "Hello World"
        color: root.ink
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Item {
        id: dockRow
        visible: !dockWindow.layoutEmpty
        anchors.fill: parent
        anchors.margins: Style.space(10)

        readonly property bool vertical: root.barEdge !== "bottom"
        readonly property int sectionGap: Style.space(4)

        function sectionAt(chromeX, chromeY) {
          function hit(sectionItem, name) {
            if (!sectionItem) return null
            var p = sectionItem.mapFromItem(chrome, chromeX, chromeY)
            var padX = root.dragging ? Style.space(10) : 0
            var padY = root.dragging ? Style.space(8) : 0
            if (p.x >= -padX && p.x <= sectionItem.width + padX
                && p.y >= -padY && p.y <= sectionItem.height + padY) {
              var pitch = root.iconSlot + dockRow.sectionGap
              var along = dockRow.vertical ? p.y : p.x
              var idx = pitch > 0 ? Math.round(along / pitch) : 0
              var count = sectionItem.model ? sectionItem.model.length : 0
              // If dragging within this section, model still includes the item.
              if (idx < 0) idx = 0
              if (idx > count) idx = count
              return { section: name, index: idx }
            }
            return null
          }

          var leftHit = hit(leftSection, "left")
          if (leftHit) return leftHit
          var centerHit = hit(centerSection, "center")
          if (centerHit) return centerHit
          var rightHit = hit(rightSection, "right")
          if (rightHit) return rightHit

          // Spacers / empty zones: thirds along the bar.
          var shown = dockWindow.screenLayout
          var rel = dockRow.vertical
            ? chromeY / Math.max(1, chrome.height)
            : chromeX / Math.max(1, chrome.width)
          if (rel < 0.33) {
            var leftCount = shown && shown.left ? shown.left.length : 0
            return { section: "left", index: leftCount }
          }
          if (rel > 0.66) {
            var rightCount = shown && shown.right ? shown.right.length : 0
            return { section: "right", index: rightCount }
          }
          var centerCount = shown && shown.center ? shown.center.length : 0
          return { section: "center", index: centerCount }
        }

        function trackDragAt(chromeX, chromeY) {
          root.updateIconDragGhost(chromeX, chromeY)
          var target = sectionAt(chromeX, chromeY)
          if (target) root.setIconDropTarget(target.section, target.index)
        }

        DockSection {
          id: leftSection
          sectionName: "left"
          x: dockRow.vertical ? (parent.width - width) / 2 : 0
          y: dockRow.vertical ? 0 : (parent.height - height) / 2
          width: implicitWidth
          height: implicitHeight
          model: (dockWindow.screenLayout && dockWindow.screenLayout.left) ? dockWindow.screenLayout.left : []
          hostScreen: dockWindow.screen
          chromeItem: chrome
          trackDrag: dockRow.trackDragAt
        }

        DockSection {
          id: centerSection
          sectionName: "center"
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          width: implicitWidth
          height: implicitHeight
          model: (dockWindow.screenLayout && dockWindow.screenLayout.center) ? dockWindow.screenLayout.center : []
          hostScreen: dockWindow.screen
          chromeItem: chrome
          trackDrag: dockRow.trackDragAt
        }

        DockSection {
          id: rightSection
          sectionName: "right"
          x: dockRow.vertical ? (parent.width - width) / 2 : parent.width - width
          y: dockRow.vertical ? parent.height - height : (parent.height - height) / 2
          width: implicitWidth
          height: implicitHeight
          model: (dockWindow.screenLayout && dockWindow.screenLayout.right) ? dockWindow.screenLayout.right : []
          hostScreen: dockWindow.screen
          chromeItem: chrome
          trackDrag: dockRow.trackDragAt
        }
      }

      // Drag ghost + insert marker overlay
      Item {
        anchors.fill: parent
        visible: root.dragging
        z: 100

        // Drop insert caret in the active section
        Rectangle {
          id: insertCaret
          visible: root.dropSection !== ""
          readonly property bool verticalBar: root.barEdge !== "bottom"
          readonly property var sectionItem: root.dropSection === "left" ? leftSection
            : root.dropSection === "right" ? rightSection
            : centerSection
          readonly property real along: {
            var pitch = root.iconSlot + Style.space(4)
            var local = root.dropIndex * pitch - 1
            if (!sectionItem) return 0
            var mapped = verticalBar
              ? mapFromItem(sectionItem, 0, local)
              : mapFromItem(sectionItem, local, 0)
            return verticalBar ? mapped.y : mapped.x
          }
          width: verticalBar ? root.iconSlot : 2
          height: verticalBar ? 2 : root.iconSlot
          radius: 1
          color: root.ink
          opacity: 0.85
          x: verticalBar ? (sectionItem ? mapFromItem(sectionItem, 0, 0).x : 0) : along
          y: verticalBar ? along : (parent.height - height) / 2
        }

        Rectangle {
          id: dragGhost
          width: root.iconSlot
          height: root.iconSlot
          radius: Style.space(8)
          x: root.dragGhostX
          y: root.dragGhostY
          color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.92)
          border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
          border.width: 1
          opacity: 0.95

          Text {
            visible: root.dragGhostBadge.length > 0
            anchors.centerIn: parent
            text: root.dragGhostBadge
            textFormat: Text.PlainText
            color: root.ink
            font.family: Style.font.menuFamily
            font.pixelSize: Math.max(10, Math.round(root.iconSlot * 0.34))
            font.bold: true
          }

          Image {
            visible: root.dragGhostBadge.length === 0
            anchors.centerIn: parent
            width: root.iconSlot - Style.space(2)
            height: width
            source: root.dragGhostSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: ghostRoundMask
              maskThresholdMin: 0.5
              maskSpreadAtMin: 0.18
            }
          }

          Rectangle {
            id: ghostRoundMask
            width: root.iconSlot - Style.space(2)
            height: width
            visible: false
            color: "#ffffff"
            radius: Math.max(4, Math.round(width * 0.22))
            layer.enabled: true
            layer.smooth: true
          }
        }
      }
    }
  }

  component DockSection: Item {
    id: sectionRoot
    property string sectionName: "center"
    property var model: []
    property var hostScreen: null
    property Item chromeItem: null
    property var trackDrag: null
    readonly property bool vertical: root.barEdge !== "bottom"
    readonly property int iconPitch: root.iconSlot + Style.space(4)
    readonly property int iconCount: model ? model.length : 0
    implicitWidth: vertical
      ? root.iconSlot
      : Math.max(iconCount > 0 ? iconCount * iconPitch - Style.space(4) : 0, root.dragging ? root.iconSlot : 0)
    implicitHeight: vertical
      ? Math.max(iconCount > 0 ? iconCount * iconPitch - Style.space(4) : 0, root.dragging ? root.iconSlot : 0)
      : root.iconSlot

    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      visible: root.dragging && root.dropSection === sectionRoot.sectionName
      color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
    }

    Item {
      id: sectionRow
      anchors.fill: parent

      Repeater {
        model: sectionRoot.model
        delegate: Item {
          id: iconWrap
          required property var modelData
          required property int index
          x: sectionRoot.vertical ? 0 : index * sectionRoot.iconPitch
          y: sectionRoot.vertical ? index * sectionRoot.iconPitch : 0
          width: root.iconSlot
          height: root.iconSlot
          opacity: root.dragging && root.dragItem && root.dragItem.id === modelData.id ? 0.35 : 1

          Rectangle {
            id: hoverBg
            anchors.fill: parent
            anchors.margins: iconMouse.containsMouse && !root.dragging ? 0 : 1
            radius: Style.space(8)
            color: iconMouse.containsMouse && !root.dragging
              ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28)
              : "transparent"
            border.width: iconMouse.containsMouse && !root.dragging ? 1 : 0
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on anchors.margins { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          }

          Item {
            id: iconClip
            anchors.centerIn: parent
            width: root.iconSlot - Style.space(2)
            height: width
            scale: iconMouse.containsMouse && !root.dragging ? 1.12 : 1.0
            layer.enabled: cornerProbe.sharp
            layer.smooth: true
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: iconRoundMask
              maskThresholdMin: 0.5
              maskSpreadAtMin: 0.18
            }

            Behavior on scale {
              NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            Image {
              id: iconImage
              visible: iconWrap.modelData.kind !== "keybind"
              anchors.fill: parent
              source: visible ? root.iconSource(iconWrap.modelData.icon) : ""
              fillMode: Image.PreserveAspectFit
              smooth: true
              asynchronous: true
              onStatusChanged: if (status === Image.Ready) cornerProbe.scan()
              onSourceChanged: cornerProbe.scan()
            }
          }

          Rectangle {
            id: keybindBadge
            readonly property bool hot: iconMouse.containsMouse && !root.dragging
            visible: iconWrap.modelData.kind === "keybind"
            anchors.fill: iconClip
            scale: hot ? 1.12 : 1.0
            radius: Style.space(8)
            color: hot ? root.surface : root.ink
            border.width: hot ? 2 : 1
            border.color: root.ink

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale {
              NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            Text {
              anchors.centerIn: parent
              text: String(iconWrap.modelData.badge || "").slice(0, 3)
              textFormat: Text.PlainText
              color: keybindBadge.hot ? root.ink : root.surface
              font.family: Style.font.menuFamily
              font.pixelSize: Math.max(12, Math.round(root.iconSlot * 0.42))
              font.bold: true

              Behavior on color { ColorAnimation { duration: 120 } }
            }
          }

          Rectangle {
            id: iconRoundMask
            width: iconClip.width
            height: iconClip.height
            visible: false
            color: "#ffffff"
            radius: Math.max(4, Math.round(Math.min(width, height) * 0.22))
            layer.enabled: true
            layer.smooth: true
          }

          Canvas {
            id: cornerProbe
            width: 12
            height: 12
            visible: false
            property bool sharp: false

            function looksRaster() {
              var s = String(iconImage.source || "").toLowerCase()
              if (!s.length) return false
              if (s.indexOf("symbolic") >= 0 || s.indexOf(".svg") >= 0)
                return false
              return true
            }

            function scan() {
              if (iconImage.status !== Image.Ready) {
                sharp = false
                return
              }
              var url = String(iconImage.source || "")
              if (!url.length) {
                sharp = looksRaster()
                return
              }
              if (isImageLoaded(url))
                requestPaint()
              else
                loadImage(url)
            }

            onImageLoaded: requestPaint()
            onPaint: {
              var url = String(iconImage.source || "")
              if (!url.length || !isImageLoaded(url)) {
                sharp = looksRaster()
                return
              }
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              try {
                ctx.drawImage(url, 0, 0, width, height)
              } catch (e) {
                sharp = looksRaster()
                return
              }
              var pts = [
                [0, 0], [width - 1, 0], [0, height - 1], [width - 1, height - 1],
                [1, 1], [width - 2, 1], [1, height - 2], [width - 2, height - 2]
              ]
              var opaque = 0
              for (var i = 0; i < pts.length; i++) {
                var d = ctx.getImageData(pts[i][0], pts[i][1], 1, 1)
                if (d && d.data && d.data[3] > 200)
                  opaque += 1
              }
              sharp = opaque >= 6
            }
          }

          // Running / focused underline. Reads liveClientGen so a closed
          // keybind window drops the mark on the same event.
          Rectangle {
            id: runDot
            readonly property bool running: root.itemIsRunning(iconWrap.modelData, sectionRoot.hostScreen, root.liveClientGen)
            readonly property bool focused: root.itemIsFocused(iconWrap.modelData, sectionRoot.hostScreen, root.liveClientGen)
            visible: running
            z: 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: focused ? Math.max(8, root.iconSlot * 0.55) : Math.max(6, root.iconSlot * 0.34)
            height: Math.max(3, Math.round(root.iconSlot * 0.12))
            radius: height / 2
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "#33ccff" }
              GradientStop { position: 1.0; color: "#00ff99" }
            }
            opacity: root.runMarkPulse
          }

          // Tip is rendered in TipPanel (above the dock layer) so it is not clipped.

          MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            preventStealing: true

            property real pressX: 0
            property real pressY: 0
            property bool dragArmed: false
            property real hoverX: width / 2
            property real hoverY: height / 2

            onEntered: {
              hoverX = width / 2
              hoverY = height / 2
              var g = iconWrap.mapToGlobal(hoverX, 0)
              root.showIconTip(sectionRoot.hostScreen, g.x, g.y, DockModel.itemLabel(iconWrap.modelData))
            }
            onExited: {
              if (root.tipText === DockModel.itemLabel(iconWrap.modelData))
                root.hideIconTip()
            }
            onPositionChanged: function(mouse) {
              hoverX = mouse.x
              hoverY = mouse.y
              var g = iconWrap.mapToGlobal(mouse.x, 0)
              if (iconMouse.containsMouse && !root.dragging && !root.menuOpen) {
                root.refreshIconTipPosition(sectionRoot.hostScreen, g.x, g.y)
                if (!root.tipVisible && !tipDelay.running)
                  root.showIconTip(sectionRoot.hostScreen, g.x, g.y, DockModel.itemLabel(iconWrap.modelData))
              }
              if (!(mouse.buttons & Qt.LeftButton)) return
              if (!dragArmed) {
                if (Math.abs(mouse.x - pressX) < 8 && Math.abs(mouse.y - pressY) < 8)
                  return
                dragArmed = true
                root.hideIconTip()
                root.startIconDrag(iconWrap.modelData, sectionRoot.hostScreen)
              }
              if (!root.dragging || !sectionRoot.chromeItem || !sectionRoot.trackDrag)
                return
              var p = mapToItem(sectionRoot.chromeItem, mouse.x, mouse.y)
              sectionRoot.trackDrag(p.x, p.y)
            }
            onPressed: function(mouse) {
              if (mouse.button !== Qt.LeftButton) return
              pressX = mouse.x
              pressY = mouse.y
              dragArmed = false
            }
            onReleased: function(mouse) {
              if (mouse.button === Qt.RightButton) {
                if (root.dragging) root.cancelIconDrag()
                root.hideIconTip()
                var g = iconWrap.mapToGlobal(mouse.x, mouse.y)
                root.openItemMenu(sectionRoot.hostScreen, iconWrap.modelData, g.x, g.y)
                return
              }
              if (root.dragging && dragArmed) {
                if (sectionRoot.chromeItem && sectionRoot.trackDrag) {
                  var p = mapToItem(sectionRoot.chromeItem, mouse.x, mouse.y)
                  sectionRoot.trackDrag(p.x, p.y)
                }
                root.commitIconDrag()
                return
              }
              if (mouse.button === Qt.LeftButton)
                root.activateOrLaunch(iconWrap.modelData)
            }
            onCanceled: {
              if (root.dragging) root.cancelIconDrag()
              root.hideIconTip()
            }
            onWheel: function(wheel) { root.handleDockWheel(wheel) }
          }
        }
      }
    }
  }

  component TipPanel: PanelWindow {
    id: tipWindow
    readonly property bool forScreen: root.tipScreen === tipWindow.screen
    visible: root.tipVisible && forScreen && root.tipText.length > 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-tip"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { left: true; right: true; top: true; bottom: true }

    // Click-through: empty mask so the tip never steals input from the dock.
    mask: Region {}

    Rectangle {
      id: tipCard
      readonly property int tipPadX: Style.space(16)
      readonly property int tipPadY: Style.space(12)
      width: tipLabel.implicitWidth + tipPadX
      height: Math.max(Style.space(28), tipLabel.implicitHeight + tipPadY)
      radius: Style.cornerRadius
      color: Color.tooltip.background
      border.color: Color.tooltip.border
      border.width: Math.max(1, Style.normalBorderWidth)
      x: {
        if (root.barEdgeDragging)
          return Math.min(Math.max(Style.space(4), root.tipX), parent.width - width - Style.space(4))
        if (root.barEdge === "left")
          return root.dockHeight + Style.space(10)
        if (root.barEdge === "right")
          return Math.max(Style.space(4), parent.width - root.dockHeight - width - Style.space(10))
        return Math.min(Math.max(Style.space(4), root.tipX), parent.width - width - Style.space(4))
      }
      y: {
        if (root.barEdgeDragging)
          return Math.min(Math.max(Style.space(4), root.tipY - height - Style.space(8)), parent.height - height - Style.space(4))
        if (root.barEdge === "bottom")
          return parent.height - root.dockHeight - height - Style.space(10)
        return Math.min(Math.max(Style.space(4), root.tipY - height / 2), parent.height - height - Style.space(4))
      }

      Text {
        id: tipLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.tipText
        color: Color.tooltip.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  component CircleGlyphButton: Rectangle {
    id: glyphButton
    signal activated()
    property string glyph: ""
    property bool italicGlyph: false
    width: Style.space(26)
    height: width
    radius: width / 2
    color: glyphMouse.containsMouse ? root.menuFillHover : "transparent"
    border.width: 1.5
    border.color: glyphMouse.containsMouse ? root.menuStrokeHover : root.menuStroke

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: glyphButton.glyph
      color: root.menuForeground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.title
      font.bold: true
      font.italic: glyphButton.italicGlyph
    }

    MouseArea {
      id: glyphMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: glyphButton.activated()
    }
  }

  component MenuPanel: PanelWindow {
    id: menuWindow
    readonly property bool forScreen: root.menuScreen === menuWindow.screen
    readonly property bool itemMenuActive: visible && !!root.menuItem
    readonly property bool titleEditActive: itemMenuActive && root.labelEdit
    visible: root.menuOpen && forScreen
    focusable: titleEditActive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: titleEditActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { left: true; right: true; top: true; bottom: true }
    // Leave the dock strip uncovered so icon size, transparency, and
    // background picks stay visible while this menu is open.
    margins.left: root.barEdge === "left" ? root.dockHeight : 0
    margins.right: root.barEdge === "right" ? root.dockHeight : 0
    margins.bottom: root.barEdge === "bottom" ? root.dockHeight : 0

    HyprlandFocusGrab {
      active: menuWindow.titleEditActive
      windows: [menuWindow]
    }

    Rectangle {
      anchors.fill: parent
      color: root.menuScrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeMenus()
    }

    BorderSurface {
      id: menuCard
      width: root.menuItem ? Style.space(260) : Math.min(Style.space(380), parent.width - Style.space(24))
      height: menuColumn.implicitHeight + contentTopInset + contentBottomInset
      radius: Style.cornerRadius
      color: root.menuBackground
      borderSpec: root.menuBorderSpec
      padding: Style.space(6)
      x: {
        var origin = root.barEdge === "left" ? root.dockHeight : 0
        var local = root.menuX - origin
        return Math.min(Math.max(Style.space(8), local - width / 2), parent.width - width - Style.space(8))
      }
      y: Math.max(Style.space(8), parent.height - height - Style.space(12))

      Column {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: menuCard.contentLeftInset
        anchors.rightMargin: menuCard.contentRightInset
        anchors.topMargin: menuCard.contentTopInset
        spacing: 2

        // Selected icon identity: same glyph and label as the dock tooltip.
        Item {
          id: itemMenuHeader
          visible: !!root.menuItem
          width: parent.width
          height: visible ? Style.space(44) : 0

          Image {
            id: itemMenuHeaderIcon
            visible: !root.menuItem || root.menuItem.kind !== "keybind"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            width: Math.max(Style.space(24), root.iconSlot)
            height: width
            source: root.menuItem && visible ? root.iconSource(root.menuItem.icon) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
          }

          CircleGlyphButton {
            id: itemMenuClose
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            glyph: "X"
            onActivated: root.closeMenus()
          }

          CircleGlyphButton {
            id: itemMenuInfo
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: itemMenuClose.visible ? itemMenuClose.left : parent.right
            anchors.rightMargin: Style.space(4)
            glyph: "i"
            italicGlyph: true
            onActivated: root.helpOpen = true
          }

          Text {
            id: itemMenuHeaderLabel
            visible: !(root.labelEdit && root.labelEditTarget === "label")
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: root.menuItem && root.menuItem.kind === "keybind" ? parent.left : itemMenuHeaderIcon.right
            anchors.leftMargin: Style.space(8)
            anchors.right: itemMenuInfo.left
            anchors.rightMargin: Style.space(8)
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: root.menuItem && root.menuItem.kind === "keybind"
              ? "KEYBIND"
              : (root.menuItem ? DockModel.itemLabel(root.menuItem) : "")
            color: root.menuForeground
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          TextInput {
            id: popupTextInput
            visible: root.labelEdit && root.labelEditTarget === "label"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: itemMenuHeaderIcon.right
            anchors.leftMargin: Style.space(10)
            anchors.right: itemMenuInfo.left
            anchors.rightMargin: Style.space(8)
            clip: true
            color: root.menuForeground
            selectedTextColor: root.menuBackground
            selectionColor: root.menuSelectedText
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            font.bold: true
            selectByMouse: true
            text: root.labelDraft
            onTextChanged: {
              if (text !== root.labelDraft)
                root.labelDraft = text
            }
            Keys.onReturnPressed: root.commitLabelEdit()
            Keys.onEnterPressed: root.commitLabelEdit()
            Keys.onTabPressed: root.commitLabelEdit()
            Keys.onBacktabPressed: root.commitLabelEdit()
            Keys.onEscapePressed: root.cancelLabelEdit()
            onEditingFinished: {
              if (root.labelEdit)
                root.commitLabelEdit()
            }
          }

          MouseArea {
            anchors.left: itemMenuHeaderIcon.right
            anchors.right: itemMenuInfo.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: !root.labelEdit && !(root.menuItem && root.menuItem.kind === "keybind")
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            onDoubleClicked: root.beginLabelEdit()
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.menuLine
          }
        }

        Column {
          visible: !root.menuItem
          width: parent.width
          spacing: Style.spacing.md

          Item {
            width: parent.width
            height: Style.space(44)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.right: barMenuInfo.left
              anchors.rightMargin: Style.space(8)
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: "TASK BAR CUSTOMIZATION"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            CircleGlyphButton {
              id: barMenuClose
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              glyph: "X"
              onActivated: root.closeMenus()
            }

            CircleGlyphButton {
              id: barMenuInfo
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: barMenuClose.left
              anchors.rightMargin: Style.space(4)
              glyph: "i"
              italicGlyph: true
              onActivated: root.helpOpen = true
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 1
              color: root.menuLine
            }
          }

          PanelSectionHeader {
            text: "ADD"
            foreground: root.menuForeground
            fontFamily: Style.font.menuFamily
          }

          RowLayout {
            width: parent.width
            spacing: Style.spacing.sm

            Button {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              text: "App"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              fontSize: Style.font.bodySmall
              onClicked: root.beginAdd(root.pendingSection)
            }
            Button {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              text: "Plugin"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              fontSize: Style.font.bodySmall
              onClicked: root.beginAddPlugin(root.pendingSection)
            }
            Button {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              text: "Web"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              fontSize: Style.font.bodySmall
              onClicked: root.beginWebAdd(root.pendingSection)
            }
            Button {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              text: "KeyBind"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              fontSize: Style.font.bodySmall
              onClicked: root.beginKeybindAdd(root.pendingSection)
            }
          }

          Item {
            width: parent.width
            height: Style.space(24)

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(16)

              Repeater {
                model: [
                  { label: "Left", value: "left" },
                  { label: "Center", value: "center" },
                  { label: "Right", value: "right" }
                ]
                delegate: Item {
                  required property var modelData
                  readonly property bool selected: root.pendingSection === modelData.value
                  width: addRadioRow.implicitWidth
                  height: Style.space(24)

                  Row {
                    id: addRadioRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(14)
                      height: Style.space(14)
                      radius: width / 2
                      color: "transparent"
                      border.width: 1.5
                      border.color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, selected ? 0.75 : 0.40)

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(7)
                        height: Style.space(7)
                        radius: width / 2
                        visible: selected
                        color: root.menuForeground
                      }
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: root.menuForeground
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: selected
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pendingSection = modelData.value
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.menuForeground }

          PanelSectionHeader {
            text: "SETTINGS"
            foreground: root.menuForeground
            fontFamily: Style.font.menuFamily
          }

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              width: Style.space(92)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Icon Size"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Button {
              text: "+"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              onClicked: root.bumpIconSize(4)
            }
            Button {
              text: "-"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              onClicked: root.bumpIconSize(-4)
            }
          }

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              width: Style.space(92)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Transparency"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Button {
              text: "+"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              onClicked: root.bumpBgOpacity(-10)
            }
            Button {
              text: "-"
              bordered: true
              foreground: root.menuForeground
              accent: Color.accent
              fontFamily: Style.font.menuFamily
              onClicked: root.bumpBgOpacity(10)
            }
          }

          PanelSectionHeader {
            text: "Background"
            foreground: root.menuForeground
            fontFamily: Style.font.menuFamily
          }

          Flow {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: root.themeSwatches
              delegate: Rectangle {
                required property var modelData
                readonly property bool selected: String(root.bgColorKey || "") === String(modelData.key || "")
                width: Style.space(20)
                height: Style.space(20)
                radius: Style.space(4)
                color: modelData.hex ? modelData.hex : root.menuBackground
                border.width: selected ? 2 : 1
                border.color: selected ? Color.accent : root.menuStroke

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setBarBackground(modelData.key, modelData.hex)
                  onEntered: {
                    var g = mapToItem(null, width / 2, 0)
                    root.showIconTip(menuWindow.screen, g.x, g.y, modelData.key ? String(modelData.key).replace(/_/g, " ") : "Theme")
                  }
                  onExited: root.hideIconTip()
                }
              }
            }
          }

          Toggle {
            width: parent.width
            label: "Icon popups"
            checked: root.showTips
            foreground: root.menuForeground
            accent: Color.accent
            fontFamily: Style.font.menuFamily
            onClicked: root.toggleShowTips()
          }
        }

        // Per-icon: placement + copy to other workspaces
        Column {
          visible: !!root.menuItem && root.menuItem.kind === "keybind"
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            height: Math.max(menuBadge.height, descText.implicitHeight, descTextInput.implicitHeight) + Style.space(8)

            Rectangle {
              id: menuBadge
              readonly property bool editing: root.labelEdit && root.labelEditTarget === "badge"
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(36)
              height: Style.space(28)
              radius: Style.space(6)
              color: root.ink
              border.width: 1
              border.color: root.ink

              Text {
                visible: !menuBadge.editing
                anchors.centerIn: parent
                text: root.menuItem ? String(root.menuItem.badge || "").slice(0, 3) : ""
                textFormat: Text.PlainText
                color: root.surface
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              TextInput {
                id: badgeTextInput
                visible: menuBadge.editing
                anchors.fill: parent
                anchors.margins: Style.space(2)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                clip: true
                maximumLength: 3
                color: root.surface
                selectedTextColor: root.ink
                selectionColor: root.menuSelectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                selectByMouse: true
                text: root.labelEditTarget === "badge" ? root.labelDraft : ""
                onTextChanged: {
                  if (root.labelEditTarget !== "badge") return
                  var next = text.replace(/[^A-Za-z0-9]/g, "").toUpperCase().slice(0, 3)
                  if (next !== text)
                    text = next
                  if (text !== root.labelDraft)
                    root.labelDraft = text
                }
                Keys.onReturnPressed: root.commitLabelEdit()
                Keys.onEnterPressed: root.commitLabelEdit()
                Keys.onEscapePressed: root.cancelLabelEdit()
                onEditingFinished: {
                  if (root.labelEdit && root.labelEditTarget === "badge")
                    root.commitLabelEdit()
                }
              }

              MouseArea {
                anchors.fill: parent
                visible: !menuBadge.editing
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onDoubleClicked: root.beginKeybindBadgeEdit()
              }
            }

            Text {
              id: descText
              visible: !(root.labelEdit && root.labelEditTarget === "desc")
              anchors.left: menuBadge.right
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.menuItem ? DockModel.itemLabel(root.menuItem) : ""
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }

            TextInput {
              id: descTextInput
              readonly property int descSlots: 20
              visible: root.labelEdit && root.labelEditTarget === "desc"
              anchors.left: menuBadge.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(8)
              width: Math.min(parent.width - menuBadge.width - Style.space(24), descMetrics.averageCharacterWidth * descSlots)
              clip: true
              maximumLength: descSlots
              color: root.menuForeground
              selectedTextColor: root.menuBackground
              selectionColor: root.menuSelectedText
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              selectByMouse: true
              text: root.labelEditTarget === "desc" ? root.labelDraft : ""
              FontMetrics {
                id: descMetrics
                font: descTextInput.font
              }
              onTextChanged: {
                if (root.labelEditTarget !== "desc") return
                var next = text.slice(0, descSlots)
                if (next !== text)
                  text = next
                if (text !== root.labelDraft)
                  root.labelDraft = text
              }
              Keys.onReturnPressed: root.commitLabelEdit()
              Keys.onEnterPressed: root.commitLabelEdit()
              Keys.onEscapePressed: root.cancelLabelEdit()
              onEditingFinished: {
                if (root.labelEdit && root.labelEditTarget === "desc")
                  root.commitLabelEdit()
              }
            }

            MouseArea {
              anchors.left: menuBadge.right
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              visible: descText.visible
              hoverEnabled: true
              cursorShape: Qt.IBeamCursor
              onDoubleClicked: root.beginKeybindDescEdit()
            }
          }

          Text {
            width: parent.width
            leftPadding: Style.space(8)
            rightPadding: Style.space(8)
            bottomPadding: Style.space(6)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: root.menuItem ? String(root.menuItem.bindCombo || "") : ""
            color: root.menuMuted
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
          }
        }

        Rectangle {
          visible: !!root.menuItem
          width: parent.width
          height: visible ? itemPlaceColumn.implicitHeight + Style.space(16) : 0
          radius: Style.space(8)
          color: "transparent"
          border.width: 1
          border.color: root.menuLine

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.top
            textFormat: Text.PlainText
            text: " PLACE "
            color: root.menuMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            Rectangle {
              z: -1
              anchors.fill: parent
              anchors.margins: -1
              color: root.menuBackground
            }
          }

          Column {
            id: itemPlaceColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Style.space(12)
            anchors.margins: Style.space(6)
            spacing: Style.space(4)

            Item {
              width: parent.width
              height: Style.space(28)

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(16)

                Repeater {
                  model: [
                    { label: "Left", value: "left" },
                    { label: "Center", value: "center" },
                    { label: "Right", value: "right" }
                  ]
                  delegate: Item {
                    required property var modelData
                    readonly property bool selected: root.itemPlaceSection === modelData.value
                    width: itemRadioRow.implicitWidth
                    height: Style.space(24)

                    Row {
                      id: itemRadioRow
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(14)
                        height: Style.space(14)
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, selected ? 0.75 : 0.40)

                        Rectangle {
                          anchors.centerIn: parent
                          width: Style.space(7)
                          height: Style.space(7)
                          radius: width / 2
                          visible: selected
                          color: root.menuForeground
                        }
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: modelData.label
                        color: root.menuForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: selected
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setItemPlaceSection(modelData.value)
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          visible: !!root.menuItem
          width: parent.width
          height: visible ? itemWsColumn.implicitHeight + Style.space(16) : 0
          radius: Style.space(8)
          color: "transparent"
          border.width: 1
          border.color: root.menuLine

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.top
            textFormat: Text.PlainText
            text: " WORKSPACES "
            color: root.menuMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            Rectangle {
              z: -1
              anchors.fill: parent
              anchors.margins: -1
              color: root.menuBackground
            }
          }

          Column {
            id: itemWsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Style.space(12)
            anchors.margins: Style.space(6)
            spacing: 2

            Repeater {
              model: root.menuItem ? root.otherWorkspaceIds : []
              delegate: MenuRow {
                required property var modelData
                readonly property int wsId: Number(modelData)
                readonly property bool present: {
                  var _a = root.layout
                  var _b = root.workspaceLayouts
                  var _c = root.defaultLayout
                  return !!(root.menuItem && root.itemPresentOnWorkspace(root.menuItem.id, wsId))
                }
                text: "Workspace " + wsId
                checkable: true
                checked: present
                onActivated: {
                  if (!root.menuItem) return
                  root.setItemOnWorkspace(root.menuItem, wsId, !present)
                }
              }
            }
          }
        }

        MenuRow {
          visible: !!root.menuItem
          text: "Remove"
          onActivated: {
            var id = root.menuItem ? root.menuItem.id : ""
            root.menuItem = null
            root.labelDraft = ""
            root.labelEdit = false
            root.persistLayout(DockModel.removeItem(root.layout, id))
            root.closeMenus()
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: root.labelEdit
        propagateComposedEvents: true
        onPressed: function(mouse) {
          var field = root.labelEditTarget === "badge" ? badgeTextInput
            : root.labelEditTarget === "desc" ? descTextInput
            : popupTextInput
          var p = mapToItem(field, mouse.x, mouse.y)
          var inside = field.visible
            && p.x >= 0 && p.y >= 0
            && p.x <= field.width && p.y <= field.height
          if (!inside)
            root.commitLabelEdit()
          mouse.accepted = false
        }
      }
    }

    // Help sits above the icon menu. Colors are the live menu tokens, so the
    // card follows the current Omarchy theme. Clicks outside the card dismiss it.
    Item {
      id: helpLayer
      anchors.fill: parent
      visible: root.helpOpen && menuWindow.visible
      z: 20

      MouseArea {
        anchors.fill: parent
        onClicked: root.helpOpen = false
      }

      BorderSurface {
        id: helpCard
        readonly property int cardWidth: Math.min(Style.space(440), parent.width - Style.space(32))
        readonly property int sectionGap: Style.space(8)
        readonly property int maxBody: Math.max(Style.space(140), menuCard.y - Style.space(96))
        readonly property bool barHelp: !root.menuItem
        readonly property bool keybindHelp: !!root.menuItem && root.menuItem.kind === "keybind"
        width: cardWidth
        height: contentTopInset + helpTitleRow.height + sectionGap + helpFlick.height + contentBottomInset
        radius: Style.cornerRadius
        color: root.menuBackground
        borderSpec: root.menuBorderSpec
        padding: Style.space(12)
        x: {
          var margin = Style.space(8)
          var fallback = Math.max(margin, Math.round((parent.width - width) / 2))
          if (!root.helpPosSet) return fallback
          var maxX = Math.max(margin, parent.width - width - margin)
          return Math.min(Math.max(margin, root.helpPosX), maxX)
        }
        y: {
          var margin = Style.space(12)
          var aboveMenu = menuCard.y - height - margin
          var fallback = Math.max(margin, Math.min(Math.round((menuCard.y - height) / 2), aboveMenu))
          if (!root.helpPosSet) return fallback
          var maxY = Math.max(margin, parent.height - height - margin)
          return Math.min(Math.max(margin, root.helpPosY), maxY)
        }

        // Holds clicks on the card so they do not fall through to the dismiss layer.
        MouseArea {
          anchors.fill: parent
          z: 0
        }

        Item {
          id: helpTitleRow
          z: 1
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.leftMargin: helpCard.contentLeftInset
          anchors.rightMargin: helpCard.contentRightInset
          anchors.topMargin: helpCard.contentTopInset
          height: Math.max(Style.space(28), helpClose.height)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: helpClose.left
            anchors.rightMargin: Style.space(8)
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: helpCard.keybindHelp ? "KEYBIND" : (helpCard.barHelp ? "Task Bar Customization" : "Icon Placement")
            color: root.menuForeground
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          CircleGlyphButton {
            id: helpClose
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            glyph: "X"
            onActivated: root.helpOpen = false
          }
        }

        Flickable {
          id: helpFlick
          z: 1
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: helpTitleRow.bottom
          anchors.leftMargin: helpCard.contentLeftInset
          anchors.rightMargin: helpCard.contentRightInset
          anchors.topMargin: helpCard.sectionGap
          height: helpCard.barHelp
            ? helpColumn.implicitHeight
            : Math.min(helpColumn.implicitHeight, helpCard.maxBody)
          contentWidth: width
          contentHeight: helpColumn.implicitHeight
          clip: !helpCard.barHelp
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: !helpCard.barHelp && contentHeight > height + 1

          Column {
            id: helpColumn
            width: helpFlick.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "PURPOSE"
              foreground: root.menuForeground
              fontFamily: Style.font.menuFamily
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: helpCard.keybindHelp
                ? "This icon runs one shortcut from the Super+K list. KEYBIND is the title of this menu. The mark and description under it name the shortcut, and the line under those is the keystroke."
                : helpCard.barHelp
                  ? "Right-click a blank part of the task bar to open task bar customization. Use it to add icons, including a keybind, and to change how the task bar looks. Each workspace keeps its own icons."
                  : "Keeps the apps, plugins, and web links you use on a bar along one edge of the screen. Each workspace keeps its own icons, and each monitor shows the workspace on that screen."
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }

            PanelSectionHeader {
              text: "FEATURES"
              foreground: root.menuForeground
              fontFamily: Style.font.menuFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: helpCard.keybindHelp ? [
                  "Left-click the icon to run the shortcut, the same action as choosing it in the Super+K list.",
                  "Hover the icon to see the description. The popup shows that name, not the keystroke.",
                  "The letters to the left of the description are the mark on the bar icon. Double-click those letters to change them. Up to three characters.",
                  "Double-click the description to rename it. That name is what you see when you hover the icon.",
                  "The line under the description is the keystroke combination.",
                  "Place chooses Left, Center, or Right for this icon.",
                  "Check a workspace to show this icon there. Uncheck to remove that copy.",
                  "Drag the icon and drop it to move it along the bar.",
                  "Remove takes this icon off the current workspace.",
                  "The circled i opens this help. The circled X closes the menu."
                ] : helpCard.barHelp ? [
                  "App adds a program. Plugin adds a shell plugin. Web adds a link.",
                  "KeyBind adds a shortcut from the Super+K list. The task bar icon shows up to three letters from that shortcut name. Hover shows the name. Left-click runs the shortcut.",
                  "Left, Center, or Right chooses which group the new item joins.",
                  "Icon Size + makes icons larger. Icon Size - makes them smaller. Scroll on the task bar does the same.",
                  "Transparency + makes the task bar more see-through. Transparency - makes it more solid. Hold Alt and scroll to do the same.",
                  "A background swatch sets the task bar color. Theme follows the current Omarchy theme.",
                  "Icon popups shows a name when you hover an icon, and RClick customize on a blank part of the task bar.",
                  "Left-click an icon to open it on this workspace. A plugin toggles. A web link opens. A keybind runs its shortcut.",
                  "Click an icon, then drag and drop it to reposition it along the task bar, including into Left, Center, or Right.",
                  "Hold Super and drag a blank part of the task bar to the left, the right, or the bottom to move the task bar there.",
                  "The task bar hides until the pointer reaches its edge. It stays open while the pointer is off the outer side of the screen.",
                  "A mark under an app means it is open. A wider mark means that window is focused."
                ] : [
                  "Left-click an icon to open another window on this workspace.",
                  "Left-click a plugin to toggle it. Left-click a web link to open it.",
                  "Hover an icon to see its name. Hover a blank part of the bar to see how to customize. Turn those popups off from the bar menu.",
                  "Double-click the name at the top of this menu to rename the icon.",
                  "Click an icon, then drag and drop it to reposition it along the bar, including into Left, Center, or Right.",
                  "Place sets Left, Center, or Right for this icon.",
                  "Check a workspace to copy this icon there. Uncheck to remove that copy.",
                  "Remove takes this icon off the current workspace only.",
                  "Right-click the empty bar to add an app, plugin, or web link.",
                  "From the empty bar, change icon size, transparency, and the bar color.",
                  "Scroll on the bar to resize icons. Hold Alt and scroll to change transparency.",
                  "A mark under an app means it is open. A wider mark means that window is focused.",
                  "The bar slides away until the pointer reaches the bottom edge.",
                  "Hold Super and drag this card to move it. It stays where you drop it until you log out.",
                  "Hold Super and drag a blank part of the bar left or right to move it to that side. Drag it inward or down to put it back on the bottom."
                ]
                delegate: Item {
                  required property var modelData
                  width: parent.width
                  height: featureText.implicitHeight

                  Rectangle {
                    id: featureDot
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: Math.max(0, Math.round((Style.font.body - height) / 2))
                    width: Style.space(5)
                    height: width
                    radius: width / 2
                    color: root.menuForeground
                  }

                  Text {
                    id: featureText
                    anchors.left: featureDot.right
                    anchors.leftMargin: Style.space(8)
                    anchors.right: parent.right
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    text: modelData
                    color: root.menuForeground
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                  }
                }
              }
            }
          }
        }

        // Super+left-drag moves the card. Other presses stay with the close
        // button, the text, and the flickable, so the wheel still scrolls.
        DragHandler {
          id: helpDrag
          acceptedButtons: Qt.LeftButton
          acceptedModifiers: Qt.MetaModifier
          grabPermissions: PointerHandler.CanTakeOverFromAnything
          target: null
          property real originX: 0
          property real originY: 0
          property real startSceneX: 0
          property real startSceneY: 0

          onActiveChanged: {
            if (active) {
              originX = helpCard.x
              originY = helpCard.y
              startSceneX = centroid.scenePosition.x
              startSceneY = centroid.scenePosition.y
              root.helpPosX = helpCard.x
              root.helpPosY = helpCard.y
              root.helpPosSet = true
              root.helpDragging = true
            } else if (root.helpDragging) {
              root.helpDragging = false
              root.helpPosX = helpCard.x
              root.helpPosY = helpCard.y
              root.saveHelpPos(menuWindow.screen ? String(menuWindow.screen.name || "") : "")
            }
          }
          onTranslationChanged: {
            if (!root.helpDragging) return
            root.helpPosX = originX + (centroid.scenePosition.x - startSceneX)
            root.helpPosY = originY + (centroid.scenePosition.y - startSceneY)
          }
        }
      }
    }

    Timer {
      interval: 50
      repeat: true
      triggeredOnStart: true
      running: menuWindow.titleEditActive
      property int tries: 0
      onRunningChanged: if (running) tries = 0
      onTriggered: {
        if (menuWindow.WlrLayershell)
          menuWindow.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
        var field = root.labelEditTarget === "badge" ? badgeTextInput
          : root.labelEditTarget === "desc" ? descTextInput
          : popupTextInput
        field.forceActiveFocus()
        field.selectAll()
        tries += 1
        if (tries >= 8 || field.activeFocus)
          stop()
      }
    }
  }

  component MenuRow: Rectangle {
    id: row
    signal activated()
    property string text: ""
    property bool checkable: false
    property bool checked: false
    width: parent ? parent.width : Style.space(200)
    height: visible ? Style.space(32) : 0
    radius: Style.space(6)
    color: rowMouse.containsMouse ? root.menuSelectedBackground : "transparent"

    Rectangle {
      id: checkBox
      visible: row.checkable
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      width: Style.space(16)
      height: Style.space(16)
      radius: Style.space(3)
      color: row.checked ? root.menuSelectedBackground : "transparent"
      border.width: 1
      border.color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, row.checked ? 0.55 : 0.35)

      Text {
        anchors.centerIn: parent
        visible: row.checked
        textFormat: Text.PlainText
        text: "✓"
        color: root.menuSelectedText
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: row.checkable ? Style.space(34) : Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      textFormat: Text.PlainText
      text: row.text
      color: rowMouse.containsMouse ? root.menuSelectedText : root.menuForeground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.activated()
    }
  }

  component DockSelectRow: BorderSurface {
    id: selectRow
    property bool hasCursor: false
    property bool menuLine: false
    property string label: ""
    property string detail: ""
    property string iconName: ""
    signal activated()
    signal hovered()

    width: parent ? parent.width : Style.space(300)
    height: menuLine
      ? Style.space(28)
      : detail.length
        ? Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
        : root.menuRowHeight
    radius: Style.cornerRadius
    color: hasCursor ? root.menuSelectedBackground : "transparent"
    borderSpec: hasCursor ? root.menuSelectedBorderSpec : Border.none()

    Image {
      id: selectIcon
      visible: selectRow.iconName.length > 0
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: root.menuRowPadLeft
      width: Style.font.iconLarge
      height: width
      source: visible ? root.iconSource(selectRow.iconName) : ""
      fillMode: Image.PreserveAspectFit
      asynchronous: true
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: selectIcon.visible ? selectIcon.right : parent.left
      anchors.leftMargin: selectIcon.visible ? Style.space(10) : root.menuRowPadLeft + Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: root.menuRowPadRight
      spacing: Style.space(3)

      Text {
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: selectRow.label
        color: selectRow.hasCursor ? root.menuSelectedText : root.menuForeground
        font.family: Style.font.menuFamily
        font.pixelSize: selectRow.menuLine ? Style.font.body : Style.font.heading
        font.weight: selectRow.menuLine ? Font.Normal : Font.Medium
      }

      Text {
        visible: selectRow.detail.length > 0
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: selectRow.detail
        color: root.menuForeground
        opacity: 0.52
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: selectRow.hovered()
      onClicked: selectRow.activated()
    }
  }

  component PickerPanel: PanelWindow {
    id: pickerPanel
    readonly property bool pickerActive: root.pickerOpen
    readonly property bool keyHasFocus: keyCatcher.activeFocus
    visible: pickerActive
    // PanelWindow.focusable is the property that actually enables keyboard
    // input on Hyprland; WlrLayershell.keyboardFocus Exclusive then grabs the seat.
    focusable: pickerActive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pickerActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { left: true; right: true; top: true; bottom: true }

    function grabKeys() {
      if (pickerActive && pickerPanel.WlrLayershell)
        pickerPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
      keyCatcher.forceActiveFocus()
    }

    HyprlandFocusGrab {
      active: pickerPanel.pickerActive
      windows: [pickerPanel]
    }

    readonly property bool keybindList: root.pickerKind === "keybind"
    readonly property int rowStride: keybindList
      ? Style.space(28) + Style.spacing.xs
      : root.menuRowHeight + Style.spacing.xs
    readonly property int visibleRowCount: Math.min(
      root.pickerModel ? root.pickerModel.length : 0,
      keybindList ? 16 : 8
    )
    readonly property int listHeight: Math.max(
      keybindList ? Style.space(28) : root.menuRowHeight,
      pickerPanel.visibleRowCount * pickerPanel.rowStride - Style.spacing.xs
    )

    Rectangle {
      anchors.fill: parent
      color: root.menuScrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeMenus()
    }

    BorderSurface {
      id: pickerCard
      width: root.pickerKind === "keybind"
        ? Math.min(Style.space(760), parent.width - Style.space(48))
        : Math.min(Style.space(300), parent.width - Style.gapsOut * 2)
      height: root.menuContentMargin * 2 + root.menuHeaderHeight + root.menuContentSpacing + pickerPanel.listHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      radius: Style.cornerRadius
      color: root.menuBackground
      borderSpec: root.menuBorderSpec
      padding: root.menuContentMargin

      MouseArea {
        anchors.fill: parent
        onClicked: pickerPanel.grabKeys()
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        anchors.topMargin: pickerCard.contentTopInset
        anchors.rightMargin: pickerCard.contentRightInset
        anchors.bottomMargin: pickerCard.contentBottomInset
        anchors.leftMargin: pickerCard.contentLeftInset
        focus: pickerPanel.pickerActive
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.handlePickerKey(event) }

        Column {
          anchors.fill: parent
          spacing: root.menuContentSpacing

          Rectangle {
            width: parent.width
            height: root.menuHeaderHeight
            radius: Style.cornerRadius
            color: "transparent"

            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.pickerQuery.length
                ? root.pickerQuery
                : (root.pickerKind === "keybind" ? "Search keybindings…" : "Go…")
              color: root.menuForeground
              opacity: root.pickerQuery.length ? 1 : 0.58
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
            }
          }

          ListView {
            id: pickerList
            width: parent.width
            height: pickerPanel.listHeight
            clip: true
            model: root.pickerModel
            currentIndex: root.pickerSelectedIndex
            spacing: Style.spacing.xs
            boundsBehavior: Flickable.StopAtBounds
            Text {
              visible: pickerList.count === 0
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.pickerQuery.length
                ? ("No matches for “" + root.pickerQuery + "”")
                : "Nothing here yet"
              color: root.menuForeground
              opacity: 0.58
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
            }
            delegate: DockSelectRow {
              required property var modelData
              required property int index
              width: ListView.view.width
              hasCursor: index === root.pickerSelectedIndex
              menuLine: root.pickerKind === "keybind"
              label: root.pickerKind === "keybind"
                ? String(modelData.line || modelData.name || "")
                : root.pickerKind === "plugin"
                  ? String(modelData.name || modelData.id)
                  : DockModel.entryName(modelData)
              iconName: root.pickerKind === "keybind"
                ? ""
                : root.pickerKind === "plugin"
                  ? String(modelData.icon || DockModel.pluginIconFor(modelData.id))
                  : String(modelData.icon || modelData.id)
              onHovered: root.pickerSelectedIndex = index
              onActivated: root.acceptPickerRow(modelData)
            }
          }
        }
      }
    }

    Timer {
      id: pickerFocusRetry
      interval: 50
      repeat: true
      triggeredOnStart: true
      running: pickerPanel.pickerActive
      property int tries: 0
      onRunningChanged: if (running) tries = 0
      onTriggered: {
        pickerPanel.grabKeys()
        tries += 1
        if (tries >= 8 || keyCatcher.activeFocus)
          stop()
      }
    }

    onVisibleChanged: if (visible) pickerPanel.grabKeys()
    onPickerActiveChanged: if (pickerActive) pickerPanel.grabKeys()
  }

  component WebPanel: PanelWindow {
    id: webPanel
    readonly property bool webActive: root.webOpen
    readonly property string webHeader: {
      var cur = root.webFocus === "url" ? root.webUrl : root.webName
      return cur.length ? cur : "Go…"
    }
    visible: webActive
    focusable: webActive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-web"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: webActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { left: true; right: true; top: true; bottom: true }

    HyprlandFocusGrab {
      active: webPanel.webActive
      windows: [webPanel]
    }

    function grabKeys() {
      if (webActive && webPanel.WlrLayershell)
        webPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
      webKeyCatcher.forceActiveFocus()
    }

    Rectangle {
      anchors.fill: parent
      color: root.menuScrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeMenus()
    }

    BorderSurface {
      id: webCard
      width: Math.min(Style.space(300), parent.width - Style.gapsOut * 2)
      height: root.menuContentMargin * 2 + root.menuHeaderHeight + root.menuContentSpacing
        + webNameRow.height + Style.spacing.xs + webUrlRow.height
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      radius: Style.cornerRadius
      color: root.menuBackground
      borderSpec: root.menuBorderSpec
      padding: root.menuContentMargin

      MouseArea {
        anchors.fill: parent
        onClicked: webPanel.grabKeys()
      }

      Item {
        id: webKeyCatcher
        anchors.fill: parent
        anchors.topMargin: webCard.contentTopInset
        anchors.rightMargin: webCard.contentRightInset
        anchors.bottomMargin: webCard.contentBottomInset
        anchors.leftMargin: webCard.contentLeftInset
        focus: webPanel.webActive
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.handleWebKey(event) }

        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: root.menuContentSpacing

          Rectangle {
            width: parent.width
            height: root.menuHeaderHeight
            color: "transparent"

            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: webPanel.webHeader
              color: root.menuForeground
              opacity: webPanel.webHeader === "Go…" ? 0.58 : 1
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.xs

            DockSelectRow {
              id: webNameRow
              width: parent.width
              hasCursor: root.webFocus === "name"
              label: "Name"
              detail: root.webName
              onHovered: root.webFocus = "name"
              onActivated: root.webFocus = "name"
            }

            DockSelectRow {
              id: webUrlRow
              width: parent.width
              hasCursor: root.webFocus === "url"
              label: "URL"
              detail: root.webUrl
              onHovered: root.webFocus = "url"
              onActivated: root.webFocus = "url"
            }
          }
        }
      }
    }

    Timer {
      interval: 50
      repeat: true
      triggeredOnStart: true
      running: webPanel.webActive
      property int tries: 0
      onRunningChanged: if (running) tries = 0
      onTriggered: {
        webPanel.grabKeys()
        tries += 1
        if (tries >= 8 || webKeyCatcher.activeFocus)
          stop()
      }
    }

    onVisibleChanged: if (visible) webPanel.grabKeys()
    onWebActiveChanged: if (webActive) webPanel.grabKeys()
  }

  PickerPanel {
    id: pickerHost
    screen: root.menuScreen
  }

  WebPanel {
    screen: root.menuScreen
  }
}

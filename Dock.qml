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
// Empty layout shows "Right click to start customization".
// Right-click an icon, then the info button, for help on what the dock does.
// Icons, bar edge, size, color, popups, and auto-hide are stored per workspace.
// The globe at the end of the right section toggles Global Changes for every workspace.
// Each monitor's dock shows the workspace that monitor is displaying.
// Auto-hide reveals only the monitor under the pointer, so one workspace's
// edge hover does not slide the other workspaces' docks into view.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string home: Quickshell.env("HOME")
  property var shell: null
  property var manifest: null
  readonly property string pluginId: "drace3000.bottom-dock"

  property bool autoHide: true
  property bool revealHeld: false
  // Output name whose dock is allowed to slide in. Other monitors stay hidden.
  property string revealScreenName: ""
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
  property bool globalChanges: false
  property bool globalIcons: true
  property bool globalSections: true
  // Per-workspace bar edge, size, color, popups, and auto-hide.
  // Missing keys use defaultLook, which is what a new workspace inherits.
  property var workspaceLooks: ({})
  property var defaultLook: DockModel.defaultLook()
  property string workspaceId: "1"
  property var hoveredScreen: null
  property int iconSize: DockModel.defaultIconSize()
  property int bgOpacity: DockModel.defaultBgOpacity()
  property string bgColorKey: ""
  property string bgColorHex: ""
  property var themePalette: []
  property bool showTips: true
  property string barEdge: "bottom" // "bottom" | "left" | "right"
  property bool barEdgeDragging: false
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
  property int menuSectionIndex: -1
  property bool confirmRemoveOpen: false
  property int confirmSectionIndex: -1
  property int removeSectionPick: -1
  property int resizeBoundaryIndex: -1
  property bool resizeTail: false
  property bool superDown: false
  property int resizePreviewTick: 0
  property int resizeFrozenLead: -1
  property bool resizeButtonDown: false
  property real resizeOriginAlong: 0
  property var resizeBaseLayout: null
  property int dropIndex: 0
  property string dragGhostSource: ""
  property string dragGhostBadge: ""
  property real dragGhostX: 0
  property real dragGhostY: 0
  // The moving icon is only for the screen under the pointer. Other
  // workspaces stay still, including when Global Changes is on.
  property string dragScreenName: ""
  property int toplevelRevision: 0
  // Mapped Hyprland clients, refreshed on open/close/move. Keybind underlines
  // follow this list so they clear when the window is gone.
  property var liveClients: []
  property int liveClientGen: 0
  property var closedAddresses: ({})
  property bool clientSyncAgain: false

  property int pendingSection: 1
  property int itemPlaceSection: 1
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
  // Last place and size of the task bar customization window.
  property bool customMenuPlaced: false
  property real customMenuX: 0
  property real customMenuY: 0
  property bool customMenuSized: false
  property real customMenuW: 0
  property real customMenuH: 0
  property bool iconMenuPlaced: false
  property real iconMenuX: 0
  property real iconMenuY: 0
  property bool iconMenuSized: false
  property real iconMenuW: 0
  property real iconMenuH: 0
  property bool helpWindowSized: false
  property real helpWindowW: 0
  property real helpWindowH: 0
  property var menuScreen: null
  property string pickerQuery: ""
  property int pickerSelectedIndex: 0
  property string webName: ""
  property string webUrl: ""
  property string webFocus: "name"
  property var pluginCatalog: []

  property bool tipVisible: false
  property string tipText: ""
  property var tipItem: null
  property var tipItemScreen: null
  property real tipX: 0
  property real tipY: 0
  property var tipScreen: null
  property int tipRequest: 0

  readonly property bool hovered: hoverCount > 0
  readonly property bool uiHeld: menuOpen || pickerOpen || webOpen || dragging || barEdgeDragging
  readonly property bool layoutEmpty: DockModel.isEmpty(layout)

  readonly property int dockHeight: DockModel.dockHeightForIcons(iconSize)
  // Extra room on each side of the icons when the bar is on the left or right.
  readonly property int sideInset: Math.round(Style.space(8) * 0.616)
  readonly property int barCross: dockHeight + sideInset * 2
  readonly property int edgeSize: 4
  readonly property int hideOffset: barCross + 1

  readonly property int endGap: Math.max(0, topBarInsetFile.insetSize)

  FileView {
    id: topBarInsetFile
    property bool shown: false
    property string insetScreen: ""
    property int insetSize: 0
    path: {
      var runtime = String(Quickshell.env("XDG_RUNTIME_DIR") || "")
      if (!runtime.length) runtime = "/tmp"
      return runtime + "/omarchy-top-bar-inset.json"
    }
    watchChanges: true
    printErrors: false
    onLoaded: applyInsetText()
    onFileChanged: reload()
    function applyInsetText() {
      var raw = ""
      try { raw = text() } catch (e) { raw = "" }
      var nextShown = false
      var nextScreen = ""
      var nextSize = 0
      try {
        var parsed = JSON.parse(raw || "")
        nextShown = !!parsed.shown
        nextScreen = String(parsed.screen || "")
        nextSize = Math.max(0, Math.round(Number(parsed.size) || 0))
      } catch (e) {}
      shown = nextShown
      insetScreen = nextScreen
      insetSize = nextSize
    }
  }
  readonly property int iconSlot: iconSize
  // Wider than app icons so two or three letters stay clear of the border.
  readonly property int keybindSlot: iconSlot + Style.space(16)
  // Gap between the three equal sections.
  readonly property int groupGap: Math.max(Style.space(20), iconSlot)
  // Floor so a short group still reads as its own section. The real length
  // is the fullest group when that is longer than this.
  readonly property int defaultSectionSpan: iconSlot * 3 + Style.space(4) * 2

  function sectionContentSpan(items, metrics) {
    var list = items || []
    var slot = metrics && metrics.iconSlot ? metrics.iconSlot : iconSlot
    var keybind = metrics && metrics.keybindSlot ? metrics.keybindSlot : keybindSlot
    if (!list.length)
      return dragging ? slot : 0
    var gap = Style.space(4)
    var total = 0
    for (var i = 0; i < list.length; i++) {
      var item = list[i]
      total += item && String(item.kind || "") === "keybind" ? keybind : slot
    }
    if (list.length > 1)
      total += gap * (list.length - 1)
    return Math.max(total, dragging ? slot : 0)
  }

  function displayedSectionSpan(section, metrics) {
    var slot = metrics && metrics.iconSlot ? metrics.iconSlot : iconSize
    var keybind = metrics && metrics.keybindSlot ? metrics.keybindSlot : slot + Style.space(16)
    var iconGap = Style.space(4)
    var stored = Math.max(0, Math.round(Number(section && section.span) || 0))
    var items = section && section.items ? section.items : []
    if (!items.length) return Math.max(stored, slot)
    var content = 0
    for (var i = 0; i < items.length; i++) {
      var item = items[i]
      content += item && String(item.kind || "") === "keybind" ? keybind : slot
    }
    if (items.length > 1) content += iconGap * (items.length - 1)
    return Math.max(stored, content)
  }

  function sectionSpanSum(layout, metrics) {
    var sections = DockModel.sectionsOf(layout)
    var sum = 0
    for (var i = 0; i < sections.length; i++)
      sum += displayedSectionSpan(sections[i], metrics)
    return sum
  }

  // Section spans, the gaps between them, and the globe.
  function barContentAlong(layout, vertical, metrics) {
    var slot = metrics && metrics.iconSlot ? metrics.iconSlot : iconSlot
    var gap = metrics && metrics.groupGap ? metrics.groupGap : Math.max(Style.space(20), slot)
    var endPad = vertical ? Style.space(6) : Style.space(10)
    var tail = globalToggleSpan(metrics)
    var count = DockModel.groupCount(layout)
    if (count <= 0)
      return tail + endPad * 2
    var between = Math.max(0, count - 1) * gap
    return sectionSpanSum(layout, metrics) + between + endPad * 2 + tail
  }

  // Separator plus globe pinned to the end of the right section.
  function globalToggleSpan(metrics) {
    var slot = metrics && metrics.iconSlot ? metrics.iconSlot : iconSlot
    var rule = Math.max(2, Math.round(Style.space(1)))
    var gap = Style.space(8)
    return gap + rule + gap + slot + Style.space(6) + slot
  }

  function metricsForLook(look) {
    var size = DockModel.clampIconSize(look && look.iconSize ? look.iconSize : iconSize)
    var slot = size
    var keybind = slot + Style.space(16)
    var height = DockModel.dockHeightForIcons(size)
    var cross = height + sideInset * 2
    var edge = DockModel.normalizeEdge(look && look.barEdge ? look.barEdge : barEdge)
    return {
      iconSize: size,
      iconSlot: slot,
      keybindSlot: keybind,
      dockHeight: height,
      barCross: cross,
      hideOffset: cross + 1,
      barEdge: edge,
      groupGap: Math.max(Style.space(20), slot)
    }
  }

  // lead/trail are the margins that center a content-sized bar on the screen.
  // A side bar stays below the top bar. A bottom bar centers on the full width.
  function panelInsets(screen, layout, look) {
    var metrics = metricsForLook(look || lookFor(workspaceId))
    var vertical = metrics.barEdge !== "bottom"
    var along = barContentAlong(layout, vertical, metrics)
    var sw = screen ? Number(screen.width) || 0 : 0
    var sh = screen ? Number(screen.height) || 0 : 0
    var screenAlong = Math.max(1, vertical ? sh : sw)
    var available = vertical ? Math.max(metrics.barCross, screenAlong - endGap) : screenAlong
    var fitted = Math.max(metrics.barCross, Math.min(along, available))
    var slack = Math.max(0, (vertical ? available : screenAlong) - fitted)
    var half = Math.floor(slack / 2)
    return {
      lead: vertical ? endGap + half : half,
      trail: slack - half,
      fitted: fitted
    }
  }
  readonly property color ink: Color.bar.text
  // Selected-window border from the current theme's hyprland.lua.
  property color activeBorder: Color.accent

  function hyprColorToHex(value) {
    var s = String(value || "").trim()
    if (s.charAt(0) === "#") {
      var body = s.slice(1)
      if (body.length === 6 || body.length === 8) return "#" + body.slice(0, 6)
      return ""
    }
    var rgb = s.match(/^rgb\(([0-9a-fA-F]{6})\)$/i)
    if (rgb) return "#" + rgb[1]
    var rgba = s.match(/^rgba\(([0-9a-fA-F]{8})\)$/i)
    if (rgba) return "#" + rgba[1].slice(0, 6)
    return ""
  }

  function readActiveBorder(raw) {
    var text = String(raw || "")
    var simple = text.match(/active_border_color\s*=\s*["']([^"']+)["']/)
    var gradient = text.match(/active_border_color\s*=\s*\{[\s\S]{0,500}?["']([^"']+)["']/)
    var token = (simple && simple[1]) || (gradient && gradient[1]) || ""
    var hex = hyprColorToHex(token)
    return hex.length ? hex : Color.accent
  }
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
  readonly property var sectionChoices: {
    var n = DockModel.groupCount(layout)
    var out = []
    for (var i = 0; i < n; i++) out.push({ label: String(i + 1), value: i })
    return out
  }
  readonly property string pickerTitle: pickerKind === "plugin"
    ? ("Add plugin → " + (pendingSection + 1))
    : pickerKind === "keybind"
      ? "Keybindings"
      : ("Add app → " + (pendingSection + 1))

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
    if (data.sized === true) {
      helpWindowSized = true
      helpWindowW = Number(data.w) || 0
      helpWindowH = Number(data.h) || 0
    }
  }

  function saveHelpPos(screenName) {
    helpPosScreen = String(screenName || helpPosScreen || "")
    helpPosFile.setText(JSON.stringify({
      x: helpPosX,
      y: helpPosY,
      screen: helpPosScreen,
      sized: !!helpWindowSized,
      w: Math.round(helpWindowW),
      h: Math.round(helpWindowH)
    }) + "\n")
    persistSettings()
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
    var screen = screenNamed(mon.name)
    var currentEdge = lookFor(workspaceIdForScreen(screen)).barEdge
    var edge = edgeFromDrag(currentEdge, x0 - originX, y0 - originY, x1 - originX, y1 - originY, w, h)
    if (screen)
      showEdgeHint(screen, x1 - originX, y1 - originY, edge)
    if (commit) {
      barEdgeDragging = false
      setBarEdge(edge, screen)
      hideIconTip()
    } else {
      barEdgeDragging = true
      armReveal(screen)
    }
    return edge
  }

  function setBarEdge(edge, screen) {
    var id = screen ? workspaceIdForScreen(screen) : workspaceId
    var next = edge === "left" || edge === "right" ? edge : "bottom"
    if (!globalChanges && next === lookFor(id).barEdge) return
    if (globalChanges && next === lookFor(id).barEdge && looksShareEdge(next)) return
    patchLooks({ barEdge: next }, id)
  }

  function looksShareEdge(edge) {
    if (DockModel.normalizeEdge(defaultLook.barEdge) !== edge) return false
    var ids = knownWorkspaceIds()
    for (var i = 0; i < ids.length; i++) {
      if (lookFor(ids[i]).barEdge !== edge) return false
    }
    return true
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
    var layout = panel && panel.screenLayout ? panel.screenLayout : root.layout
    var look = panel && panel.screenLook ? panel.screenLook : lookFor(workspaceIdForScreen(screen))
    var metrics = metricsForLook(look)
    var insets = panelInsets(screen, layout, look)
    var cross = metrics.barCross
    if (metrics.barEdge === "right")
      x = sw - (panel && panel.width ? panel.width : cross) + x
    else if (metrics.barEdge === "bottom")
      x = insets.lead + x
    if (metrics.barEdge === "bottom")
      y = sh - (panel && panel.height ? panel.height : cross) + y
    else
      y = insets.lead + y
    return { x: x, y: y, w: sw, h: sh }
  }

  // mapToGlobal on the dock panel is relative to the bar, which no longer
  // starts at the screen edge. Convert a panel-local point to desktop coords.
  function globalFromPanel(panel, sceneX, sceneY) {
    var screen = panel && panel.screen ? panel.screen : null
    var pt = panelPointToScreen(panel, sceneX, sceneY)
    return {
      x: pt.x + (screen ? Number(screen.x) || 0 : 0),
      y: pt.y + (screen ? Number(screen.y) || 0 : 0)
    }
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
    confirmRemoveOpen = false
    confirmSectionIndex = -1
    removeSectionPick = -1
    menuSectionIndex = -1
    hideIconTip()
    releaseRevealSoon()
  }

  function sectionHasIcons(index) {
    var i = Math.round(Number(index))
    if (DockModel.sectionLength(layout, i) > 0) return true
    if (!globalSectionsActive()) return false
    var ids = knownWorkspaceIds()
    for (var n = 0; n < ids.length; n++) {
      if (DockModel.sectionLength(layoutForWorkspaceKey(ids[n]), i) > 0) return true
    }
    return false
  }

  function toggleSectionPick(index) {
    var i = Math.round(Number(index))
    var n = DockModel.groupCount(layout)
    if (i < 0 || i >= n) return
    removeSectionPick = removeSectionPick === i ? -1 : i
  }

  function dropSection(index) {
    var i = Math.round(Number(index))
    removeSectionPick = -1
    commitLayout(function(current) { return DockModel.removeSection(current, i) }, "sections")
  }

  function askRemoveSection(index) {
    var n = DockModel.groupCount(layout)
    var i = Math.round(Number(index))
    if (i < 0 || i >= n) return
    if (!sectionHasIcons(i)) {
      confirmRemoveOpen = false
      confirmSectionIndex = -1
      dropSection(i)
      return
    }
    confirmSectionIndex = i
    confirmRemoveOpen = true
  }

  function cancelRemoveSection() {
    confirmRemoveOpen = false
    confirmSectionIndex = -1
  }

  function commitRemoveSection() {
    var index = confirmSectionIndex
    confirmRemoveOpen = false
    confirmSectionIndex = -1
    if (index < 0) return
    dropSection(index)
    closeMenus()
  }

  function addUserSection() {
    if (DockModel.groupCount(layout) >= DockModel.maxSections()) return
    var span = spanFloor()
    commitLayout(function(current) {
      if (DockModel.groupCount(current) >= DockModel.maxSections()) return current
      return DockModel.addSection(current, span)
    }, "sections")
  }

  function beginSectionResize(panel, index, along) {
    if (panel && panel.screen) syncWorkspaceForScreen(panel.screen)
    resizeTail = false
    resizeBoundaryIndex = Math.round(Number(index))
    resizeOriginAlong = along
    resizeBaseLayout = DockModel.cloneLayout(layout)
    if (resizeFrozenLead < 0 && panel && panel.insets)
      resizeFrozenLead = panel.insets.lead
  }

  function beginTailResize(panel, along) {
    if (panel && panel.screen) syncWorkspaceForScreen(panel.screen)
    if (DockModel.groupCount(layout) < 1) return
    resizeTail = true
    resizeBoundaryIndex = DockModel.groupCount(layout) - 1
    resizeOriginAlong = along
    resizeBaseLayout = DockModel.cloneLayout(layout)
    if (resizeFrozenLead < 0 && panel && panel.insets)
      resizeFrozenLead = panel.insets.lead
  }

  function updateSectionResize(panel, along) {
    if (resizeBoundaryIndex < 0 || !resizeBaseLayout) return
    var delta = along - resizeOriginAlong
    var slot = panel && panel.screenIconSlot ? panel.screenIconSlot : iconSlot
    var keybind = panel && panel.screenKeybindSlot ? panel.screenKeybindSlot : keybindSlot
    var gap = Style.space(4)
    var minA = DockModel.sectionMinimum(DockModel.sectionItems(resizeBaseLayout, resizeBoundaryIndex), slot, keybind, gap)
    var next = DockModel.resizeSection(resizeBaseLayout, resizeBoundaryIndex, delta, minA)
    // Keep the same section objects while dragging. Replacing the layout
    // rebuilds the separator under the pointer and the drag dies.
    var live = layout && layout.sections ? layout.sections : []
    var preview = next.sections
    for (var i = 0; i < live.length && i < preview.length; i++)
      live[i].span = preview[i].span
    resizePreviewTick = resizePreviewTick + 1
  }

  function endSectionResize() {
    if (resizeBoundaryIndex < 0) return
    var before = resizeBaseLayout ? DockModel.cloneLayout(resizeBaseLayout) : null
    var after = DockModel.cloneLayout(layout)
    resizeBoundaryIndex = -1
    resizeTail = false
    resizeBaseLayout = null
    resizeFrozenLead = -1
    if (before && globalSectionsActive()) {
      var slot = iconSize
      var keybind = iconSize + Style.space(16)
      var gap = Style.space(4)
      layout = DockModel.cloneLayout(before)
      commitLayout(function(current) {
        return DockModel.applySpanDeltas(current, before, after, slot, keybind, gap)
      }, "sections")
      return
    }
    persistLayout(after)
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
    tipItem = null
    tipItemScreen = null
    tipScreen = null
  }

  function showIconTip(screen, globalX, globalY, text) {
    var label = String(text || "")
    var tipsOn = screen ? lookFor(workspaceIdForScreen(screen)).showTips !== false : showTips
    if (!tipsOn || !label.length || dragging || menuOpen || pickerOpen || webOpen) {
      hideIconTip()
      return
    }
    tipItem = null
    tipItemScreen = null
    tipText = label
    tipScreen = screen
    // Screen-local cursor. The tip card centers on this point.
    tipX = globalX - (screen ? screen.x : 0)
    tipY = globalY - (screen ? screen.y : 0)
    if (tipVisible)
      return
    tipDelay.restart()
  }

  function refreshIconTipPosition(screen, globalX, globalY) {
    if (!tipVisible && !tipDelay.running) return
    if (screen) tipScreen = screen
    tipX = globalX - (screen ? screen.x : 0)
    tipY = globalY - (screen ? screen.y : 0)
  }

  function screenNameOf(screen) {
    return screen ? String(screen.name || "") : ""
  }

  function setHovered(hovered, screen) {
    hoverCount = Math.max(0, hoverCount + (hovered ? 1 : -1))
    if (hovered && screen) {
      revealScreenName = screenNameOf(screen)
      hoveredScreen = screen
    }
    if (hoverCount === 0) {
      if (cursorKeepsBar())
        armReveal()
      else
        hideTimer.restart()
    } else if (hovered) {
      hideTimer.stop()
      revealHeld = true
    }
  }

  function armReveal(screen) {
    var name = screenNameOf(screen)
    if (name.length)
      revealScreenName = name
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

  // True only for the output that was hovered. A menu or drag keeps that
  // output's dock up; every other workspace stays slid away.
  function screenRevealed(screen) {
    return screenRevealedName(screenNameOf(screen))
  }

  function autoHideActive() {
    var ids = knownWorkspaceIds()
    for (var i = 0; i < ids.length; i++) {
      if (lookFor(ids[i]).autoHide) return true
    }
    return !!(defaultLook && defaultLook.autoHide)
  }

  function screenRevealedName(name) {
    var output = String(name || "")
    if (output.length && !lookFor(workspaceIdForOutput(output)).autoHide) return true
    if (!output.length && !autoHide) return true
    if (!output.length) return false
    if (uiHeld) {
      var pinned = screenNameOf(menuScreen)
      if (!pinned.length) pinned = revealScreenName
      return pinned === output
    }
    if (!(revealHeld || hovered)) return false
    return revealScreenName === output
  }

  function hyprMonitors() {
    var mons = []
    try { mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [] } catch (e) { mons = [] }
    return mons
  }

  // Which output's outer edge contains this global pointer. Bottom edges share
  // a Y, so the match has to include that output's X range. Sliding off the
  // outer edge still counts; crossing onto another output does not.
  function pointerEdgeScreenName(x, y) {
    var mons = hyprMonitors()
    var offName = ""
    var offDist = 1e12
    var insideAny = false
    for (var i = 0; i < mons.length; i++) {
      var mon = mons[i]
      if (!mon) continue
      var mx = Number(mon.x) || 0
      var my = Number(mon.y) || 0
      var mw = Number(mon.width) || 0
      var mh = Number(mon.height) || 0
      var name = String(mon.name || "")
      if (!name.length || mw < 1 || mh < 1) continue
      var look = lookFor(monWorkspaceId(mon))
      var metrics = metricsForLook(look)
      var edge = metrics.barEdge
      var cross = metrics.barCross
      var insideX = x >= mx && x < mx + mw
      var insideY = y >= my && y < my + mh
      if (insideX && insideY) insideAny = true
      if (edge === "left") {
        if (insideY && x >= mx && x <= mx + cross)
          return name
        if (insideY && x < mx) {
          var dl = mx - x
          if (dl < offDist) { offDist = dl; offName = name }
        }
      } else if (edge === "right") {
        if (insideY && x >= mx + mw - cross && x < mx + mw)
          return name
        if (insideY && x >= mx + mw) {
          var dr = x - (mx + mw)
          if (dr < offDist) { offDist = dr; offName = name }
        }
      } else if (insideX && y >= my + mh - cross) {
        return name
      }
    }
    if (!insideAny && offName.length) {
      var offMon = null
      var mons2 = hyprMonitors()
      for (var j = 0; j < mons2.length; j++) {
        if (mons2[j] && String(mons2[j].name || "") === offName) offMon = mons2[j]
      }
      if (offMon && lookFor(monWorkspaceId(offMon)).barEdge !== "bottom")
        return offName
    }
    return ""
  }

  function monWorkspaceId(mon) {
    var ws = mon ? mon.activeWorkspace : null
    if (ws && ws.id !== undefined && ws.id !== null)
      return DockModel.workspaceKey(ws.id)
    return workspaceId
  }

  // Remember the screen whose edge was just shown. The pointer can slide off
  // that screen, past the bar, and the bar should stay out until the pointer
  // comes back onto the screen on the inner side of the bar.
  function noteEdgeHold(screen) {
    var name = screenNameOf(screen)
    if (!name.length) return
    revealScreenName = name
    if (!pointerProc.running)
      pointerProc.running = true
  }

  function cursorKeepsBar() {
    if (!pointerKnown || !revealScreenName.length) return false
    return pointerEdgeScreenName(pointerX, pointerY) === revealScreenName
  }

  function notePointer(x, y) {
    var wasKeeping = cursorKeepsBar()
    pointerX = x
    pointerY = y
    pointerKnown = true
    if (!(revealHeld || hovered)) return
    if (menuOpen || pickerOpen || webOpen) return
    // Stay on the workspace that was hovered. Crossing onto another output's
    // edge does not reveal that output; its own edge hover does.
    if (cursorKeepsBar()) {
      armReveal()
      return
    }
    if (wasKeeping && revealHeld && !hovered && !uiHeld)
      hideTimer.restart()
  }

  function lookFor(id) {
    return DockModel.lookForWorkspace(workspaceLooks, id, defaultLook)
  }

  // One tone is an 8% step in lightness. Three tones is the watermark on an empty section.
  function shiftTones(color, steps) {
    var c = color
    var light = c.hslLightness + 0.08 * steps
    light = Math.max(0, Math.min(1, light))
    return Qt.hsla(c.hslHue, c.hslSaturation, light, 1)
  }

  function darkerTones(color, steps) {
    return shiftTones(color, -Math.max(0, steps))
  }

  function lighterTones(color, steps) {
    return shiftTones(color, Math.max(0, steps))
  }

  function fillForLook(look) {
    var src = look || lookFor(workspaceId)
    var hex = DockModel.resolveThemeColor(themePalette, src.bgColorKey, src.bgColorHex)
    if (hex && String(hex).charAt(0) === "#")
      return hex
    return surface
  }

  function knownWorkspaceIds() {
    var seen = {}
    var out = []
    function add(id) {
      var key = DockModel.workspaceKey(id)
      if (!key.length || seen[key]) return
      seen[key] = true
      out.push(key)
    }
    var listed = listedWorkspaceIds || []
    for (var i = 0; i < listed.length; i++) add(listed[i])
    add(workspaceId)
    var maps = workspaceLayouts || {}
    for (var layoutKey in maps) {
      if (Object.prototype.hasOwnProperty.call(maps, layoutKey)) add(layoutKey)
    }
    var looks = workspaceLooks || {}
    for (var lookKey in looks) {
      if (Object.prototype.hasOwnProperty.call(looks, lookKey)) add(lookKey)
    }
    return out
  }

  function activeLook() {
    return {
      barEdge: barEdge,
      iconSize: iconSize,
      bgOpacity: bgOpacity,
      bgColorKey: bgColorKey,
      bgColorHex: bgColorHex,
      showTips: showTips,
      autoHide: autoHide
    }
  }

  function applyActiveLook(look) {
    var next = DockModel.cloneLook(look, defaultLook)
    barEdge = next.barEdge
    iconSize = next.iconSize
    bgOpacity = next.bgOpacity
    bgColorKey = next.bgColorKey
    bgColorHex = next.bgColorHex
    showTips = next.showTips
    autoHide = next.autoHide
  }

  // patch is absolute values. Global Changes writes them onto every workspace
  // and the shared default. Otherwise only the workspace being edited changes.
  function patchLooks(patch, id) {
    var key = DockModel.workspaceKey(id || workspaceId)
    if (globalChanges) {
      var ids = knownWorkspaceIds()
      var baseDefault = defaultLook
      workspaceLooks = DockModel.applyLookPatch(workspaceLooks, ids, patch, baseDefault)
      defaultLook = DockModel.patchLook(baseDefault, patch)
      applyActiveLook(lookFor(workspaceId))
    } else {
      var local = DockModel.patchLook(lookFor(key), patch)
      workspaceLooks = DockModel.setWorkspaceLook(workspaceLooks, key, local)
      if (key === DockModel.workspaceKey(workspaceId))
        applyActiveLook(local)
    }
    persistSettings()
  }

  function persistSettings() {
    if (_loadingConfig || _switchingWorkspace) return
    if (workspaceTouched[DockModel.workspaceKey(workspaceId)])
      workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, workspaceId, layout)
    // Keep a non-empty shared default so new workspaces inherit icons.
    if (!DockModel.isEmpty(layout) && DockModel.isEmpty(defaultLayout))
      defaultLayout = DockModel.cloneLayout(layout)
    if (shell && typeof shell.updateEntryInline === "function") {
      var shared = DockModel.cloneLook(defaultLook)
      var payload = {
        layout: DockModel.isEmpty(layout) ? DockModel.cloneLayout(defaultLayout) : DockModel.cloneLayout(layout),
        defaultLayout: DockModel.cloneLayout(defaultLayout),
        workspaces: DockModel.pruneEmptyWorkspaceLayouts(workspaceLayouts, defaultLayout),
        iconSize: shared.iconSize,
        bgOpacity: shared.bgOpacity,
        bgColorKey: shared.bgColorKey,
        bgColorHex: shared.bgColorHex,
        showTips: shared.showTips,
        autoHide: shared.autoHide,
        barEdge: shared.barEdge,
        globalChanges: !!globalChanges,
        globalIcons: !!globalIcons,
        globalSections: !!globalSections,
        workspaceLooks: DockModel.cloneLookMap(workspaceLooks),
        customMenu: {
          placed: !!customMenuPlaced,
          sized: !!customMenuSized,
          x: Math.round(customMenuX),
          y: Math.round(customMenuY),
          w: Math.round(customMenuW),
          h: Math.round(customMenuH)
        },
        iconMenu: {
          placed: !!iconMenuPlaced,
          sized: !!iconMenuSized,
          x: Math.round(iconMenuX),
          y: Math.round(iconMenuY),
          w: Math.round(iconMenuW),
          h: Math.round(iconMenuH)
        },
        helpWindow: {
          placed: !!helpPosSet,
          sized: !!helpWindowSized,
          x: Math.round(helpPosX),
          y: Math.round(helpPosY),
          w: Math.round(helpWindowW),
          h: Math.round(helpWindowH)
        }
      }
      try { payload = JSON.parse(JSON.stringify(payload)) } catch (e) {}
      shell.updateEntryInline(pluginId, payload)
    }
  }

  function persistLayout(next) {
    layout = materializeLayout(DockModel.cloneLayout(next))
    var key = DockModel.workspaceKey(workspaceId)
    var touched = Object.assign({}, workspaceTouched)
    touched[key] = true
    workspaceTouched = touched
    workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, key, layout)
    persistSettings()
  }

  function globalIconsActive() {
    return globalChanges && globalIcons
  }

  function globalSectionsActive() {
    return globalChanges && globalSections
  }

  // mutator(layout) -> layout. scope "icons" or "sections" follows that
  // checkbox, and only when Global Changes is on. Anything else follows the toggle alone.
  function commitLayout(mutator, scope) {
    if (typeof mutator !== "function") return
    var spread = globalChanges
    if (scope === "icons") spread = globalIconsActive()
    else if (scope === "sections") spread = globalSectionsActive()
    if (!spread) {
      persistLayout(mutator(DockModel.cloneLayout(layout)))
      return
    }
    var ids = knownWorkspaceIds()
    var currentKey = DockModel.workspaceKey(workspaceId)
    var maps = DockModel.cloneWorkspaceMap(workspaceLayouts)
    var nextDefault = mutator(DockModel.cloneLayout(defaultLayout))
    for (var i = 0; i < ids.length; i++) {
      var key = DockModel.workspaceKey(ids[i])
      var base = key === currentKey
        ? layout
        : (Object.prototype.hasOwnProperty.call(maps, key) ? maps[key] : defaultLayout)
      maps[key] = mutator(DockModel.cloneLayout(base))
    }
    if (!Object.prototype.hasOwnProperty.call(maps, currentKey))
      maps[currentKey] = mutator(DockModel.cloneLayout(layout))
    layout = DockModel.cloneLayout(maps[currentKey])
    defaultLayout = DockModel.cloneLayout(nextDefault)
    workspaceLayouts = maps
    var touched = Object.assign({}, workspaceTouched)
    for (var j = 0; j < ids.length; j++)
      touched[DockModel.workspaceKey(ids[j])] = true
    touched[currentKey] = true
    workspaceTouched = touched
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

  function spanFloor() {
    return DockModel.floorSpan(iconSize, Style.space(4))
  }

  function materializeLayout(next) {
    return DockModel.assignMissingSpans(next, iconSize, iconSize + Style.space(16), Style.space(4))
  }

  function setItemPlaceSection(section) {
    var key = DockModel.sectionIndex(section)
    itemPlaceSection = key
    if (!menuItem) return
    var copy = DockModel.cloneItem(menuItem)
    var span = spanFloor()
    commitLayout(function(current) { return DockModel.addItemGrowing(current, key, copy, span) }, "icons")
  }

  function setItemOnWorkspace(item, id, enabled) {
    if (!item || !item.id) return
    var key = DockModel.workspaceKey(id)
    var copy = DockModel.cloneItem(item)
    if (!copy) return
    var current = DockModel.cloneLayout(layoutForWorkspaceKey(key))
    var span = spanFloor()
    var next = enabled
      ? (globalIconsActive()
        ? DockModel.addItemGrowing(current, itemPlaceSection, copy, span)
        : DockModel.addItemClamped(current, itemPlaceSection, copy, span))
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
  function workspaceIdForOutput(name) {
    return workspaceIdForScreen(screenNamed(name))
  }

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
    applyActiveLook(lookFor(nextId))
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

  function scaleSpansForSize(id, oldSize, newSize) {
    if (!(oldSize > 0) || !(newSize > 0) || oldSize === newSize) return
    var ratio = newSize / oldSize
    if (globalChanges) {
      var ids = knownWorkspaceIds()
      var maps = DockModel.cloneWorkspaceMap(workspaceLayouts)
      for (var i = 0; i < ids.length; i++) {
        var ws = DockModel.workspaceKey(ids[i])
        var base = ws === DockModel.workspaceKey(workspaceId) ? layout : (maps[ws] || defaultLayout)
        maps[ws] = DockModel.scaleSpans(base, ratio)
      }
      defaultLayout = DockModel.scaleSpans(defaultLayout, ratio)
      var currentKey = DockModel.workspaceKey(workspaceId)
      if (maps[currentKey]) layout = DockModel.cloneLayout(maps[currentKey])
      workspaceLayouts = maps
    } else {
      var localKey = DockModel.workspaceKey(id || workspaceId)
      var local = DockModel.scaleSpans(layoutForWorkspaceKey(localKey), ratio)
      if (localKey === DockModel.workspaceKey(workspaceId)) layout = local
      workspaceLayouts = DockModel.setWorkspaceLayout(workspaceLayouts, localKey, local)
    }
  }

  function bumpIconSize(delta, id) {
    var key = DockModel.workspaceKey(id || workspaceId)
    var base = lookFor(key).iconSize
    var next = DockModel.clampIconSize(base + delta)
    scaleSpansForSize(key, base, next)
    patchLooks({ iconSize: next }, key)
  }

  function bumpBgOpacity(delta, id) {
    var key = DockModel.workspaceKey(id || workspaceId)
    var base = lookFor(key).bgOpacity
    patchLooks({ bgOpacity: DockModel.clampBgOpacity(base + delta) }, key)
  }

  function setBarBackground(key, hex) {
    patchLooks({
      bgColorKey: String(key || ""),
      bgColorHex: String(hex || "")
    })
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
        var badgeId = menuItem.id
        commitLayout(function(current) { return DockModel.setItemBadge(current, badgeId, mark) }, "icons")
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
      var renameId = menuItem.id
      commitLayout(function(current) { return DockModel.renameItem(current, renameId, name) }, "icons")
      var found = DockModel.findItem(layout, menuItem.id)
      if (found)
        menuItem = found
    }
    labelDraft = DockModel.itemLabel(menuItem)
    labelEdit = false
    labelEditTarget = ""
  }

  function setShowTips(enabled) {
    if (!enabled) hideIconTip()
    patchLooks({ showTips: !!enabled })
  }

  function toggleShowTips() {
    setShowTips(!lookFor(workspaceId).showTips)
  }

  function setAutoHide(enabled) {
    patchLooks({ autoHide: !!enabled })
  }

  function toggleAutoHide() {
    setAutoHide(!lookFor(workspaceId).autoHide)
  }

  function toggleGlobalChanges() {
    globalChanges = !globalChanges
    persistSettings()
  }

  function handleDockWheel(wheel, id) {
    if (!wheel) return
    var key = id ? DockModel.workspaceKey(id) : workspaceId
    var mods = wheel.modifiers
    // Alt+wheel → background opacity (also accept Meta/Alt combos that still include Alt).
    if (mods & Qt.AltModifier) {
      if (wheel.angleDelta.y > 0) bumpBgOpacity(5, key)
      else if (wheel.angleDelta.y < 0) bumpBgOpacity(-5, key)
      wheel.accepted = true
      return
    }
    if (wheel.angleDelta.y > 0) bumpIconSize(2, key)
    else if (wheel.angleDelta.y < 0) bumpIconSize(-2, key)
    wheel.accepted = true
  }

  // Super+Plus / Super+Minus (via Hyprland binds → IPC) only when cursor is on the dock.
  function hoveredWorkspaceId() {
    if (hoveredScreen) return workspaceIdForScreen(hoveredScreen)
    return workspaceId
  }

  function iconsLargerFromHotkey() {
    if (!hovered) return "ignored"
    bumpIconSize(4, hoveredWorkspaceId())
    return "ok"
  }

  function iconsSmallerFromHotkey() {
    if (!hovered) return "ignored"
    bumpIconSize(-4, hoveredWorkspaceId())
    return "ok"
  }

  function opacityUpFromHotkey() {
    if (!hovered) return "ignored"
    bumpBgOpacity(5, hoveredWorkspaceId())
    return "ok"
  }

  function opacityDownFromHotkey() {
    if (!hovered) return "ignored"
    bumpBgOpacity(-5, hoveredWorkspaceId())
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
    dragScreenName = screenNameOf(screen)
    armReveal(screen)
  }

  function updateIconDragGhost(chromeX, chromeY) {
    var ghostW = dragGhostBadge.length && barEdge === "bottom" ? keybindSlot : iconSlot
    var ghostH = dragGhostBadge.length && barEdge !== "bottom" ? keybindSlot : iconSlot
    dragGhostX = chromeX - ghostW / 2
    dragGhostY = chromeY - ghostH / 2
  }

  function setIconDropTarget(section, index) {
    dropSection = section
    dropIndex = Math.max(0, Math.round(Number(index) || 0))
  }

  function commitIconDrag() {
    if (dragging && dragItem && dropSection) {
      var itemId = dragItem.id
      var section = dropSection
      var index = dropIndex
      var copy = DockModel.cloneItem(dragItem)
      var span = spanFloor()
      commitLayout(function(current) {
        return DockModel.moveItemAtGrowing(current, itemId, section, index, span, copy)
      }, "icons")
    }
    cancelIconDrag()
  }

  function cancelIconDrag() {
    dragging = false
    dragItem = null
    dropSection = ""
    dropIndex = 0
    dragGhostSource = ""
    dragGhostBadge = ""
    dragScreenName = ""
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

    globalChanges = cfg.globalChanges === true
    globalIcons = cfg.globalIcons !== false
    globalSections = cfg.globalSections !== false
    if (cfg.customMenu) {
      customMenuPlaced = cfg.customMenu.placed === true
      customMenuSized = cfg.customMenu.sized === true
      customMenuX = Number(cfg.customMenu.x) || 0
      customMenuY = Number(cfg.customMenu.y) || 0
      customMenuW = Number(cfg.customMenu.w) || 0
      customMenuH = Number(cfg.customMenu.h) || 0
    }
    if (cfg.iconMenu) {
      iconMenuPlaced = cfg.iconMenu.placed === true
      iconMenuSized = cfg.iconMenu.sized === true
      iconMenuX = Number(cfg.iconMenu.x) || 0
      iconMenuY = Number(cfg.iconMenu.y) || 0
      iconMenuW = Number(cfg.iconMenu.w) || 0
      iconMenuH = Number(cfg.iconMenu.h) || 0
    }
    if (cfg.helpWindow) {
      helpPosSet = cfg.helpWindow.placed === true
      helpPosX = Number(cfg.helpWindow.x) || 0
      helpPosY = Number(cfg.helpWindow.y) || 0
      helpWindowSized = cfg.helpWindow.sized === true
      helpWindowW = Number(cfg.helpWindow.w) || 0
      helpWindowH = Number(cfg.helpWindow.h) || 0
    }
    defaultLook = DockModel.cloneLook({
      barEdge: cfg.barEdge,
      iconSize: cfg.iconSize > 0 ? cfg.iconSize : DockModel.defaultIconSize(),
      bgOpacity: cfg.bgOpacity >= 0 ? cfg.bgOpacity : DockModel.defaultBgOpacity(),
      bgColorKey: cfg.bgColorKey,
      bgColorHex: cfg.bgColorHex,
      showTips: cfg.showTips !== false,
      autoHide: cfg.autoHide !== false
    })
    workspaceLooks = DockModel.cloneLookMap(cfg.workspaceLooks)
    applyActiveLook(lookFor(workspaceId))
    materializeAllLayouts()
    _loadingConfig = false
    persistSettings()
  }

  function materializeAllLayouts() {
    var slot = iconSize
    var keybind = iconSize + Style.space(16)
    var gap = Style.space(4)
    defaultLayout = DockModel.assignMissingSpans(defaultLayout, slot, keybind, gap)
    var maps = DockModel.cloneWorkspaceMap(workspaceLayouts)
    for (var key in maps) {
      if (!Object.prototype.hasOwnProperty.call(maps, key)) continue
      maps[key] = DockModel.assignMissingSpans(maps[key], slot, keybind, gap)
    }
    workspaceLayouts = maps
    if (Object.prototype.hasOwnProperty.call(workspaceLayouts, DockModel.workspaceKey(workspaceId)))
      layout = DockModel.cloneLayout(workspaceLayouts[DockModel.workspaceKey(workspaceId)])
    else
      layout = DockModel.cloneLayout(defaultLayout)
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
    return itemRunningCount(item, screen, _gen) > 0
  }

  // Windows of this icon on the workspace that screen is showing.
  function itemRunningCount(item, screen, _gen) {
    var _rev = toplevelRevision
    var _live = liveClientGen
    if (!item) return 0
    var ws = String(workspaceIdForScreen(screen) || "")
    if (String(item.kind || "") === "keybind") {
      if (!_live) return 0
      var rows = liveClients || []
      var keys = 0
      for (var i = 0; i < rows.length; i++) {
        var client = rows[i]
        if (!client) continue
        if (ws.length && String(client.workspaceId || "") !== ws) continue
        if (DockModel.keybindMatchesClass(item, client.className)
            || DockModel.keybindMatchesClass(item, client.initialClass))
          keys++
      }
      return keys
    }
    var values = hyprToplevels()
    var count = 0
    for (var j = 0; j < values.length; j++) {
      var raw = values[j]
      if (!raw) continue
      if (ws.length && toplevelWorkspaceId(raw) !== ws) continue
      if (!windowMatchesItem(item, toplevelView(raw))) continue
      count++
    }
    return count
  }

  function showItemIconTip(screen, globalX, globalY, item) {
    showIconTip(screen, globalX, globalY, DockModel.itemLabel(item))
    if (tipText === DockModel.itemLabel(item)) {
      tipItem = item
      tipItemScreen = screen
    }
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
    armReveal(screen)
  }

  function openItemMenu(screen, item, globalX, globalY) {
    menuSectionIndex = -1
    confirmRemoveOpen = false
    syncWorkspaceForScreen(screen)
    helpOpen = false
    menuItem = item
    labelDraft = DockModel.itemLabel(item)
    labelEdit = false
    menuScreen = screen
    menuX = globalX - (screen ? screen.x : 0)
    menuY = globalY - (screen ? screen.y : 0)
    var loc = DockModel.findItemLocation(layout, item ? item.id : "")
    itemPlaceSection = loc ? DockModel.sectionIndex(loc.section) : 0
    menuOpen = true
    pickerOpen = false
    webOpen = false
    armReveal(screen)
  }

  function beginAdd(section) {
    pendingSection = DockModel.groupCount(layout) ? DockModel.sectionIndex(section) : 0
    pickerKind = "app"
    menuOpen = false
    pickerQuery = ""
    pickerSelectedIndex = 0
    ensureMenuScreen()
    pickerOpen = true
    webOpen = false
    armReveal(menuScreen)
  }

  function beginAddPlugin(section) {
    pendingSection = DockModel.groupCount(layout) ? DockModel.sectionIndex(section) : 0
    pickerKind = "plugin"
    menuOpen = false
    pickerQuery = ""
    pickerSelectedIndex = 0
    ensureMenuScreen()
    pickerOpen = true
    webOpen = false
    refreshPluginCatalog()
    armReveal(menuScreen)
  }

  function beginKeybindAdd(section) {
    pendingSection = DockModel.groupCount(layout) ? DockModel.sectionIndex(section) : 0
    pickerKind = "keybind"
    menuOpen = false
    pickerQuery = ""
    pickerSelectedIndex = 0
    ensureMenuScreen()
    pickerOpen = true
    webOpen = false
    refreshKeybinds()
    armReveal(menuScreen)
  }

  function beginWebAdd(section) {
    pendingSection = DockModel.groupCount(layout) ? DockModel.sectionIndex(section) : 0
    menuOpen = false
    pickerOpen = false
    webName = ""
    webUrl = ""
    webFocus = "name"
    ensureMenuScreen()
    webOpen = true
    armReveal(menuScreen)
  }

  function acceptApp(entry) {
    if (!entry) return
    var section = pendingSection
    var item = DockModel.makeAppItem(entry)
    var span = spanFloor()
    commitLayout(function(current) { return DockModel.addItemGrowing(current, section, item, span) }, "icons")
    closeMenus()
  }

  function acceptPlugin(plugin) {
    if (!plugin) return
    var section = pendingSection
    var item = DockModel.makePluginItem(plugin)
    var span = spanFloor()
    commitLayout(function(current) { return DockModel.addItemGrowing(current, section, item, span) }, "icons")
    closeMenus()
  }

  function acceptKeybind(row) {
    if (!row) return
    var section = pendingSection
    var item = DockModel.makeKeybindItem(row, layout)
    var span = spanFloor()
    commitLayout(function(current) { return DockModel.addItemGrowing(current, section, item, span) }, "icons")
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
    var section = pendingSection
    var item = DockModel.makeWebItem(name, url)
    var span = spanFloor()
    commitLayout(function(current) { return DockModel.addItemGrowing(current, section, item, span) }, "icons")
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
    console.log("bottom-dock loaded search-v3")
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
      if (root.autoHideActive() && !pointerProc.running)
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
    id: activeBorderFile
    path: Color.currentThemePath + "/hyprland.lua"
    watchChanges: true
    printErrors: false
    onLoaded: root.activeBorder = root.readActiveBorder(text())
    onFileChanged: reload()
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
      root.globalChanges = false
      root.workspaceLooks = ({})
      root.defaultLook = DockModel.defaultLook()
      root.iconSize = DockModel.defaultIconSize()
      root.bgOpacity = DockModel.defaultBgOpacity()
      root.bgColorKey = ""
      root.bgColorHex = ""
      root.showTips = true
      root.autoHide = true
      root.barEdge = "bottom"
    }
  }

  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  readonly property string focusedWorkspaceKey: DockModel.workspaceKey(
    focusedWorkspace && focusedWorkspace.id !== undefined ? focusedWorkspace.id : 1)

  onFocusedWorkspaceKeyChanged: {
    if (_loadingConfig || menuOpen || pickerOpen || webOpen) return
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
          var monLook = root.lookFor(wsKey || root.workspaceId)
          monitors.push({
            name: String(m && m.name ? m.name : ""),
            focused: !!(m && m.focused),
            workspaceId: String(wsKey),
            barEdge: String(monLook.barEdge || "bottom"),
            sections: DockModel.groupCount(shown),
            left: DockModel.sectionLength(shown, 0),
            center: DockModel.sectionLength(shown, 1),
            right: DockModel.sectionLength(shown, 2)
          })
        }
      } catch (e) {
      }
      return JSON.stringify({
        workspaceId: String(root.workspaceId),
        globalChanges: !!root.globalChanges,
        barEdge: String(root.barEdge || "bottom"),
        focusedKey: String(root.focusedWorkspaceKey),
        keys: keys,
        monitors: monitors,
        sections: DockModel.groupCount(root.layout),
        left: DockModel.sectionLength(root.layout, 0),
        center: DockModel.sectionLength(root.layout, 1),
        right: DockModel.sectionLength(root.layout, 2),
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
        outputName: modelData ? String(modelData.name || "") : ""
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      EdgePanel {
        required property var modelData
        screen: modelData
        outputName: modelData ? String(modelData.name || "") : ""
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

  component StatusToggle: BorderSurface {
    id: toggleRoot
    property string label: ""
    property bool checked: false
    signal clicked()

    implicitHeight: Style.space(48)
    radius: Style.cornerRadius
    color: Style.controlFill(false, toggleMouse.containsMouse, root.menuForeground, Color.accent)
    borderSpec: Border.controlSpec(toggleMouse.containsMouse ? "hover-cursor" : "normal", root.menuForeground, Color.accent)

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(8)

      Text {
        width: parent.width - track.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: label
        color: root.menuForeground
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
      }

      Rectangle {
        id: track
        width: Style.space(44)
        height: Style.space(24)
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        color: checked ? "#2f9e44" : "#d64545"
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
          width: parent.height - Style.space(4)
          height: width
          radius: height / 2
          anchors.verticalCenter: parent.verticalCenter
          x: checked ? parent.width - width - Style.space(2) : Style.space(2)
          color: "#ffffff"
          Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
      }
    }

    MouseArea {
      id: toggleMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: toggleRoot.clicked()
    }
  }

  component EdgePanel: PanelWindow {
    id: edgeWindow
    property string outputName: ""
    readonly property var screenLook: {
      root.workspaceLooks; root.defaultLook; Hyprland.focusedWorkspace
      return root.lookFor(root.workspaceIdForOutput(outputName))
    }
    readonly property string screenEdge: root.metricsForLook(screenLook).barEdge
    // outputName comes from the delegate so this binding does not read screen.
    readonly property bool localRevealed: {
      root.workspaceLooks; root.defaultLook; root.revealHeld; root.hovered; root.uiHeld
      root.revealScreenName; root.menuScreen; outputName
      return root.screenRevealedName(outputName)
    }
    readonly property bool armed: screenLook.autoHide && !localRevealed
    visible: armed
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-edge"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.left: screenEdge === "left" || screenEdge === "bottom"
    anchors.right: screenEdge === "right" || screenEdge === "bottom"
    anchors.top: screenEdge !== "bottom"
    anchors.bottom: true
    margins.top: screenEdge === "bottom" ? 0 : root.endGap
    margins.bottom: screenEdge === "bottom" ? 0 : root.endGap
    margins.left: screenEdge === "bottom" ? root.endGap : 0
    margins.right: screenEdge === "bottom" ? root.endGap : 0
    implicitWidth: screenEdge === "bottom" ? 0 : root.edgeSize
    implicitHeight: screenEdge === "bottom" ? root.edgeSize : 0
    HoverHandler {
      enabled: edgeWindow.armed
      onHoveredChanged: {
        if (hovered) {
          if (edgeWindow.screen) root.noteEdgeHold(edgeWindow.screen)
          root.armReveal(edgeWindow.screen)
        } else if (!root.screenRevealed(edgeWindow.screen)) {
          root.releaseRevealSoon()
        }
      }
    }
  }

  component DockPanel: PanelWindow {
    id: dockWindow
    property string outputName: ""
    // outputName comes from the delegate so this binding does not read screen.
    readonly property bool localRevealed: {
      root.workspaceLooks; root.defaultLook; root.revealHeld; root.hovered; root.uiHeld
      root.revealScreenName; root.menuScreen; outputName
      return root.screenRevealedName(outputName)
    }
    property int localSlide: localRevealed ? 0 : dockWindow.screenMetrics.hideOffset
    Behavior on localSlide {
      NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    visible: true
    exclusionMode: dockWindow.screenLook.autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock"
    WlrLayershell.layer: WlrLayer.Top
    readonly property bool verticalBar: dockWindow.screenEdge !== "bottom"
    readonly property var insets: {
      var _tick = root.resizePreviewTick
      return root.panelInsets(dockWindow.screen, screenLayout, screenLook)
    }
    anchors.left: verticalBar ? dockWindow.screenEdge === "left" : true
    anchors.right: verticalBar ? dockWindow.screenEdge === "right" : true
    anchors.top: verticalBar
    anchors.bottom: true
    readonly property bool resizePinned: root.resizeFrozenLead >= 0 && dockWindow.screenWorkspaceId === root.workspaceId
    margins.top: verticalBar && resizePinned ? root.resizeFrozenLead : (verticalBar ? insets.lead : 0)
    margins.bottom: verticalBar && resizePinned
      ? Math.max(0, (dockWindow.screen ? dockWindow.screen.height : 0) - root.resizeFrozenLead - insets.fitted)
      : (verticalBar ? insets.trail : -localSlide)
    margins.left: !verticalBar && resizePinned
      ? root.resizeFrozenLead
      : (verticalBar ? (dockWindow.screenEdge === "left" ? -localSlide : 0) : insets.lead)
    margins.right: !verticalBar && resizePinned
      ? Math.max(0, (dockWindow.screen ? dockWindow.screen.width : 0) - root.resizeFrozenLead - insets.fitted)
      : (verticalBar ? (dockWindow.screenEdge === "right" ? -localSlide : 0) : insets.trail)
    implicitWidth: verticalBar ? dockWindow.screenBarCross : insets.fitted
    implicitHeight: verticalBar ? insets.fitted : dockWindow.screenBarCross

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
    readonly property var screenLook: {
      var _looks = root.workspaceLooks
      var _def = root.defaultLook
      var _id = screenWorkspaceId
      return root.lookFor(_id)
    }
    readonly property var screenMetrics: root.metricsForLook(screenLook)
    readonly property string screenEdge: screenMetrics.barEdge
    readonly property int screenIconSlot: screenMetrics.iconSlot
    readonly property int screenKeybindSlot: screenMetrics.keybindSlot
    readonly property int screenBarCross: screenMetrics.barCross
    readonly property int screenGroupGap: screenMetrics.groupGap
    readonly property color screenFill: root.fillForLook(screenLook)
    readonly property bool screenShowTips: screenLook.showTips !== false

    HoverHandler {
      onHoveredChanged: {
        if (hovered && dockWindow.screen)
          root.noteEdgeHold(dockWindow.screen)
        root.setHovered(hovered, dockWindow.screen)
      }
      Component.onDestruction: if (hovered) root.setHovered(false, dockWindow.screen)
    }

    Rectangle {
      id: chrome
      anchors.fill: parent
      color: Qt.rgba(dockWindow.screenFill.r, dockWindow.screenFill.g, dockWindow.screenFill.b, dockWindow.screenLook.bgOpacity / 100)
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
      border.width: 1
      topLeftRadius: Style.space(10)
      topRightRadius: Style.space(10)
      bottomLeftRadius: Style.space(10)
      bottomRightRadius: Style.space(10)

      WheelHandler {
        // Grab wheel over the whole chrome, including over icon MouseAreas.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
        onWheel: function(event) { root.handleDockWheel(event, dockWindow.screenWorkspaceId) }
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
          var edge = root.edgeFromDrag(dockWindow.screenEdge, dragX0, dragY0, dragX1, dragY1, dragW, dragH)
          root.showEdgeHint(dockWindow.screen, dragX1, dragY1, edge)
        }

        onEntered: {
          if (!dockWindow.screenShowTips) return
          var g = root.globalFromPanel(dockWindow, mouseX, 0)
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
          root.armReveal(dockWindow.screen)
          root.showEdgeHint(dockWindow.screen, pt.x, pt.y, dockWindow.screenEdge)
          mouse.accepted = true
        }
        onPositionChanged: function(mouse) {
          if (edgeDrag && (mouse.buttons & Qt.LeftButton)) {
            trackEdge(mouse.x, mouse.y)
            return
          }
          if (!containsMouse || !dockWindow.screenShowTips || root.dragging || root.barEdgeDragging || root.menuOpen) return
          var g = root.globalFromPanel(dockWindow, mouse.x, mouse.y)
          root.refreshIconTipPosition(dockWindow.screen, g.x, g.y)
          if (root.tipVisible && root.tipText === root.blankBarTip) return
          if (!root.tipVisible && tipDelay.running && root.tipText === root.blankBarTip) return
          root.showIconTip(dockWindow.screen, g.x, g.y, root.blankBarTip)
        }
        onReleased: function(mouse) {
          if (!edgeDrag) return
          trackEdge(mouse.x, mouse.y)
          edgeDrag = false
          var edge = dockWindow.screenEdge
          if (dragW > 1 && dragH > 1)
            edge = root.edgeFromDrag(dockWindow.screenEdge, dragX0, dragY0, dragX1, dragY1, dragW, dragH)
          root.barEdgeDragging = false
          root.setBarEdge(edge, dockWindow.screen)
          root.hideIconTip()
        }
        onExited: {
          if (root.tipText === root.blankBarTip)
            root.hideIconTip()
        }
        onClicked: function(mouse) {
          if (mouse.button !== Qt.RightButton) return
          root.hideIconTip()
          var target = dockRow.sectionAt(mouse.x, mouse.y)
          root.menuSectionIndex = target ? Number(target.section) : -1
          var g = root.globalFromPanel(dockWindow, mouse.x, mouse.y)
          root.openDockMenu(dockWindow.screen, g.x, g.y)
        }
        onWheel: function(wheel) { root.handleDockWheel(wheel, dockWindow.screenWorkspaceId) }
      }

      Text {
        visible: dockWindow.layoutEmpty && DockModel.groupCount(dockWindow.screenLayout) === 0
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "Right click to start customization"
        color: root.ink
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      GlobalToggle {
        visible: DockModel.groupCount(dockWindow.screenLayout) === 0
        z: 5
        slot: dockWindow.screenIconSlot
        upright: !dockWindow.verticalBar
        screen: dockWindow.screen
        panel: dockWindow
        chromeItem: chrome
        x: upright ? parent.width - width - Style.space(10) : (parent.width - width) / 2
        y: upright ? (parent.height - height) / 2 : parent.height - height - Style.space(6)
      }

      Item {
        id: dockRow
        visible: DockModel.groupCount(dockWindow.screenLayout) > 0
        anchors.fill: parent
        anchors.leftMargin: vertical ? root.sideInset : Style.space(10)
        anchors.rightMargin: vertical ? root.sideInset : Style.space(10)
        anchors.topMargin: vertical ? Style.space(6) : root.sideInset
        anchors.bottomMargin: vertical ? Style.space(6) : root.sideInset

        readonly property bool vertical: dockWindow.screenEdge !== "bottom"
        readonly property int sectionGap: Style.space(4)
        readonly property var sectionModels: {
          var layout = dockWindow.screenLayout
          return layout && layout.sections ? layout.sections : []
        }

        function sectionByIndex(index) {
          return sectionRepeater.itemAt(index)
        }

        function sectionAt(chromeX, chromeY) {
          function hit(sectionItem, name) {
            if (!sectionItem) return null
            var p = sectionItem.mapFromItem(chrome, chromeX, chromeY)
            var padX = root.dragging ? Style.space(10) : 0
            var padY = root.dragging ? Style.space(8) : 0
            if (p.x >= -padX && p.x <= sectionItem.width + padX
                && p.y >= -padY && p.y <= sectionItem.height + padY) {
              var along = dockRow.vertical ? p.y : p.x
              var idx = sectionItem.indexAt(along)
              var count = sectionItem.model ? sectionItem.model.length : 0
              if (idx < 0) idx = 0
              if (idx > count) idx = count
              return { section: name, index: idx }
            }
            return null
          }

          var count = sectionRepeater.count
          for (var h = 0; h < count; h++) {
            var direct = hit(sectionByIndex(h), String(h))
            if (direct) return direct
          }

          var along = dockRow.vertical ? chromeY : chromeX
          var best = null
          var bestDist = 1e9
          for (var i = 0; i < count; i++) {
            var sec = sectionByIndex(i)
            if (!sec) continue
            var origin = sec.mapToItem(chrome, 0, 0)
            var start = dockRow.vertical ? origin.y : origin.x
            var span = dockRow.vertical ? sec.height : sec.width
            if (span <= 0) continue
            var end = start + span
            var dist = along < start ? start - along : along > end ? along - end : 0
            if (dist >= bestDist) continue
            bestDist = dist
            var icons = sec.model ? sec.model.length : 0
            var idx = along > end ? icons : 0
            best = { section: String(i), index: idx }
          }
          if (best) return best
          return count ? { section: "0", index: 0 } : null
        }

        function packedStart(sectionItem) {
          var pos = 0
          var placed = false
          var count = sectionRepeater.count
          for (var i = 0; i < count; i++) {
            var sec = sectionByIndex(i)
            if (!sec) continue
            var span = dockRow.vertical ? sec.implicitHeight : sec.implicitWidth
            if (sec === sectionItem)
              return pos
            if (span <= 0) continue
            pos += span
            placed = true
          }
          return pos
        }

        function globeStart() {
          var count = sectionRepeater.count
          if (!count) return 0
          var last = sectionByIndex(count - 1)
          if (!last) return 0
          var pos = packedStart(last)
          var span = dockRow.vertical ? last.implicitHeight : last.implicitWidth
          return pos + span
        }

        function trackDragAt(chromeX, chromeY) {
          root.updateIconDragGhost(chromeX, chromeY)
          var target = sectionAt(chromeX, chromeY)
          if (target) root.setIconDropTarget(target.section, target.index)
        }

        Repeater {
          id: sectionRepeater
          model: dockRow.sectionModels
          delegate: DockSection {
            id: sectionItem
            required property var modelData
            required property int index
            sectionName: String(index)
            sectionIndex: index
            sectionCount: sectionRepeater.count
            leadGap: index > 0 ? dockWindow.screenGroupGap : 0
            sectionSpan: {
              var _tick = root.resizePreviewTick
              var live = root.layoutForWorkspaceKey(dockWindow.screenWorkspaceId)
              var sections = live && live.sections ? live.sections : null
              var sec = sections ? sections[index] : null
              if (sec) return Math.max(0, Math.round(Number(sec.span) || 0))
              return Math.max(0, Math.round(Number(modelData.span) || 0))
            }
            x: dockRow.vertical ? (parent.width - width) / 2 : dockRow.packedStart(sectionItem)
            y: dockRow.vertical ? dockRow.packedStart(sectionItem) : (parent.height - height) / 2
            width: implicitWidth
            height: implicitHeight
            model: modelData.items || []
            hostScreen: dockWindow.screen
            panelWindow: dockWindow
            chromeItem: chrome
            trackDrag: dockRow.trackDragAt
            barEdge: dockWindow.screenEdge
            iconSlot: dockWindow.screenIconSlot
            keybindSlot: dockWindow.screenKeybindSlot
          }
        }

        GlobalToggle {
          z: 5
          canResize: true
          slot: dockWindow.screenIconSlot
          upright: !dockRow.vertical
          screen: dockWindow.screen
          panel: dockWindow
          chromeItem: chrome
          x: dockRow.vertical ? (parent.width - width) / 2 : dockRow.globeStart()
          y: dockRow.vertical ? dockRow.globeStart() : (parent.height - height) / 2
        }
      }

      // Drag ghost + insert marker overlay. One per monitor, so the
      // shared drag state has to be limited to the screen that started it.
      Item {
        anchors.fill: parent
        visible: root.dragging && root.dragScreenName.length > 0 && (dockWindow.outputName === root.dragScreenName || root.screenNameOf(dockWindow.screen) === root.dragScreenName)
        z: 100

        // Drop insert caret in the active section
        Rectangle {
          id: insertCaret
          visible: root.dropSection !== ""
          readonly property bool verticalBar: dockWindow.screenEdge !== "bottom"
          readonly property var sectionItem: dockRow.sectionByIndex(Number(root.dropSection))
          readonly property real along: {
            var local = sectionItem ? sectionItem.offsetOf(root.dropIndex) - 1 : 0
            if (!sectionItem) return 0
            var mapped = verticalBar
              ? mapFromItem(sectionItem, 0, local)
              : mapFromItem(sectionItem, local, 0)
            return verticalBar ? mapped.y : mapped.x
          }
          width: verticalBar ? dockWindow.screenIconSlot : 2
          height: verticalBar ? 2 : dockWindow.screenIconSlot
          radius: 1
          color: root.ink
          opacity: 0.85
          x: verticalBar ? (sectionItem ? mapFromItem(sectionItem, 0, 0).x : 0) : along
          y: verticalBar ? along : (parent.height - height) / 2
        }

        Rectangle {
          id: dragGhost
          width: root.dragGhostBadge.length && dockWindow.screenEdge === "bottom" ? dockWindow.screenKeybindSlot : dockWindow.screenIconSlot
          height: root.dragGhostBadge.length && dockWindow.screenEdge !== "bottom" ? dockWindow.screenKeybindSlot : dockWindow.screenIconSlot
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
            text: dockWindow.screenEdge === "bottom" ? root.dragGhostBadge : root.dragGhostBadge.split("").join("\n")
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            color: root.ink
            font.family: Style.font.menuFamily
            font.pixelSize: Math.max(10, Math.round(dockWindow.screenIconSlot * 0.34))
            font.bold: true
          }

          Image {
            visible: root.dragGhostBadge.length === 0
            anchors.centerIn: parent
            width: dockWindow.screenIconSlot - Style.space(2)
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
            width: dockWindow.screenIconSlot - Style.space(2)
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

  component GlobalToggle: Item {
    id: toggleRoot
    property int slot: root.iconSlot
    property bool upright: true
    property var screen: null
    property var panel: null
    property Item chromeItem: null
    property bool canResize: false
    readonly property color ink: root.globalChanges ? "#39FF14" : "#FF3131"
    readonly property color barColor: panel && panel.screenFill ? panel.screenFill : root.barFill
    readonly property int gap: Style.space(8)
    readonly property int rule: Math.max(2, Math.round(Style.space(1)))
    readonly property int ruleLength: Math.round(slot * 0.72)
    readonly property int gearGap: Style.space(6)
    implicitWidth: upright ? gap + rule + gap + slot + gearGap + slot : slot
    implicitHeight: upright ? slot : gap + rule + gap + slot + gearGap + slot

    Item {
      id: tailRule
      z: 2
      width: toggleRoot.upright ? toggleRoot.gap + toggleRoot.rule + toggleRoot.gap : parent.width
      height: toggleRoot.upright ? parent.height : toggleRoot.gap + toggleRoot.rule + toggleRoot.gap

      Rectangle {
        anchors.centerIn: parent
        color: root.activeBorder
        radius: width < height ? width / 2 : height / 2
        width: toggleRoot.upright ? toggleRoot.rule : toggleRoot.ruleLength
        height: toggleRoot.upright ? toggleRoot.ruleLength : toggleRoot.rule
      }

      MouseArea {
        anchors.fill: parent
        enabled: toggleRoot.canResize
        hoverEnabled: true
        cursorShape: toggleRoot.upright ? Qt.SizeHorCursor : Qt.SizeVerCursor
        acceptedButtons: Qt.LeftButton
        onPressed: function(mouse) {
          root.superDown = (mouse.modifiers & Qt.MetaModifier) !== 0
          if (!toggleRoot.chromeItem) return
          var mapped = mapToItem(toggleRoot.chromeItem, mouse.x, mouse.y)
          root.beginTailResize(toggleRoot.panel, toggleRoot.upright ? mapped.x : mapped.y)
          mouse.accepted = true
        }
        onPositionChanged: function(mouse) {
          var superHeld = (mouse.modifiers & Qt.MetaModifier) !== 0
          root.superDown = superHeld
          if (!toggleRoot.chromeItem) return
          var mapped = mapToItem(toggleRoot.chromeItem, mouse.x, mouse.y)
          var along = toggleRoot.upright ? mapped.x : mapped.y
          if (!(pressed || superHeld)) {
            if (root.resizeTail) root.endSectionResize()
            return
          }
          if (!root.resizeTail)
            root.beginTailResize(toggleRoot.panel, along)
          else
            root.updateSectionResize(toggleRoot.panel, along)
        }
        onExited: if (!pressed && root.resizeTail) root.endSectionResize()
        onReleased: function(mouse) {
          root.superDown = (mouse.modifiers & Qt.MetaModifier) !== 0
          if (!root.superDown) root.endSectionResize()
        }
        onCanceled: if (root.resizeTail) root.endSectionResize()
      }
    }

    Item {
      id: globeHit
      x: toggleRoot.upright ? toggleRoot.gap + toggleRoot.rule + toggleRoot.gap : 0
      y: toggleRoot.upright ? 0 : toggleRoot.gap + toggleRoot.rule + toggleRoot.gap
      width: toggleRoot.slot
      height: toggleRoot.slot

      Canvas {
        id: globeMark
        anchors.centerIn: parent
        width: parent.width - Style.space(2)
        height: width
        onPaint: {
          var ctx = getContext("2d")
          var w = width
          var h = height
          ctx.clearRect(0, 0, w, h)
          ctx.fillStyle = toggleRoot.ink
          var d = "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"
          var tokens = []
          var re = /[MmLlHhVvCcSsZz]|-?\d*\.?\d+/g
          var found = d.match(re) || []
          for (var t = 0; t < found.length; t++) tokens.push(found[t])
          var scale = Math.min(w, h) / 24
          var ox = (w - 24 * scale) / 2
          var oy = (h - 24 * scale) / 2
          function px(v) { return ox + v * scale }
          function py(v) { return oy + v * scale }
          var i = 0
          var cx = 0
          var cy = 0
          var sx = 0
          var sy = 0
          var prev = ""
          var cpx = 0
          var cpy = 0
          function num() { return parseFloat(tokens[i++]) }
          function isCmd(tok) { return tok && tok.length === 1 && tok >= "A" && tok <= "z" }
          ctx.beginPath()
          while (i < tokens.length) {
            var cmd = isCmd(tokens[i]) ? tokens[i++] : prev
            if (cmd === "M" || cmd === "m") {
              var mx = num()
              var my = num()
              if (cmd === "m") { mx += cx; my += cy }
              ctx.moveTo(px(mx), py(my))
              cx = mx; cy = my; sx = mx; sy = my
              prev = cmd === "m" ? "l" : "L"
            } else if (cmd === "L" || cmd === "l") {
              var lx = num()
              var ly = num()
              if (cmd === "l") { lx += cx; ly += cy }
              ctx.lineTo(px(lx), py(ly))
              cx = lx; cy = ly; prev = cmd
            } else if (cmd === "H" || cmd === "h") {
              var hx = num()
              if (cmd === "h") hx += cx
              ctx.lineTo(px(hx), py(cy))
              cx = hx; prev = cmd
            } else if (cmd === "V" || cmd === "v") {
              var hy = num()
              if (cmd === "v") hy += cy
              ctx.lineTo(px(cx), py(hy))
              cy = hy; prev = cmd
            } else if (cmd === "C" || cmd === "c") {
              var c1x = num(), c1y = num(), c2x = num(), c2y = num(), ex = num(), ey = num()
              if (cmd === "c") {
                c1x += cx; c1y += cy; c2x += cx; c2y += cy; ex += cx; ey += cy
              }
              ctx.bezierCurveTo(px(c1x), py(c1y), px(c2x), py(c2y), px(ex), py(ey))
              cpx = c2x; cpy = c2y; cx = ex; cy = ey; prev = cmd
            } else if (cmd === "S" || cmd === "s") {
              var s2x = num(), s2y = num(), sex = num(), sey = num()
              var s1x = cx
              var s1y = cy
              if (prev === "C" || prev === "c" || prev === "S" || prev === "s") {
                s1x = 2 * cx - cpx
                s1y = 2 * cy - cpy
              }
              if (cmd === "s") { s2x += cx; s2y += cy; sex += cx; sey += cy }
              ctx.bezierCurveTo(px(s1x), py(s1y), px(s2x), py(s2y), px(sex), py(sey))
              cpx = s2x; cpy = s2y; cx = sex; cy = sey; prev = cmd
            } else if (cmd === "Z" || cmd === "z") {
              ctx.closePath()
              cx = sx; cy = sy; prev = cmd
            } else {
              break
            }
          }
          ctx.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
          target: toggleRoot
          function onInkChanged() { globeMark.requestPaint() }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        function showGlobeTip() {
          if (!toggleRoot.panel || !toggleRoot.chromeItem) return
          var p = mapToItem(toggleRoot.chromeItem, width / 2, 0)
          var g = root.globalFromPanel(toggleRoot.panel, p.x, p.y)
          var label = root.globalChanges ? "Global changes" : "Local changes"
          root.showIconTip(toggleRoot.screen, g.x, g.y, label)
        }
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) {
            if (!toggleRoot.panel || !toggleRoot.chromeItem) return
            var p = mapToItem(toggleRoot.chromeItem, mouse.x, mouse.y)
            var g = root.globalFromPanel(toggleRoot.panel, p.x, p.y)
            root.openDockMenu(toggleRoot.screen, g.x, g.y)
            return
          }
          root.toggleGlobalChanges()
          showGlobeTip()
        }
        onEntered: showGlobeTip()
        onExited: root.hideIconTip()
      }
    }

    Item {
      id: gearHit
      x: globeHit.x + (toggleRoot.upright ? toggleRoot.slot + toggleRoot.gearGap : 0)
      y: globeHit.y + (toggleRoot.upright ? 0 : toggleRoot.slot + toggleRoot.gearGap)
      width: toggleRoot.slot
      height: toggleRoot.slot

      Rectangle {
        anchors.fill: parent
        anchors.margins: gearMouse.containsMouse ? 0 : 1
        radius: Style.space(8)
        color: gearMouse.containsMouse
          ? Qt.rgba(toggleRoot.barColor.r, toggleRoot.barColor.g, toggleRoot.barColor.b, 0.55)
          : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
      }

      Canvas {
        id: gearMark
        anchors.centerIn: parent
        width: parent.width - Style.space(4)
        height: width
        property color ink: gearMouse.containsMouse
          ? root.lighterTones(toggleRoot.barColor, 5)
          : root.lighterTones(toggleRoot.barColor, 3)
        onPaint: {
          var ctx = getContext("2d")
          var w = width
          var h = height
          ctx.clearRect(0, 0, w, h)
          ctx.fillStyle = gearMark.ink
          ctx.strokeStyle = gearMark.ink
          var cx = w / 2
          var cy = h / 2
          ctx.lineWidth = Math.max(2, w * 0.14)
          ctx.beginPath()
          ctx.arc(cx, cy, w * 0.26, 0, Math.PI * 2)
          ctx.stroke()
          for (var tooth = 0; tooth < 8; tooth++) {
            ctx.save()
            ctx.translate(cx, cy)
            ctx.rotate(tooth * Math.PI / 4)
            ctx.fillRect(-w * 0.07, -w * 0.48, w * 0.14, w * 0.18)
            ctx.restore()
          }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onInkChanged: requestPaint()
      }

      MouseArea {
        id: gearMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (!toggleRoot.panel || !toggleRoot.chromeItem) return
          root.menuSectionIndex = -1
          root.confirmRemoveOpen = false
          var p = mapToItem(toggleRoot.chromeItem, width / 2, height / 2)
          var g = root.globalFromPanel(toggleRoot.panel, p.x, p.y)
          root.openDockMenu(toggleRoot.screen, g.x, g.y)
        }
        onEntered: {
          gearMark.requestPaint()
          if (!toggleRoot.panel || !toggleRoot.chromeItem) return
          var p = mapToItem(toggleRoot.chromeItem, width / 2, 0)
          var g = root.globalFromPanel(toggleRoot.panel, p.x, p.y)
          root.showIconTip(toggleRoot.screen, g.x, g.y, "Task bar settings")
        }
        onExited: {
          gearMark.requestPaint()
          root.hideIconTip()
        }
      }
    }
  }

  component DockSection: Item {
    id: sectionRoot
    property string sectionName: "center"
    property int sectionIndex: 0
    property int sectionCount: 1
    property var model: []
    property var hostScreen: null
    property var panelWindow: null
    property Item chromeItem: null
    property var trackDrag: null
    property string barEdge: root.barEdge
    property int iconSlot: root.iconSlot
    property int keybindSlot: root.keybindSlot
    readonly property bool vertical: barEdge !== "bottom"
    readonly property int iconCount: model ? model.length : 0
    // Shared with the other two groups. Icons are centered in every section.
    property int sectionSpan: 0
    property int leadGap: 0

    function spanOf(item) {
      return item && String(item.kind || "") === "keybind" ? sectionRoot.keybindSlot : sectionRoot.iconSlot
    }

    function contentSpan() {
      var items = model || []
      if (!items.length)
        return root.dragging ? iconSlot : 0
      var gap = Style.space(4)
      var total = 0
      for (var i = 0; i < items.length; i++)
        total += spanOf(items[i])
      if (items.length > 1)
        total += gap * (items.length - 1)
      return Math.max(total, root.dragging ? iconSlot : 0)
    }

    function contentOrigin() {
      var along = vertical ? height : width
      var room = Math.max(0, along - leadGap)
      var content = contentSpan()
      return leadGap + Math.max(0, (room - content) / 2)
    }

    function offsetOf(index) {
      var items = model || []
      var gap = Style.space(4)
      var pos = contentOrigin()
      var n = Math.min(Math.max(0, index), items.length)
      for (var i = 0; i < n; i++)
        pos += spanOf(items[i]) + gap
      return pos
    }

    function indexAt(along) {
      var items = model || []
      var gap = Style.space(4)
      var pos = 0
      var local = along - contentOrigin()
      for (var i = 0; i < items.length; i++) {
        var span = spanOf(items[i])
        if (local < pos + span / 2)
          return i
        pos += span + gap
      }
      return items.length
    }

    implicitWidth: {
      var _m = model
      var _span = sectionSpan
      var _lead = leadGap
      return vertical ? sectionRoot.iconSlot : _lead + Math.max(_span, contentSpan())
    }
    implicitHeight: {
      var _m = model
      var _span = sectionSpan
      var _lead = leadGap
      return vertical ? _lead + Math.max(_span, contentSpan()) : sectionRoot.iconSlot
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      visible: root.dragging && root.dropSection === sectionRoot.sectionName && root.dragScreenName === root.screenNameOf(sectionRoot.hostScreen)
      color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
    }

    Item {
      // Stay under the icons. The count comes from the icon repeater so the
      // mark disappears as soon as a delegate exists, not from a stale length.
      visible: sectionIcons.count === 0
      enabled: false
      z: 0
      x: sectionRoot.vertical ? 0 : sectionRoot.leadGap
      y: sectionRoot.vertical ? sectionRoot.leadGap : 0
      width: sectionRoot.vertical ? parent.width : Math.max(0, parent.width - sectionRoot.leadGap)
      height: sectionRoot.vertical ? Math.max(0, parent.height - sectionRoot.leadGap) : parent.height

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: (sectionRoot.sectionIndex + 1) + "/" + Math.max(1, sectionRoot.sectionCount)
        color: root.darkerTones(sectionRoot.panelWindow && sectionRoot.panelWindow.screenFill ? sectionRoot.panelWindow.screenFill : root.barFill, 5)
        font.family: Style.font.family
        font.pixelSize: Math.max(10, Math.round(sectionRoot.iconSlot * 0.42)) + 1
        font.bold: false
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    Item {
      id: sectionRule
      visible: Number(sectionRoot.sectionName) > 0
      z: 8
      readonly property int boundary: Number(sectionRoot.sectionName) - 1
      readonly property int gap: sectionRoot.leadGap
      x: 0
      y: 0
      width: sectionRoot.vertical ? parent.width : gap
      height: sectionRoot.vertical ? gap : parent.height

      Rectangle {
        anchors.centerIn: parent
        color: root.activeBorder
        radius: width < height ? width / 2 : height / 2
        width: sectionRoot.vertical ? Math.round(sectionRoot.iconSlot * 0.72) : Math.max(2, Style.space(1))
        height: sectionRoot.vertical ? Math.max(2, Style.space(1)) : Math.round(sectionRoot.iconSlot * 0.72)
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: sectionRoot.vertical ? Qt.SizeVerCursor : Qt.SizeHorCursor
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        onPressed: function(mouse) {
          root.resizeButtonDown = true
          root.superDown = (mouse.modifiers & Qt.MetaModifier) !== 0
          var mapped = mapToItem(sectionRoot.chromeItem, mouse.x, mouse.y)
          var along = sectionRoot.vertical ? mapped.y : mapped.x
          root.beginSectionResize(sectionRoot.panelWindow, sectionRule.boundary, along)
          mouse.accepted = true
        }
        onPositionChanged: function(mouse) {
          var superHeld = (mouse.modifiers & Qt.MetaModifier) !== 0
          root.superDown = superHeld
          var buttonDown = root.resizeButtonDown || ((mouse.buttons & Qt.LeftButton) !== 0)
          if (!sectionRoot.chromeItem) return
          var mapped = mapToItem(sectionRoot.chromeItem, mouse.x, mouse.y)
          var along = sectionRoot.vertical ? mapped.y : mapped.x
          if (!(buttonDown || superHeld)) {
            if (!root.resizeTail && root.resizeBoundaryIndex === sectionRule.boundary)
              root.endSectionResize()
            return
          }
          if (root.resizeTail) return
          if (root.resizeBoundaryIndex < 0)
            root.beginSectionResize(sectionRoot.panelWindow, sectionRule.boundary, along)
          else if (root.resizeBoundaryIndex === sectionRule.boundary)
            root.updateSectionResize(sectionRoot.panelWindow, along)
        }
        onReleased: function(mouse) {
          root.resizeButtonDown = false
          root.superDown = (mouse.modifiers & Qt.MetaModifier) !== 0
          if (!root.superDown && !root.resizeTail && root.resizeBoundaryIndex === sectionRule.boundary)
            root.endSectionResize()
        }
        onCanceled: {
          root.resizeButtonDown = false
          if (!root.resizeTail && root.resizeBoundaryIndex === sectionRule.boundary)
            root.endSectionResize()
        }
      }
    }

    Item {
      id: sectionRow
      z: 2
      anchors.fill: parent

      Repeater {
        id: sectionIcons
        model: sectionRoot.model
        delegate: Item {
          id: iconWrap
          required property var modelData
          required property int index
          readonly property bool keybindIcon: String(modelData.kind || "") === "keybind"
          x: {
            var _m = sectionRoot.model
            return sectionRoot.vertical ? 0 : sectionRoot.offsetOf(index)
          }
          y: {
            var _m = sectionRoot.model
            return sectionRoot.vertical ? sectionRoot.offsetOf(index) : 0
          }
          width: keybindIcon && sectionRoot.barEdge === "bottom" ? sectionRoot.keybindSlot : sectionRoot.iconSlot
          height: keybindIcon && sectionRoot.barEdge !== "bottom" ? sectionRoot.keybindSlot : sectionRoot.iconSlot
          opacity: root.dragging && root.dragScreenName === root.screenNameOf(sectionRoot.hostScreen) && root.dragItem && root.dragItem.id === modelData.id ? 0.35 : 1

          Item {
            id: iconMotion
            anchors.fill: parent
            readonly property bool hot: iconMouse.containsMouse && !root.dragging

            Rectangle {
              id: hoverBg
              anchors.fill: parent
              anchors.margins: iconMotion.hot ? 0 : 1
              radius: Style.space(8)
              color: iconMotion.hot
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
                : "transparent"

              Behavior on color { ColorAnimation { duration: 140 } }
              Behavior on anchors.margins { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Item {
              id: iconClip
              anchors.centerIn: parent
              width: sectionRoot.iconSlot - Style.space(2)
              height: width
              layer.enabled: cornerProbe.sharp
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: iconRoundMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.18
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
              readonly property bool hot: iconMotion.hot
              visible: iconWrap.keybindIcon
              anchors.centerIn: parent
              width: parent.width - Style.space(2)
              height: parent.height - Style.space(2)
              radius: Style.space(8)
              color: hot ? root.surface : root.ink
              border.width: 0

              Behavior on color { ColorAnimation { duration: 140 } }

              Text {
                readonly property bool upright: sectionRoot.barEdge !== "bottom"
                readonly property string letters: String(iconWrap.modelData.badge || "").slice(0, 3)
                anchors.fill: parent
                anchors.leftMargin: upright ? Style.space(2) : (keybindBadge.width > sectionRoot.iconSlot ? Style.space(7) : Style.space(3))
                anchors.rightMargin: anchors.leftMargin
                anchors.topMargin: upright ? Style.space(3) : 0
                anchors.bottomMargin: upright ? Style.space(3) : 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: upright ? letters.split("").join("\n") : letters
                textFormat: Text.PlainText
                color: keybindBadge.hot ? root.ink : root.surface
                font.family: Style.font.menuFamily
                font.pixelSize: {
                  var n = 3
                  var cap = Math.max(12, Math.round(sectionRoot.iconSlot * 0.42))
                  if (!upright) {
                    var pad = keybindBadge.width > sectionRoot.iconSlot ? Style.space(14) : Style.space(6)
                    var inner = Math.max(8, keybindBadge.width - pad)
                    var fitted = Math.floor(inner / (n * 0.68))
                    var byHeight = Math.floor(keybindBadge.height * 0.62)
                    return Math.max(8, Math.min(cap, byHeight, fitted))
                  }
                  var innerW = Math.max(8, keybindBadge.width - Style.space(4))
                  var innerH = Math.max(8, keybindBadge.height - Style.space(6))
                  var byWidth = Math.floor(innerW * 0.78)
                  var byStack = Math.floor(innerH / n * 0.9)
                  return Math.max(8, Math.min(cap, byWidth, byStack))
                }
                font.bold: true
                lineHeightMode: Text.ProportionalHeight
                lineHeight: upright ? 0.9 : 1
                elide: upright ? Text.ElideNone : Text.ElideRight

                Behavior on color { ColorAnimation { duration: 120 } }
              }
            }

            // Faint white frame. On hover it becomes the Omarchy active-window
            // border (cyan into green at 45 degrees) with a soft halo.
            Rectangle {
              id: iconRim
              anchors.fill: iconWrap.keybindIcon ? keybindBadge : iconClip
              readonly property real corner: iconWrap.keybindIcon
                ? Style.space(8)
                : Math.max(4, Math.round(Math.min(width, height) * 0.22))
              radius: corner
              color: "transparent"
              border.width: 1
              border.color: Qt.rgba(1, 1, 1, 0.62)
              opacity: iconMotion.hot ? 0 : 1
              z: 4

              Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            Canvas {
              id: activeRim
              anchors.fill: iconWrap.keybindIcon ? keybindBadge : iconClip
              anchors.margins: -2
              opacity: iconMotion.hot ? 1 : 0
              visible: opacity > 0
              z: 5

              Behavior on opacity { NumberAnimation { duration: 140 } }

              function trace(ctx, inset) {
                var r = Math.max(2, iconRim.corner - inset * 0.2)
                var x = inset
                var y = inset
                var w = width - inset * 2
                var h = height - inset * 2
                ctx.beginPath()
                ctx.moveTo(x + r, y)
                ctx.lineTo(x + w - r, y)
                ctx.arcTo(x + w, y, x + w, y + r, r)
                ctx.lineTo(x + w, y + h - r)
                ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                ctx.lineTo(x + r, y + h)
                ctx.arcTo(x, y + h, x, y + h - r, r)
                ctx.lineTo(x, y + r)
                ctx.arcTo(x, y, x + r, y, r)
                ctx.closePath()
              }

              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()
              onVisibleChanged: if (visible) requestPaint()
              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                // Soft halo, then the 45-degree active-window stroke.
                trace(ctx, 2.5)
                ctx.lineWidth = 4
                ctx.strokeStyle = "rgba(51, 204, 255, 0.35)"
                ctx.shadowColor = "rgba(51, 204, 255, 0.9)"
                ctx.shadowBlur = 3
                ctx.stroke()
                trace(ctx, 2.5)
                var g = ctx.createLinearGradient(0, 0, width, height)
                g.addColorStop(0, "rgba(51, 204, 255, 0.95)")
                g.addColorStop(1, "rgba(0, 255, 153, 0.95)")
                ctx.shadowBlur = 0
                ctx.lineWidth = 1.5
                ctx.strokeStyle = g
                ctx.stroke()
              }
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
            visible: running
            z: 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            readonly property real iconBottom: iconWrap.keybindIcon
              ? Math.max(0, iconWrap.width - Style.space(2))
              : Math.max(0, sectionRoot.iconSlot - Style.space(2))
            width: iconBottom * 0.85
            height: Math.max(3, Math.round(sectionRoot.iconSlot * 0.12))
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

            function pointerGlobal(localX, localY) {
              var host = sectionRoot.chromeItem || iconWrap
              var p = iconWrap.mapToItem(host, localX, localY)
              return root.globalFromPanel(sectionRoot.panelWindow, p.x, p.y)
            }

            onEntered: {
              hoverX = width / 2
              hoverY = height / 2
              var g = pointerGlobal(hoverX, 0)
              root.showItemIconTip(sectionRoot.hostScreen, g.x, g.y, iconWrap.modelData)
            }
            onExited: {
              if (root.tipText === DockModel.itemLabel(iconWrap.modelData))
                root.hideIconTip()
            }
            onPositionChanged: function(mouse) {
              hoverX = mouse.x
              hoverY = mouse.y
              var g = pointerGlobal(mouse.x, mouse.y)
              if (iconMouse.containsMouse && !root.dragging && !root.menuOpen) {
                root.refreshIconTipPosition(sectionRoot.hostScreen, g.x, g.y)
                if (!root.tipVisible && !tipDelay.running)
                  root.showItemIconTip(sectionRoot.hostScreen, g.x, g.y, iconWrap.modelData)
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
                var g = pointerGlobal(mouse.x, mouse.y)
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
            onWheel: function(wheel) {
              var panel = sectionRoot.panelWindow
              root.handleDockWheel(wheel, panel ? panel.screenWorkspaceId : "")
            }
          }
        }
      }
    }
  }

  component TipPanel: PanelWindow {
    id: tipWindow
    readonly property bool forScreen: root.tipScreen === tipWindow.screen
    readonly property var tipLook: {
      var _looks = root.workspaceLooks
      var _def = root.defaultLook
      var _screen = root.tipScreen
      return root.lookFor(root.workspaceIdForScreen(_screen))
    }
    readonly property var tipMetrics: root.metricsForLook(tipLook)
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
      readonly property int tipCount: {
        var _gen = root.liveClientGen
        var _rev = root.toplevelRevision
        if (!root.tipItem) return 0
        return root.itemRunningCount(root.tipItem, root.tipItemScreen, _gen)
      }
      width: tipLabel.implicitWidth + (tipCountLabel.visible ? tipCountLabel.implicitWidth + Style.space(6) : 0) + tipPadX
      height: Math.max(Style.space(28), Math.max(tipLabel.implicitHeight, tipCountLabel.implicitHeight) + tipPadY)
      radius: Style.cornerRadius
      color: Color.tooltip.background
      border.color: Color.tooltip.border
      border.width: Math.max(1, Style.normalBorderWidth)
      x: {
        var left = root.tipX - width / 2
        if (!root.barEdgeDragging && tipWindow.tipMetrics.barEdge === "left")
          left = tipWindow.tipMetrics.barCross + Style.space(10)
        else if (!root.barEdgeDragging && tipWindow.tipMetrics.barEdge === "right")
          left = parent.width - tipWindow.tipMetrics.barCross - width - Style.space(10)
        return Math.min(Math.max(Style.space(4), left), parent.width - width - Style.space(4))
      }
      y: {
        var top = root.tipY - height - Style.space(8)
        if (!root.barEdgeDragging && tipWindow.tipMetrics.barEdge !== "bottom")
          top = root.tipY - height / 2
        return Math.min(Math.max(Style.space(4), top), parent.height - height - Style.space(4))
      }

      Row {
        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
          id: tipLabel
          textFormat: Text.PlainText
          text: root.tipText
          color: Color.tooltip.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          verticalAlignment: Text.AlignVCenter
        }

        Text {
          id: tipCountLabel
          visible: tipCard.tipCount > 0
          textFormat: Text.PlainText
          text: "(" + tipCard.tipCount + ")"
          color: Color.tooltip.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          verticalAlignment: Text.AlignVCenter
        }
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

  // Help lines are word pieces so a match can sit on a real yellow rectangle.
  // Text background-color is not painted by this shell.
  component HelpMarkText: Item {
    id: markHost
    property string source: ""
    property var segments: []
    property color textColor: root.menuForeground
    property int pixelSize: Style.font.body
    property bool boldText: false
    property real padTop: 0
    property int hitCursorStart: -1
    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight + padTop
    height: implicitHeight

    function yOfStart(start) {
      for (var i = 0; i < segRepeater.count; i++) {
        var piece = segRepeater.itemAt(i)
        if (piece && piece.segStart === start)
          return padTop + piece.y
      }
      return padTop
    }

    Flow {
      id: flow
      y: markHost.padTop
      width: markHost.width
      spacing: 0

      Repeater {
        id: segRepeater
        model: markHost.segments ? markHost.segments.length : 0
        delegate: Item {
          required property int index
          readonly property var seg: markHost.segments[index]
          property int segStart: seg ? seg.start : -1
          width: label.implicitWidth
          height: Math.max(label.implicitHeight, markHost.pixelSize + 4)

          Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            visible: !!(seg && seg.hit)
            radius: 3
            color: "#FFE56A"
          }

          Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: seg ? seg.text : ""
            textFormat: Text.PlainText
            color: markHost.textColor
            font.family: Style.font.menuFamily
            font.pixelSize: markHost.pixelSize
            font.bold: seg ? !!seg.bold : markHost.boldText
          }
        }
      }
    }
  }

  component MenuPanel: PanelWindow {
    id: menuWindow
    readonly property bool forScreen: root.menuScreen === menuWindow.screen
    readonly property bool itemMenuActive: visible && !!root.menuItem
    readonly property bool titleEditActive: itemMenuActive && root.labelEdit
    readonly property bool barHelpKeys: visible && root.helpOpen && !root.menuItem
    visible: root.menuOpen && forScreen
    focusable: titleEditActive || barHelpKeys
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (titleEditActive || barHelpKeys) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property var menuLook: {
      var _looks = root.workspaceLooks
      var _def = root.defaultLook
      return root.lookFor(root.workspaceIdForScreen(menuWindow.screen))
    }
    readonly property var menuMetrics: root.metricsForLook(menuLook)
    anchors { left: true; right: true; top: true; bottom: true }
    // Leave the dock strip uncovered so icon size, transparency, and
    // background picks stay visible while this menu is open.
    margins.left: menuMetrics.barEdge === "left" ? menuMetrics.barCross : 0
    margins.right: menuMetrics.barEdge === "right" ? menuMetrics.barCross : 0
    margins.bottom: menuMetrics.barEdge === "bottom" ? menuMetrics.barCross : 0

    HyprlandFocusGrab {
      active: menuWindow.titleEditActive || menuWindow.barHelpKeys
      windows: [menuWindow]
    }
    onBarHelpKeysChanged: if (barHelpKeys) Qt.callLater(function() { helpKeyCatcher.forceActiveFocus() })

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
      // Task bar customization keeps a size and position of its own.
      // The icon menu still opens at the pointer and sizes to its rows.
      readonly property real minBarW: Style.space(280)
      readonly property real minBarH: Style.space(240)
      readonly property real minIconW: Style.space(220)
      readonly property real minIconH: Style.space(180)
      readonly property real naturalW: Math.min(Style.space(380), Math.max(minBarW, parent.width - Style.space(24)))
      readonly property real naturalH: Math.min(barSettings.implicitHeight + barMenuTitle.height + contentTopInset + contentBottomInset + Style.space(8), Math.max(minBarH, parent.height - Style.space(16)))
      property real dragPressX: 0
      property real dragPressY: 0
      property real dragOriginX: 0
      property real dragOriginY: 0
      property bool resizing: false
      property real resizePinX: 0
      property real resizePinY: 0
      width: root.menuItem
        ? (root.iconMenuSized ? Math.min(Math.max(minIconW, root.iconMenuW), parent.width - Style.space(16)) : Style.space(260))
        : (root.customMenuSized ? Math.min(Math.max(minBarW, root.customMenuW), parent.width - Style.space(16)) : naturalW)
      height: root.menuItem
        ? (root.iconMenuSized ? Math.min(Math.max(minIconH, root.iconMenuH), parent.height - Style.space(16)) : (menuColumn.implicitHeight + contentTopInset + contentBottomInset))
        : (root.customMenuSized ? Math.min(Math.max(minBarH, root.customMenuH), parent.height - Style.space(16)) : naturalH)
      radius: Style.cornerRadius
      color: root.menuBackground
      borderSpec: root.menuBorderSpec
      padding: Style.space(6)
      function dragPoint(item, lx, ly) {
        return item.mapToItem(parent, lx, ly)
      }
      function dragStart(item, lx, ly) {
        var p = dragPoint(item, lx, ly)
        dragPressX = p.x
        dragPressY = p.y
        dragOriginX = x
        dragOriginY = y
      }
      function dragMove(item, lx, ly) {
        var p = dragPoint(item, lx, ly)
        park(dragOriginX + p.x - dragPressX, dragOriginY + p.y - dragPressY)
      }
      function park(px, py) {
        var margin = Style.space(8)
        var nx = Math.min(Math.max(margin, px), parent.width - width - margin)
        var ny = Math.min(Math.max(margin, py), parent.height - height - margin)
        if (root.menuItem) {
          root.iconMenuX = nx
          root.iconMenuY = ny
          root.iconMenuPlaced = true
        } else {
          root.customMenuX = nx
          root.customMenuY = ny
          root.customMenuPlaced = true
        }
      }
      x: {
        var margin = Style.space(8)
        if (resizing) return resizePinX
        if (root.menuItem && root.iconMenuPlaced)
          return Math.min(Math.max(margin, root.iconMenuX), parent.width - width - margin)
        if (!root.menuItem && root.customMenuPlaced)
          return Math.min(Math.max(margin, root.customMenuX), parent.width - width - margin)
        var left = root.menuX - width / 2
        if (menuWindow.menuMetrics.barEdge === "left")
          left = root.menuX + Style.space(8) - menuWindow.menuMetrics.barCross
        else if (menuWindow.menuMetrics.barEdge === "right")
          left = root.menuX - width - Style.space(8)
        return Math.min(Math.max(margin, left), parent.width - width - margin)
      }
      y: {
        var margin = Style.space(8)
        if (resizing) return resizePinY
        if (root.menuItem && root.iconMenuPlaced)
          return Math.min(Math.max(margin, root.iconMenuY), parent.height - height - margin)
        if (!root.menuItem && root.customMenuPlaced)
          return Math.min(Math.max(margin, root.customMenuY), parent.height - height - margin)
        var top = root.menuY - height - Style.space(10)
        if (menuWindow.menuMetrics.barEdge !== "bottom")
          top = root.menuY - height / 2
        return Math.min(Math.max(margin, top), parent.height - height - margin)
      }

      Column {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: menuCard.contentLeftInset
        anchors.rightMargin: menuCard.contentRightInset
        anchors.topMargin: menuCard.contentTopInset
        height: root.menuItem
          ? (root.iconMenuSized ? Math.max(0, menuCard.height - menuCard.contentTopInset - menuCard.contentBottomInset) : implicitHeight)
          : Math.max(0, menuCard.height - menuCard.contentTopInset - menuCard.contentBottomInset)
        clip: root.menuItem && root.iconMenuSized
        spacing: 2

        // Selected icon identity: same glyph and label as the dock tooltip.
        Item {
          id: itemMenuHeader
          visible: !!root.menuItem
          width: parent.width
          height: visible ? Style.space(44) : 0

          MouseArea {
            z: 3
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: itemMenuInfo.left
            cursorShape: Qt.SizeAllCursor
            preventStealing: true
            enabled: itemMenuHeader.visible && !root.labelEdit
            onPressed: function(mouse) { menuCard.dragStart(this, mouse.x, mouse.y) }
            onPositionChanged: function(mouse) {
              if (!(mouse.buttons & Qt.LeftButton)) return
              menuCard.dragMove(this, mouse.x, mouse.y)
            }
            onReleased: root.persistSettings()
            onDoubleClicked: {
              if (root.menuItem && root.menuItem.kind !== "keybind")
                root.beginLabelEdit()
            }
          }

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
            width: {
              var limit = itemMenuInfo.x - x - Style.space(8)
              var countW = itemMenuCount.visible ? itemMenuCount.implicitWidth + Style.space(6) : 0
              return Math.min(implicitWidth, Math.max(0, limit - countW))
            }
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

          Text {
            id: itemMenuCount
            visible: itemMenuHeaderLabel.visible && itemMenuCountValue > 0
            readonly property int itemMenuCountValue: root.menuItem
              ? root.itemRunningCount(root.menuItem, menuWindow.screen, root.liveClientGen)
              : 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: itemMenuHeaderLabel.right
            anchors.leftMargin: Style.space(6)
            textFormat: Text.PlainText
            text: "(" + itemMenuCountValue + ")"
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

        Item {
          id: barMenuBody
          visible: !root.menuItem
          width: parent.width
          height: visible ? Math.max(0, menuColumn.height) : 0

          Item {
            id: barMenuTitle
            width: parent.width
            height: Style.space(44)

            MouseArea {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.right: barMenuInfo.left
              cursorShape: Qt.SizeAllCursor
              preventStealing: true
              onPressed: function(mouse) { menuCard.dragStart(this, mouse.x, mouse.y) }
              onPositionChanged: function(mouse) {
                if (!(mouse.buttons & Qt.LeftButton)) return
                menuCard.dragMove(this, mouse.x, mouse.y)
              }
              onReleased: root.persistSettings()
            }

            Item {
              id: barMenuTitleIcon
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              width: Style.space(18)
              height: width
              z: 2

              Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: Math.max(7, Math.round(parent.height * 0.46))
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: root.menuForeground
              }

              Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                  model: 3
                  Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: root.menuForeground
                  }
                }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: barMenuTitleIcon.right
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

          Flickable {
            id: barScroll
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: barMenuTitle.bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(16)
            clip: true
            contentWidth: width
            contentHeight: barSettings.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height + 1

            Column {
              id: barSettings
              width: barScroll.width
              spacing: Style.spacing.md

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
            id: placementRadios
            width: parent.width
            height: Math.max(Style.space(24), placementFlow.implicitHeight)

            Text {
              id: placementLabel
              width: Style.space(92)
              height: Style.space(24)
              verticalAlignment: Text.AlignVCenter
              textFormat: Text.PlainText
              text: "Placement"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Flow {
              id: placementFlow
              anchors.left: placementLabel.right
              anchors.leftMargin: Style.spacing.sm
              anchors.right: parent.right
              spacing: Style.space(12)

              Repeater {
                model: root.sectionChoices
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
            Text {
              width: Style.space(44) + 15
              leftPadding: 15
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: DockModel.iconSizePercent(root.iconSize) + "%"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall + 3
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
            Text {
              width: Style.space(44) + 15
              leftPadding: 15
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: DockModel.transparencyPercent(root.bgOpacity) + "%"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall + 3
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

          StatusToggle {
            width: parent.width
            label: "Icon popups"
            checked: root.showTips
            onClicked: root.toggleShowTips()
          }

          StatusToggle {
            width: parent.width
            label: "Auto hide task bar"
            checked: root.autoHide
            onClicked: root.toggleAutoHide()
          }

          BorderSurface {
            id: globalToggle
            width: parent.width
            implicitHeight: globalChecks.y + globalChecks.height + Style.space(8)
            radius: Style.cornerRadius
            color: Style.controlFill(false, globalSwitch.containsMouse, root.menuForeground, Color.accent)
            borderSpec: Border.controlSpec(globalSwitch.containsMouse ? "hover-cursor" : "normal", root.menuForeground, Color.accent)

            Text {
              id: globalLabel
              anchors.left: parent.left
              anchors.leftMargin: Style.space(12)
              anchors.top: parent.top
              anchors.topMargin: Style.space(10)
              textFormat: Text.PlainText
              text: "Global Changes"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Row {
              id: globalChecks
              anchors.left: globalLabel.left
              anchors.top: globalLabel.bottom
              anchors.topMargin: Style.space(4)
              spacing: Style.space(10)
              opacity: root.globalChanges ? 1 : 0.4

              Repeater {
                model: [
                  { key: "icons", label: "Icons" },
                  { key: "sections", label: "Sections" }
                ]
                delegate: Item {
                  required property var modelData
                  readonly property bool on: modelData.key === "icons" ? root.globalIcons : root.globalSections
                  width: globalCheck.implicitWidth
                  height: Style.space(22)

                  Row {
                    id: globalCheck
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(16)
                      height: width
                      radius: Style.space(3)
                      color: "transparent"
                      border.width: 1.5
                      border.color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, on ? 0.9 : 0.45)

                      Text {
                        visible: on
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        textFormat: Text.PlainText
                        text: "✓"
                        color: root.menuForeground
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.space(13)
                        font.bold: true
                      }
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: root.menuForeground
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: on
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.key === "icons") root.globalIcons = !root.globalIcons
                      else root.globalSections = !root.globalSections
                      root.persistSettings()
                    }
                  }
                }
              }
            }

            Rectangle {
              id: globalTrack
              anchors.right: parent.right
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: globalLabel.verticalCenter
              width: Style.space(44)
              height: Style.space(24)
              radius: height / 2
              color: root.globalChanges ? "#2f9e44" : "#d64545"
              Behavior on color { ColorAnimation { duration: 120 } }

              Rectangle {
                width: parent.height - Style.space(4)
                height: width
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                x: root.globalChanges ? parent.width - width - Style.space(2) : Style.space(2)
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }

              MouseArea {
                id: globalSwitch
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleGlobalChanges()
              }
            }
          }

          Column {
            id: sectionPicker
            width: parent.width
            spacing: Style.space(6)

            readonly property int sectionCount: root.sectionChoices ? root.sectionChoices.length : 0
            readonly property real circleGap: Style.space(4)
            readonly property real circleMax: Style.space(28)
            readonly property real circleMin: Style.space(18)
            readonly property real circle: {
              var n = Math.max(1, sectionCount)
              var avail = Math.max(circleMin, width)
              var fitted = Math.floor((avail - circleGap * Math.max(0, n - 1)) / n)
              return Math.max(circleMin, Math.min(circleMax, fitted))
            }

            Row {
              height: Style.space(28)
              spacing: Style.spacing.sm

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Sections"
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
                horizontalPadding: 0
                verticalPadding: 0
                width: Style.space(28)
                height: width
                radius: width / 2
                enabled: DockModel.groupCount(root.layout) < DockModel.maxSections()
                onClicked: root.addUserSection()
              }
              Button {
                text: "−"
                bordered: true
                foreground: root.menuForeground
                accent: Color.accent
                fontFamily: Style.font.menuFamily
                horizontalPadding: 0
                verticalPadding: 0
                width: Style.space(28)
                height: width
                radius: width / 2
                enabled: root.removeSectionPick >= 0
                opacity: enabled ? 1 : 0.35
                onClicked: root.askRemoveSection(root.removeSectionPick)
              }
            }

            Flow {
              width: parent.width
              spacing: sectionPicker.circleGap

              Repeater {
                model: root.sectionChoices
                delegate: Button {
                  required property var modelData
                  text: modelData.label
                  bordered: true
                  selected: root.removeSectionPick === modelData.value
                  foreground: root.menuForeground
                  accent: Color.accent
                  fontFamily: Style.font.menuFamily
                  fontSize: Math.max(9, Math.round(sectionPicker.circle * 0.42))
                  horizontalPadding: 0
                  verticalPadding: 0
                  width: sectionPicker.circle
                  height: width
                  radius: width / 2
                  onClicked: root.toggleSectionPick(modelData.value)
                }
              }
            }
          }

          MenuRow {
            visible: !root.menuItem && root.menuSectionIndex >= 0
            text: "Remove section " + (root.menuSectionIndex + 1)
            onActivated: root.askRemoveSection(root.menuSectionIndex)
          }

          Column {
            visible: root.confirmRemoveOpen && !root.menuItem
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: "You about to remove section " + (root.confirmSectionIndex + 1)
                    + " from Workspace " + root.workspaceId
                    + " and all of its icon contents. To keep any icons move them to other sections first or they will be removed"
                    + (root.globalSectionsActive() ? " The same section will be removed on every workspace." : "")
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              Button {
                text: "Cancel"
                bordered: true
                foreground: root.menuForeground
                accent: Color.accent
                fontFamily: Style.font.menuFamily
                onClicked: root.cancelRemoveSection()
              }
              Button {
                text: "Remove All"
                bordered: true
                foreground: root.menuForeground
                accent: Color.accent
                fontFamily: Style.font.menuFamily
                onClicked: root.commitRemoveSection()
              }
            }
          }
            }
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
            root.commitLayout(function(current) { return DockModel.removeItem(current, id) }, "icons")
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

      Item {
        id: dragGrip
        z: 40
        width: Style.space(18)
        height: width
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Style.space(2)
        anchors.topMargin: Style.space(2)

        Column {
          anchors.centerIn: parent
          spacing: 2
          Repeater {
            model: 3
            Row {
              spacing: 2
              Repeater {
                model: 2
                Rectangle {
                  width: 2
                  height: 2
                  radius: 1
                  color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.8)
                }
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.SizeAllCursor
          preventStealing: true
          onPressed: function(mouse) { menuCard.dragStart(this, mouse.x, mouse.y) }
          onPositionChanged: function(mouse) {
            if (!(mouse.buttons & Qt.LeftButton)) return
            menuCard.dragMove(this, mouse.x, mouse.y)
          }
          onReleased: root.persistSettings()
        }
      }

      Item {
        id: resizeGrip
        z: 30
        width: Style.space(28)
        height: width
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Canvas {
          id: gripCanvas
          anchors.fill: parent
          anchors.margins: Style.space(6)
          onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            ctx.clearRect(0, 0, w, h)
            ctx.strokeStyle = Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.72)
            ctx.lineWidth = Math.max(1.5, w * 0.08)
            ctx.lineCap = "round"
            var gaps = [0.22, 0.48, 0.74]
            for (var i = 0; i < gaps.length; i++) {
              var start = w * gaps[i]
              ctx.beginPath()
              ctx.moveTo(start, h - 1)
              ctx.lineTo(w - 1, start)
              ctx.stroke()
            }
          }
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          Connections {
            target: root
            function onMenuForegroundChanged() { gripCanvas.requestPaint() }
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.SizeFDiagCursor
          preventStealing: true
          property real pressX: 0
          property real pressY: 0
          property real startW: 0
          property real startH: 0
          onPressed: function(mouse) {
            var p = mapToItem(menuCard.parent, mouse.x, mouse.y)
            pressX = p.x
            pressY = p.y
            startW = menuCard.width
            startH = menuCard.height
            menuCard.resizePinX = menuCard.x
            menuCard.resizePinY = menuCard.y
            menuCard.resizing = true
            if (root.menuItem) {
              root.iconMenuW = startW
              root.iconMenuH = startH
              root.iconMenuSized = true
            } else {
              root.customMenuW = startW
              root.customMenuH = startH
              root.customMenuSized = true
            }
          }
          onPositionChanged: function(mouse) {
            if (!(mouse.buttons & Qt.LeftButton)) return
            var p = mapToItem(menuCard.parent, mouse.x, mouse.y)
            var maxW = menuCard.parent.width - menuCard.resizePinX - Style.space(8)
            var maxH = menuCard.parent.height - menuCard.resizePinY - Style.space(8)
            var minW = root.menuItem ? menuCard.minIconW : menuCard.minBarW
            var minH = root.menuItem ? menuCard.minIconH : menuCard.minBarH
            var nextW = Math.min(Math.max(minW, startW + p.x - pressX), maxW)
            var nextH = Math.min(Math.max(minH, startH + p.y - pressY), maxH)
            if (root.menuItem) {
              root.iconMenuW = nextW
              root.iconMenuH = nextH
            } else {
              root.customMenuW = nextW
              root.customMenuH = nextH
            }
          }
          onReleased: {
            menuCard.resizing = false
            menuCard.park(menuCard.resizePinX, menuCard.resizePinY)
            root.persistSettings()
          }
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
        // Half of the full task-bar card, leaving room for the title and carets.
        readonly property int barHelpBody: {
          var chrome = contentTopInset + helpTitleRow.height + sectionGap + helpSearchRow.height + sectionGap + Style.space(4) + helpCarets.height + contentBottomInset
          var full = chrome + helpColumn.implicitHeight
          return Math.max(Style.space(80), Math.round(full * 0.5) - chrome)
        }
        property bool helpSearchMiss: false
        // Set when the spyglass (or Enter) commits a search. Empty clears the marks.
        property string helpQuery: ""
        property var helpHits: []
        property int helpHitCursor: 0
        property int helpLayoutTick: 0
        property int helpSearchToken: 0

        readonly property bool barHelp: !root.menuItem
        readonly property bool keybindHelp: !!root.menuItem && root.menuItem.kind === "keybind"
        readonly property string purposeCopy: keybindHelp
          ? "A Keybind button icon runs one shortcut for the Super+K list. This popup allows the editing of text inside the button and the associated mouse over tooltip. It also helps with desired placement and the workspaces you would like it to appear in. Desired placement can be furthered by dragging and dropping the icon in the task bar itself."
          : barHelp
            ? "Open task bar customization from the gear, or by right-clicking a blank part of the bar. Add icons, choose where they go, and change how the bar looks. Drag the title or the corner grip to move this window. Drag the lower-right grip to resize it. The place and size are remembered. Each workspace keeps its own icons and sections unless Global Changes is on and the matching checkbox, Icons or Sections, is checked."
            : "Keeps the apps, plugins, and web links you use on a bar along one edge of the screen. Each workspace keeps its own icons, and each monitor shows the workspace on that screen."

        function plainText(html) {
          var source = String(html || "")
          var plain = ""
          var inTag = false
          for (var i = 0; i < source.length; i++) {
            var ch = source.charAt(i)
            if (ch === "<") { inTag = true; continue }
            if (inTag) {
              if (ch === ">") inTag = false
              continue
            }
            plain += ch
          }
          return plain
        }

        function collectHits(query) {
          var q = String(query || "").toLowerCase()
          var hits = []
          if (!q.length) return hits
          function add(kind, feature, source) {
            var plain = plainText(source).toLowerCase()
            var from = 0
            while (from <= plain.length - q.length) {
              var at = plain.indexOf(q, from)
              if (at < 0) break
              hits.push({ kind: kind, feature: feature, start: at, length: q.length })
              from = at + q.length
            }
          }
          if (helpPurposeLabel.visible)
            add(0, -1, "PURPOSE")
          add(1, -1, purposeCopy)
          add(2, -1, "FEATURES")
          var count = helpFeatureRepeater.count
          for (var i = 0; i < count; i++) {
            var node = helpFeatureRepeater.itemAt(i)
            if (!node) continue
            add(3, i, String(node.modelData || ""))
          }
          return hits
        }

        // Word pieces. A match is its own piece so a yellow rectangle can sit behind it.
        function segmentsFor(html, query, forceBold) {
          var source = String(html || "")
          var chars = ""
          var bold = []
          var depth = 0
          var inTag = false
          var tag = ""
          for (var i = 0; i < source.length; i++) {
            var ch = source.charAt(i)
            if (ch === "<") { inTag = true; tag = ""; continue }
            if (inTag) {
              if (ch === ">") {
                inTag = false
                var name = tag.toLowerCase().replace(/^\//, "")
                var closing = tag.charAt(0) === "/"
                if (name === "b" || name === "strong")
                  depth = closing ? Math.max(0, depth - 1) : depth + 1
              } else {
                tag += ch
              }
              continue
            }
            chars += ch
            bold.push(forceBold || depth > 0)
          }
          var q = String(query || "").toLowerCase()
          var lower = chars.toLowerCase()
          var hit = []
          for (var n = 0; n < chars.length; n++) hit.push(false)
          if (q.length) {
            var from = 0
            while (from <= lower.length - q.length) {
              var at = lower.indexOf(q, from)
              if (at < 0) break
              for (var j = at; j < at + q.length; j++) hit[j] = true
              from = at + q.length
            }
          }
          var segs = []
          var buf = ""
          var bufBold = false
          var bufHit = false
          var bufStart = 0
          function push() {
            if (!buf.length) return
            segs.push({ text: buf, bold: bufBold, hit: bufHit, start: bufStart })
            buf = ""
          }
          for (var c = 0; c < chars.length; c++) {
            var glyph = chars.charAt(c)
            var nextBold = bold[c]
            var nextHit = hit[c]
            var broke = buf.length > 0 && (nextBold !== bufBold || nextHit !== bufHit || buf.charAt(buf.length - 1) === " ")
            if (broke) {
              push()
              buf = glyph
              bufBold = nextBold
              bufHit = nextHit
              bufStart = c
            } else if (!buf.length) {
              buf = glyph
              bufBold = nextBold
              bufHit = nextHit
              bufStart = c
            } else {
              buf += glyph
            }
          }
          push()
          return segs
        }

        function cursorStartFor(kind, feature) {
          if (!helpQuery.length || !helpHits || !helpHits.length) return -1
          var hit = helpHits[helpHitCursor]
          if (!hit || hit.kind !== kind) return -1
          if (kind === 3 && hit.feature !== feature) return -1
          return hit.start
        }

        function clearHelpSearch() {
          helpSearchInput.text = ""
          helpQuery = ""
          helpHits = []
          helpHitCursor = 0
          helpSearchMiss = false
          helpSearchToken += 1
          helpLayoutTick += 1
        }

        function contentYOf(item) {
          var y = 0
          var node = item
          while (node && node !== helpColumn) {
            y += node.y
            node = node.parent
          }
          return y
        }

        function hitBlock(hit) {
          if (!hit) return null
          if (hit.kind === 0) return helpPurposeLabel
          if (hit.kind === 1) return helpPurpose
          if (hit.kind === 2) return helpFeaturesLabel
          var row = helpFeatureRepeater.itemAt(hit.feature)
          return row ? row.featureMark : null
        }

        function scrollToHit() {
          if (!helpHits || !helpHits.length) return
          var hit = helpHits[helpHitCursor]
          var block = hitBlock(hit)
          if (!block || !block.yOfStart) return
          var y = contentYOf(block) + block.yOfStart(hit.start)
          helpFlick.reveal(Math.max(0, y - Style.space(8)))
        }

        function nextHelpHit() {
          if (!helpHits || !helpHits.length) return
          helpHitCursor = (helpHitCursor + 1) % helpHits.length
          helpLayoutTick += 1
          var token = ++helpSearchToken
          helpHitScroll.token = token
          helpHitScroll.restart()
        }

        function jumpToHelp(raw) {
          var query = String(raw || "").trim()
          if (!query.length) {
            helpQuery = ""
            helpHits = []
            helpHitCursor = 0
            helpSearchMiss = false
            helpSearchToken += 1
            helpLayoutTick += 1
            return
          }
          var hits = collectHits(query)
          if (!hits.length) {
            helpQuery = ""
            helpHits = []
            helpHitCursor = 0
            helpSearchInput.text = ""
            helpSearchMiss = true
            helpSearchToken += 1
            helpLayoutTick += 1
            return
          }
          helpSearchMiss = false
          helpHitCursor = 0
          helpHits = hits
          helpQuery = query
          var token = ++helpSearchToken
          helpHitScroll.token = token
          helpHitScroll.restart()
        }
        readonly property real naturalHelpW: cardWidth
        readonly property real helpChrome: contentTopInset + helpTitleRow.height + sectionGap + helpSearchRow.height + sectionGap + Style.space(4) + helpCarets.height + contentBottomInset
        readonly property real naturalHelpH: helpChrome + (barHelp ? barHelpBody : Math.min(helpColumn.implicitHeight, maxBody))
        property real dragPressX: 0
        property real dragPressY: 0
        property real dragOriginX: 0
        property real dragOriginY: 0
        property bool resizing: false
        property real resizePinX: 0
        property real resizePinY: 0
        width: root.helpWindowSized ? Math.min(Math.max(Style.space(280), root.helpWindowW), Math.max(Style.space(280), parent.width - Style.space(16))) : naturalHelpW
        height: root.helpWindowSized ? Math.min(Math.max(Style.space(220), root.helpWindowH), Math.max(Style.space(220), parent.height - Style.space(16))) : naturalHelpH
        radius: Style.cornerRadius
        color: root.menuBackground
        borderSpec: root.menuBorderSpec
        padding: Style.space(12)
        x: {
          var margin = Style.space(8)
          if (resizing) return resizePinX
          var fallback = Math.max(margin, Math.round((parent.width - width) / 2))
          if (!root.helpPosSet) return fallback
          var maxX = Math.max(margin, parent.width - width - margin)
          return Math.min(Math.max(margin, root.helpPosX), maxX)
        }
        y: {
          var margin = Style.space(12)
          if (resizing) return resizePinY
          var aboveMenu = menuCard.y - height - margin
          var fallback = Math.max(margin, Math.min(Math.round((menuCard.y - height) / 2), aboveMenu))
          if (!root.helpPosSet) return fallback
          var maxY = Math.max(margin, parent.height - height - margin)
          return Math.min(Math.max(margin, root.helpPosY), maxY)
        }
        function helpDragPoint(item, lx, ly) {
          return item.mapToItem(parent, lx, ly)
        }
        function helpDragStart(item, lx, ly) {
          var p = helpDragPoint(item, lx, ly)
          dragPressX = p.x
          dragPressY = p.y
          dragOriginX = x
          dragOriginY = y
          root.helpPosX = x
          root.helpPosY = y
          root.helpPosSet = true
          root.helpDragging = true
        }
        function helpDragMove(item, lx, ly) {
          if (!root.helpDragging) return
          var p = helpDragPoint(item, lx, ly)
          var margin = Style.space(8)
          root.helpPosX = Math.min(Math.max(margin, dragOriginX + p.x - dragPressX), parent.width - width - margin)
          root.helpPosY = Math.min(Math.max(margin, dragOriginY + p.y - dragPressY), parent.height - height - margin)
        }
        function helpDragEnd() {
          root.helpDragging = false
          root.saveHelpPos(menuWindow.screen ? String(menuWindow.screen.name || "") : "")
        }

        // Holds clicks on the card so they do not fall through to the dismiss layer.
        MouseArea {
          anchors.fill: parent
          z: 0
        }

        // Wait until the marked text has been laid out, then scroll to the first hit.
        Timer {
          id: helpHitScroll
          interval: 48
          repeat: false
          property int token: 0
          onTriggered: {
            if (token !== helpCard.helpSearchToken) return
            helpCard.helpLayoutTick += 1
            helpCard.scrollToHit()
          }
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

          MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: helpClose.left
            cursorShape: Qt.SizeAllCursor
            preventStealing: true
            onPressed: function(mouse) { helpCard.helpDragStart(this, mouse.x, mouse.y) }
            onPositionChanged: function(mouse) {
              if (!(mouse.buttons & Qt.LeftButton)) return
              helpCard.helpDragMove(this, mouse.x, mouse.y)
            }
            onReleased: helpCard.helpDragEnd()
          }

          Image {
            id: helpTitleIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Style.space(18)
            height: width
            source: root.iconSource(helpCard.keybindHelp
              ? "input-keyboard-symbolic"
              : (helpCard.barHelp ? "preferences-system" : "view-app-grid-symbolic"))
            fillMode: Image.PreserveAspectFit
            smooth: true
            sourceSize.width: width
            sourceSize.height: height
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: helpTitleIcon.right
            anchors.leftMargin: Style.space(8)
            anchors.right: helpClose.left
            anchors.rightMargin: Style.space(8)
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: helpCard.keybindHelp ? "KEYBIND" : (helpCard.barHelp ? "Task Bar Help" : "Icon Placement")
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

        Row {
          id: helpSearchRow
          z: 2
          anchors.left: helpTitleRow.left
          anchors.right: helpTitleRow.right
          anchors.top: helpTitleRow.bottom
          anchors.topMargin: helpCard.sectionGap
          height: Style.space(32)
          spacing: Style.space(6)

          Rectangle {
            id: helpSearchField
            readonly property bool showClear: helpSearchInput.text.length > 0 || helpCard.helpQuery.length > 0 || helpCard.helpSearchMiss
            readonly property real clearRoom: showClear ? helpSearchClear.width + Style.space(8) : Style.space(8)
            width: parent.width - helpSearchButton.width - helpNextButton.width - parent.spacing * 2
            height: parent.height
            radius: height / 2
            color: root.menuBackground
            border.color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.45)
            border.width: Math.max(1, Style.normalBorderWidth)

            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: helpSearchField.clearRoom
              visible: helpSearchInput.text.length === 0
              textFormat: Text.PlainText
              text: helpCard.helpSearchMiss ? "Nothing found..." : "Enter search text..."
              color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.45)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            TextInput {
              id: helpSearchInput
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: helpSearchField.clearRoom
              verticalAlignment: Text.AlignVCenter
              color: root.menuForeground
              selectionColor: root.menuSelectedText
              selectedTextColor: root.menuBackground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              clip: true
              onTextEdited: {
                helpCard.helpSearchMiss = false
                helpCard.helpQuery = ""
                helpCard.helpHits = []
                helpCard.helpHitCursor = 0
                helpCard.helpSearchToken += 1
                helpCard.helpLayoutTick += 1
              }
              Keys.onReturnPressed: helpCard.jumpToHelp(text)
              Keys.onEnterPressed: helpCard.jumpToHelp(text)
            }

            CircleGlyphButton {
              id: helpSearchClear
              z: 2
              visible: helpSearchField.showClear
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: Style.space(3)
              width: parent.height - Style.space(6)
              glyph: "X"
              onActivated: helpCard.clearHelpSearch()
            }
          }

          Rectangle {
            id: helpSearchButton
            width: height
            height: parent.height
            radius: width / 2
            color: helpSearchMouse.containsMouse ? root.menuFillHover : "transparent"
            border.color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.45)
            border.width: Math.max(1, Style.normalBorderWidth)

            Canvas {
              anchors.centerIn: parent
              width: Style.space(16)
              height: width
              onPaint: {
                var ctx = getContext("2d")
                var s = width
                ctx.clearRect(0, 0, s, s)
                ctx.strokeStyle = root.menuForeground
                ctx.fillStyle = root.menuForeground
                ctx.lineWidth = Math.max(1.6, s * 0.12)
                ctx.beginPath()
                ctx.arc(s * 0.40, s * 0.40, s * 0.26, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(s * 0.58, s * 0.58)
                ctx.lineTo(s * 0.90, s * 0.90)
                ctx.stroke()
              }
            }

            MouseArea {
              id: helpSearchMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: helpCard.jumpToHelp(helpSearchInput.text)
            }
          }

          Rectangle {
            id: helpNextButton
            readonly property bool canNext: helpCard.helpHits && helpCard.helpHits.length > 0
            width: height
            height: parent.height
            radius: width / 2
            opacity: canNext ? 1 : 0.32
            color: helpNextMouse.containsMouse && canNext ? root.menuFillHover : "transparent"
            border.color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.45)
            border.width: Math.max(1, Style.normalBorderWidth)

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "↓"
              color: root.menuForeground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            MouseArea {
              id: helpNextMouse
              anchors.fill: parent
              hoverEnabled: helpNextButton.canNext
              enabled: helpNextButton.canNext
              cursorShape: helpNextButton.canNext ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: helpCard.nextHelpHit()
            }
          }
        }

        // Marks the edge where scrolling text passes under the title.
        Rectangle {
          z: 3
          anchors.left: helpFlick.left
          anchors.right: helpFlick.right
          anchors.top: helpFlick.top
          height: 1
          color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.45)
        }

        Flickable {
          id: helpFlick
          z: 1
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: helpSearchRow.bottom
          anchors.leftMargin: helpCard.contentLeftInset
          anchors.rightMargin: helpCard.contentRightInset
          anchors.topMargin: helpCard.sectionGap
          height: root.helpWindowSized
            ? Math.max(Style.space(80), helpCard.height - helpCard.helpChrome)
            : (helpCard.barHelp ? helpCard.barHelpBody : Math.min(helpColumn.implicitHeight, helpCard.maxBody))
          contentWidth: width
          contentHeight: helpColumn.implicitHeight
          clip: contentHeight > height + 1
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height + 1

          function scrollBy(delta) {
            var maxY = Math.max(0, contentHeight - height)
            contentY = Math.max(0, Math.min(maxY, contentY + delta))
          }

          function reveal(y) {
            var maxY = Math.max(0, contentHeight - height)
            contentY = Math.max(0, Math.min(maxY, y))
          }

          Item {
            id: helpKeyCatcher
            width: 0
            height: 0
            focus: helpCard.barHelp && root.helpOpen
            Keys.onPressed: function(event) {
              if (!helpCard.barHelp || !helpFlick.interactive) return
              var step = Math.max(28, Math.round(helpFlick.height * 0.28))
              var page = Math.max(step, helpFlick.height - Style.space(16))
              if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                helpFlick.scrollBy(step)
                event.accepted = true
              } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                helpFlick.scrollBy(-step)
                event.accepted = true
              } else if (event.key === Qt.Key_PageDown) {
                helpFlick.scrollBy(page)
                event.accepted = true
              } else if (event.key === Qt.Key_PageUp) {
                helpFlick.scrollBy(-page)
                event.accepted = true
              } else if (event.key === Qt.Key_Home) {
                helpFlick.contentY = 0
                event.accepted = true
              } else if (event.key === Qt.Key_End) {
                helpFlick.contentY = Math.max(0, helpFlick.contentHeight - helpFlick.height)
                event.accepted = true
              }
            }
          }

          Connections {
            target: root
            function onHelpOpenChanged() {
              helpCard.clearHelpSearch()
              if (!root.helpOpen) return
              helpFlick.contentY = 0
              if (helpCard.barHelp)
                Qt.callLater(function() { helpKeyCatcher.forceActiveFocus() })
            }
          }

          Column {
            id: helpColumn
            width: helpFlick.width
            spacing: Style.space(8)

            HelpMarkText {
              id: helpPurposeLabel
              visible: !helpCard.keybindHelp
              width: parent.width
              source: "PURPOSE"
              textColor: Qt.darker(root.menuForeground, 1.4)
              pixelSize: Style.font.caption
              boldText: true
              padTop: Math.ceil(Style.font.caption * 0.15)
              segments: helpCard.segmentsFor(source, helpCard.helpQuery, true)
              hitCursorStart: helpCard.cursorStartFor(0, -1)
            }

            HelpMarkText {
              id: helpPurpose
              width: parent.width
              source: helpCard.purposeCopy
              segments: helpCard.segmentsFor(source, helpCard.helpQuery, false)
              hitCursorStart: helpCard.cursorStartFor(1, -1)
            }

            HelpMarkText {
              id: helpFeaturesLabel
              width: parent.width
              source: "FEATURES"
              textColor: Qt.darker(root.menuForeground, 1.4)
              pixelSize: Style.font.caption
              boldText: true
              padTop: Math.ceil(Style.font.caption * 0.15)
              segments: helpCard.segmentsFor(source, helpCard.helpQuery, true)
              hitCursorStart: helpCard.cursorStartFor(2, -1)
            }

            Column {
              id: helpFeatures
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                id: helpFeatureRepeater
                model: helpCard.keybindHelp ? [
                  "<b>Left-click</b> the icon to run the shortcut, the same action as choosing it in the Super+K list.",
                  "<b>Hover</b> the icon to see the description. The popup shows that name, not the keystroke.",
                  "The letters to the left of the description are the <b>mark</b> on the bar icon. Double-click those letters to change them. Up to three characters.",
                  "<b>Double-click the description</b> to rename it. That name is what you see when you hover the icon.",
                  "The line under the description is the <b>keystroke combination</b>.",
                  "<b>Place</b> chooses Left, Center, or Right for this icon.",
                  "Check a <b>workspace</b> to show this icon there. Uncheck to remove that copy.",
                  "<b>Drag</b> the icon and drop it to move it along the bar.",
                  "<b>Remove</b> takes this icon off this workspace. With <b>Global Changes</b> on and <b>Icons</b> checked, it comes off every workspace.",
                  "The <b>circled i</b> opens this help. Drag the title or the corner grip to move the help window, and the lower-right grip to resize it. The <b>circled X</b> closes the menu."
                ] : helpCard.barHelp ? [
                  "Drag the <b>title</b>, or the grip in the upper-left corner, to move this window. Drag the grip in the <b>lower-right corner</b> to resize it. The window remembers where you left it and how large you made it.",
                  "When the window is narrower, the <b>Placement</b> choices and the color swatches wrap onto the next line. The section number circles under <b>Sections</b> shrink, then wrap, so they stay inside the window.",
                  "<b>App</b> adds a program. <b>Plugin</b> adds a shell plugin. <b>Web</b> adds a link. <b>KeyBind</b> adds a shortcut from the Super+K list. <b>Placement</b>, to the left of the round choices, picks which section receives the new icon. Those choices show every section. The first four stay on one line, and further sections continue on the next line.",
                  "A keybind icon shows up to three letters. Hover shows its name. Left-click runs the shortcut.",
                  "A workspace can have up to eight <b>sections</b>, numbered from the left. <b>+</b> and <b>−</b> sit directly to the right of the word Sections. <b>+</b> adds an empty section at the end.",
                  "The numbered circles under Sections are the sections themselves. Click a number to press it in. Click it again to release it. <b>−</b> stays faded until a number is pressed in. Press <b>−</b> to remove that section.",
                  "An empty section shows a faint <b>watermark</b>, such as 2/5: that section's number, then how many sections the bar has. The mark uses the task bar background, several tones darker, and disappears when an icon is placed in that section.",
                  "An <b>empty section</b> is removed at once. A section that still has icons asks first. <b>Cancel</b> keeps it. <b>Remove All</b> deletes the section and those icons.",
                  "Drag a <b>separator</b> to widen or narrow the section in front of it, including the separator beside the globe, which resizes the last section. The resize cursor shows while the pointer is over the line. The section moves only while <b>Super</b> is held or the mouse button is down. Releasing both stops the move. A section will not shrink smaller than its icons.",
                  "<b>Icon Size +</b> makes icons larger. <b>Icon Size −</b> makes them smaller. <b>Scroll</b> on the task bar does the same. Section widths scale with the icon size.",
                  "<b>Transparency +</b> makes the task bar more see-through. <b>Transparency −</b> makes it more solid. Hold <b>Alt and scroll</b> to do the same.",
                  "A <b>background swatch</b> sets the task bar color. Theme follows the current Omarchy theme. The <b>gear</b> then takes that same color, three tones lighter. Hovering the gear lightens it further, and the highlight behind it uses the bar color.",
                  "<b>Icon popups</b> shows a name when you hover an icon. If that icon has a blinking underline, the popup also shows <b>(x)</b> to the right of the name, where x is how many of that item are open on this workspace.",
                  "<b>Left-click</b> an icon to open it on this workspace. A plugin toggles. A web link opens. A keybind runs its shortcut.",
                  "Click an icon, then <b>drag and drop</b> it to move it along the task bar, including into another numbered section. The moving picture stays on the screen where you started the drag.",
                  "Hold <b>Super and drag</b> a blank part of the task bar to the left, the right, or the bottom to move the task bar there.",
                  "<b>Global Changes</b> is the switch on the right of that label. The <b>Icons</b> and <b>Sections</b> checkboxes sit directly under the words. A checked box shows a check mark. They are dimmed, and do nothing, while the switch is off.",
                  "With the switch on and <b>Icons</b> checked, adding, moving, renaming, or removing an icon applies to every workspace. Adding or moving an icon into a section number that another workspace does not have yet adds empty sections there until that number exists. If Icons is not checked, those edits stay on the workspace you are changing.",
                  "With the switch on and <b>Sections</b> checked, adding a section, removing one, or dragging a separator applies to every workspace. If Sections is not checked, those edits stay on this workspace.",
                  "With the switch on, the bar's <b>edge, icon size, transparency, color, icon popups, and auto-hide</b> still apply to every workspace, whether or not Icons or Sections is checked. With the switch off, those stay on this workspace.",
                  "The <b>globe</b> after the last section is that same switch. Neon green is on. Neon red is off. It is shared by every workspace and cannot be moved or removed.",
                  "The <b>gear</b> to the right of the globe opens this settings menu, the same as a right-click on a blank part of the bar. It cannot be moved or removed.",
                  "<b>Auto hide task bar</b> hides the bar until the pointer reaches its edge. It stays open while the pointer is on the bar.",
                  "A <b>blinking underline</b> under an icon means that item is open on this workspace.",
                  "The <b>circled i</b> opens Task Bar Help. Drag its title or corner grip to move it, and the lower-right grip to resize it. That place and size are remembered too. The <b>circled X</b> closes the menu."
                ] : [
                  "<b>Left-click an icon</b> to open another window on this workspace.",
                  "<b>Left-click a plugin</b> to toggle it. <b>Left-click a web link</b> to open it.",
                  "<b>Hover an icon</b> to see its name. Hover a blank part of the bar to see how to customize. Turn those popups off from the bar menu.",
                  "<b>Double-click the name</b> at the top of this menu to rename the icon.",
                  "Click an icon, then <b>drag and drop</b> it to reposition it along the bar, including into Left, Center, or Right.",
                  "<b>Place</b> sets which numbered section this icon sits in.",
                  "Check a <b>workspace</b> to copy this icon there. Uncheck to remove that copy.",
                  "<b>Remove</b> takes this icon off this workspace. With <b>Global Changes</b> on and <b>Icons</b> checked, it comes off every workspace.",
                  "<b>Right-click the empty bar</b> to add an app, plugin, or web link.",
                  "From the empty bar, change <b>icon size, transparency, and the bar color</b>.",
                  "<b>Scroll</b> on the bar to resize icons. Hold <b>Alt and scroll</b> to change transparency.",
                  "A <b>mark</b> under an app means it is open.",
                  "The bar <b>slides away</b> until the pointer reaches the bottom edge.",
                  "Drag the <b>title</b> or the grip in the upper-left corner to move this menu. Drag the lower-right grip to resize it. The place and size are remembered.",
                  "Hold <b>Super and drag</b> a blank part of the bar left or right to move it to that side. Drag it inward or down to put it back on the bottom."
                ]
                delegate: Item {
                  id: featureRow
                  required property var modelData
                  required property int index
                  property Item featureMark: featureText
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

                  HelpMarkText {
                    id: featureText
                    anchors.left: featureDot.right
                    anchors.leftMargin: Style.space(8)
                    anchors.right: parent.right
                    source: String(featureRow.modelData || "")
                    segments: helpCard.segmentsFor(String(featureRow.modelData || ""), helpCard.helpQuery, false)
                    hitCursorStart: helpCard.cursorStartFor(3, featureRow.index)
                  }
                }
              }
            }
          }
        }

        Row {
          id: helpCarets
          z: 2
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: helpCard.contentBottomInset
          spacing: Style.space(8)
          height: Style.space(26)

          readonly property real scrollMax: Math.max(0, helpFlick.contentHeight - helpFlick.height)
          readonly property bool canUp: helpFlick.contentY > 1
          readonly property bool canDown: helpFlick.contentY < scrollMax - 1

          function nudge(delta) {
            var step = Math.max(28, Math.round(helpFlick.height * 0.28))
            helpFlick.scrollBy(delta * step)
          }

          Repeater {
            model: [
              { glyph: "⌃", down: false },
              { glyph: "⌄", down: true }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool enabledCaret: modelData.down ? helpCarets.canDown : helpCarets.canUp
              width: Style.space(26)
              height: width
              radius: width / 2
              opacity: enabledCaret ? 1 : 0.32
              color: caretMouse.containsMouse && enabledCaret ? root.menuFillHover : "transparent"
              border.width: 1.5
              border.color: caretMouse.containsMouse && enabledCaret ? root.menuStrokeHover : root.menuStroke

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData.glyph
                color: root.menuForeground
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              MouseArea {
                id: caretMouse
                anchors.fill: parent
                hoverEnabled: enabledCaret
                enabled: enabledCaret
                cursorShape: enabledCaret ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: helpCarets.nudge(modelData.down ? 1 : -1)
              }
            }
          }
        }

        Item {
          id: helpDragGrip
          z: 6
          width: Style.space(18)
          height: width
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.leftMargin: Style.space(2)
          anchors.topMargin: Style.space(2)

          Column {
            anchors.centerIn: parent
            spacing: 2
            Repeater {
              model: 3
              Row {
                spacing: 2
                Repeater {
                  model: 2
                  Rectangle {
                    width: 2
                    height: 2
                    radius: 1
                    color: Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.8)
                  }
                }
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            preventStealing: true
            onPressed: function(mouse) { helpCard.helpDragStart(this, mouse.x, mouse.y) }
            onPositionChanged: function(mouse) {
              if (!(mouse.buttons & Qt.LeftButton)) return
              helpCard.helpDragMove(this, mouse.x, mouse.y)
            }
            onReleased: helpCard.helpDragEnd()
          }
        }

        Item {
          id: helpResizeGrip
          z: 6
          width: Style.space(28)
          height: width
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          Canvas {
            id: helpGripCanvas
            anchors.fill: parent
            anchors.margins: Style.space(6)
            onPaint: {
              var ctx = getContext("2d")
              var w = width
              var h = height
              ctx.clearRect(0, 0, w, h)
              ctx.strokeStyle = Qt.rgba(root.menuForeground.r, root.menuForeground.g, root.menuForeground.b, 0.72)
              ctx.lineWidth = Math.max(1.5, w * 0.08)
              ctx.lineCap = "round"
              var gaps = [0.22, 0.48, 0.74]
              for (var i = 0; i < gaps.length; i++) {
                var start = w * gaps[i]
                ctx.beginPath()
                ctx.moveTo(start, h - 1)
                ctx.lineTo(w - 1, start)
                ctx.stroke()
              }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            preventStealing: true
            property real pressX: 0
            property real pressY: 0
            property real startW: 0
            property real startH: 0
            onPressed: function(mouse) {
              var p = mapToItem(helpCard.parent, mouse.x, mouse.y)
              pressX = p.x
              pressY = p.y
              startW = helpCard.width
              startH = helpCard.height
              helpCard.resizePinX = helpCard.x
              helpCard.resizePinY = helpCard.y
              helpCard.resizing = true
              root.helpPosX = helpCard.x
              root.helpPosY = helpCard.y
              root.helpPosSet = true
              root.helpWindowW = startW
              root.helpWindowH = startH
              root.helpWindowSized = true
            }
            onPositionChanged: function(mouse) {
              if (!(mouse.buttons & Qt.LeftButton)) return
              var p = mapToItem(helpCard.parent, mouse.x, mouse.y)
              var maxW = helpCard.parent.width - helpCard.resizePinX - Style.space(8)
              var maxH = helpCard.parent.height - helpCard.resizePinY - Style.space(8)
              root.helpWindowW = Math.min(Math.max(Style.space(280), startW + p.x - pressX), maxW)
              root.helpWindowH = Math.min(Math.max(Style.space(220), startH + p.y - pressY), maxH)
            }
            onReleased: {
              helpCard.resizing = false
              helpCard.helpDragEnd()
            }
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

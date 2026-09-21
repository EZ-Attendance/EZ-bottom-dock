import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

// Auto-hiding bottom dock with left / center / right app icons.
// Empty layout shows "Hello World". Right-click to add apps or web links.
// Layouts are stored per Hyprland workspace.
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
  property string pickerKind: "app" // "app" | "plugin"

  property var layout: DockModel.emptyLayout()
  property var defaultLayout: DockModel.emptyLayout()
  property var workspaceLayouts: ({})
  property var workspaceTouched: ({})
  property string workspaceId: "1"
  property int iconSize: DockModel.defaultIconSize()
  property int bgOpacity: DockModel.defaultBgOpacity()
  property bool showTips: true
  property bool _loadingConfig: false
  property bool _switchingWorkspace: false

  property var dragItem: null
  property string dropSection: ""
  property int dropIndex: 0
  property string dragGhostSource: ""
  property real dragGhostX: 0
  property real dragGhostY: 0
  property int toplevelRevision: 0

  property string pendingSection: "center"
  property var menuItem: null
  property real menuX: 0
  property real menuY: 0
  property var menuScreen: null
  property string pickerQuery: ""
  property string webName: ""
  property string webUrl: ""
  property var pluginCatalog: []

  property bool tipVisible: false
  property string tipText: ""
  property real tipX: 0
  property real tipY: 0
  property var tipScreen: null
  property int tipRequest: 0

  readonly property bool hovered: hoverCount > 0
  readonly property bool uiHeld: menuOpen || pickerOpen || webOpen || dragging
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
  readonly property var desktopApps: DesktopEntries.applications.values || []
  readonly property var pickerApps: DockModel.sortedDesktopEntries(desktopApps, pickerQuery)
  readonly property var pickerPlugins: DockModel.filterPlugins(pluginCatalog, pickerQuery)
  readonly property var pickerModel: pickerKind === "plugin" ? pickerPlugins : pickerApps
  readonly property string pickerTitle: pickerKind === "plugin"
    ? ("Add plugin → " + pendingSection)
    : ("Add app → " + pendingSection)

  Behavior on slideOffset {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  function open(_payload) {}
  function close() { root.closeMenus() }
  function toggle() {}

  function closeMenus() {
    menuOpen = false
    pickerOpen = false
    webOpen = false
    menuItem = null
    pickerQuery = ""
    pickerKind = "app"
    webName = ""
    webUrl = ""
    hideIconTip()
    releaseRevealSoon()
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
    if (hoverCount === 0)
      hideTimer.restart()
    else {
      hideTimer.stop()
      revealHeld = true
    }
  }

  function armReveal() {
    hideTimer.stop()
    revealHeld = true
  }

  function releaseRevealSoon() {
    if (!hovered && !uiHeld)
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
        showTips: showTips
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

  function currentHyprWorkspaceId() {
    try {
      var ws = Hyprland.focusedWorkspace
      if (ws && ws.id !== undefined && ws.id !== null)
        return ws.id
    } catch (e) {
    }
    return 1
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

  function startIconDrag(item) {
    if (!item) return
    closeMenus()
    hideIconTip()
    dragging = true
    dragItem = item
    dropSection = ""
    dropIndex = 0
    dragGhostSource = iconSource(item.icon)
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
    showTips = cfg.showTips !== false
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

  function findToplevelForItem(item) {
    // Touch revision so callers rebind when windows open/close/focus.
    var _rev = toplevelRevision
    if (!item) return null
    var values = []
    try { values = ToplevelManager.toplevels.values || [] } catch (e) { values = [] }
    var any = null
    for (var i = 0; i < values.length; i++) {
      var top = values[i]
      if (!DockModel.itemMatchesToplevel(item, top)) continue
      if (top.activated) return top
      if (!any) any = top
    }
    return any
  }

  function itemIsRunning(item) {
    return !!findToplevelForItem(item)
  }

  function itemIsFocused(item) {
    var _rev = toplevelRevision
    var active = null
    try { active = ToplevelManager.activeToplevel } catch (e) { active = null }
    return !!(active && DockModel.itemMatchesToplevel(item, active))
  }

  function activateOrLaunch(item) {
    if (!item) return
    // Plugins / web links keep their existing open behavior.
    if (item.kind === "plugin" || item.kind === "web") {
      launchItem(item)
      return
    }
    var top = findToplevelForItem(item)
    if (top && typeof top.activate === "function") {
      top.activate()
      return
    }
    launchItem(item)
  }

  function launchItem(item) {
    if (!item) return
    if (item.kind === "plugin" && item.pluginId) {
      // Host IPC — scoped shell.summon cannot open arbitrary plugins.
      Util.execDetached("omarchy-shell -q shell toggle " + Util.shellQuote(String(item.pluginId)) + " '{}'")
      return
    }
    if (item.kind === "web" && item.url) {
      Util.execArgv(["xdg-open", String(item.url)])
      return
    }
    if (item.exec) {
      Util.execDetached(String(item.exec))
      return
    }
    var id = String(item.desktopId || item.id || "")
    if (!id) return
    if (id.slice(-8) === ".desktop") id = id.slice(0, -8)
    Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(id + ".desktop"))
  }

  function openDockMenu(screen, globalX, globalY) {
    menuItem = null
    menuScreen = screen
    menuX = globalX - (screen ? screen.x : 0)
    menuY = globalY - (screen ? screen.y : 0)
    menuOpen = true
    pickerOpen = false
    webOpen = false
    armReveal()
  }

  function openItemMenu(screen, item, globalX, globalY) {
    menuItem = item
    menuScreen = screen
    menuX = globalX - (screen ? screen.x : 0)
    menuY = globalY - (screen ? screen.y : 0)
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
    pickerOpen = true
    webOpen = false
    armReveal()
  }

  function beginAddPlugin(section) {
    pendingSection = section
    pickerKind = "plugin"
    menuOpen = false
    pickerQuery = ""
    pickerOpen = true
    webOpen = false
    refreshPluginCatalog()
    armReveal()
  }

  function beginWebAdd(section) {
    pendingSection = section || "center"
    menuOpen = false
    pickerOpen = false
    webName = ""
    webUrl = "https://"
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

  function acceptPickerRow(row) {
    if (pickerKind === "plugin") acceptPlugin(row)
    else acceptApp(row)
  }

  function acceptWeb() {
    var name = String(webName || "").trim()
    var url = String(webUrl || "").trim()
    if (!name || !url || url === "https://") return
    persistLayout(DockModel.addItem(layout, pendingSection, DockModel.makeWebItem(name, url)))
    closeMenus()
  }

  function refreshPluginCatalog() {
    if (!pluginListProc.running)
      pluginListProc.running = true
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

  Component.onCompleted: {
    root.refreshPluginCatalog()
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
      if (root.hovered || root.uiHeld)
        return
      root.revealHeld = false
    }
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
      root.showTips = true
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

  IpcHandler {
    target: "drace3000.bottom-dock"
    function iconsLarger(): string { return root.iconsLargerFromHotkey() }
    function iconsSmaller(): string { return root.iconsSmallerFromHotkey() }
    function opacityUp(): string { return root.opacityUpFromHotkey() }
    function opacityDown(): string { return root.opacityDownFromHotkey() }
    function workspaceState(): string {
      var keys = []
      for (var k in root.workspaceLayouts) {
        if (Object.prototype.hasOwnProperty.call(root.workspaceLayouts, k))
          keys.push(String(k))
      }
      keys.sort()
      return JSON.stringify({
        workspaceId: String(root.workspaceId),
        focusedKey: String(root.focusedWorkspaceKey),
        keys: keys,
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

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PickerPanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      WebPanel {
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
    anchors { left: true; right: true; bottom: true }
    implicitHeight: root.edgeSize
    HoverHandler {
      enabled: edgeWindow.armed
      onHoveredChanged: {
        if (hovered) root.armReveal()
        else root.releaseRevealSoon()
      }
      Component.onDestruction: if (hovered) root.releaseRevealSoon()
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
    anchors { left: true; right: true; bottom: true }
    margins.bottom: -root.slideOffset
    implicitHeight: root.dockHeight

    HoverHandler {
      onHoveredChanged: root.setHovered(hovered)
      Component.onDestruction: if (hovered) root.setHovered(false)
    }

    Rectangle {
      id: chrome
      anchors.fill: parent
      color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, root.bgOpacity / 100)
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
      border.width: 1

      WheelHandler {
        // Grab wheel over the whole chrome, including over icon MouseAreas.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
        onWheel: function(event) { root.handleDockWheel(event) }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        hoverEnabled: true
        onClicked: function(mouse) {
          var g = mapToGlobal(mouse.x, mouse.y)
          root.openDockMenu(dockWindow.screen, g.x, g.y)
        }
        onWheel: function(wheel) { root.handleDockWheel(wheel) }
      }

      Text {
        visible: root.layoutEmpty
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "Hello World"
        color: root.ink
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      RowLayout {
        id: dockRow
        visible: !root.layoutEmpty
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        readonly property int sectionGap: Style.space(4)
        readonly property int dragMinWidth: root.iconSlot + Style.space(12)

        function sectionAt(chromeX, chromeY) {
          function hit(sectionItem, name) {
            if (!sectionItem) return null
            var p = sectionItem.mapFromItem(chrome, chromeX, chromeY)
            var padX = root.dragging ? Style.space(10) : 0
            var padY = root.dragging ? Style.space(8) : 0
            if (p.x >= -padX && p.x <= sectionItem.width + padX
                && p.y >= -padY && p.y <= sectionItem.height + padY) {
              var pitch = root.iconSlot + dockRow.sectionGap
              var idx = pitch > 0 ? Math.round(p.x / pitch) : 0
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

          // Spacers / empty zones: map by horizontal thirds of the bar.
          var rel = chromeX / Math.max(1, chrome.width)
          if (rel < 0.33) {
            var leftCount = root.layout.left ? root.layout.left.length : 0
            return { section: "left", index: leftCount }
          }
          if (rel > 0.66) {
            var rightCount = root.layout.right ? root.layout.right.length : 0
            return { section: "right", index: rightCount }
          }
          var centerCount = root.layout.center ? root.layout.center.length : 0
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
          Layout.fillHeight: true
          Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
          Layout.minimumWidth: root.dragging ? dockRow.dragMinWidth : 0
          Layout.preferredWidth: Math.max(implicitWidth, root.dragging && model.length === 0 ? dockRow.dragMinWidth : implicitWidth)
          model: root.layout.left
          hostScreen: dockWindow.screen
          chromeItem: chrome
          trackDrag: dockRow.trackDragAt
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
        }

        DockSection {
          id: centerSection
          sectionName: "center"
          Layout.fillHeight: true
          Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
          Layout.minimumWidth: root.dragging ? dockRow.dragMinWidth : 0
          Layout.preferredWidth: Math.max(implicitWidth, root.dragging && model.length === 0 ? dockRow.dragMinWidth : implicitWidth)
          model: root.layout.center
          hostScreen: dockWindow.screen
          chromeItem: chrome
          trackDrag: dockRow.trackDragAt
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
        }

        DockSection {
          id: rightSection
          sectionName: "right"
          Layout.fillHeight: true
          Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
          Layout.minimumWidth: root.dragging ? dockRow.dragMinWidth : 0
          Layout.preferredWidth: Math.max(implicitWidth, root.dragging && model.length === 0 ? dockRow.dragMinWidth : implicitWidth)
          model: root.layout.right
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
          width: 2
          height: root.iconSlot
          radius: 1
          color: root.ink
          opacity: 0.85
          y: (parent.height - height) / 2
          x: {
            var sectionItem = root.dropSection === "left" ? leftSection
              : root.dropSection === "right" ? rightSection
              : centerSection
            if (!sectionItem) return 0
            var pitch = root.iconSlot + Style.space(4)
            var localX = root.dropIndex * pitch - 1
            var mapped = mapFromItem(sectionItem, localX, 0)
            return mapped.x
          }
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

          Image {
            anchors.centerIn: parent
            width: root.iconSlot - Style.space(2)
            height: width
            source: root.dragGhostSource
            fillMode: Image.PreserveAspectFit
            smooth: true
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
    implicitWidth: Math.max(sectionRow.implicitWidth, root.dragging ? root.iconSlot : 0)
    implicitHeight: root.iconSlot

    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      visible: root.dragging && root.dropSection === sectionRoot.sectionName
      color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
    }

    Row {
      id: sectionRow
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      spacing: Style.space(4)

      Repeater {
        model: sectionRoot.model
        delegate: Item {
          id: iconWrap
          required property var modelData
          required property int index
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

          Image {
            id: iconImage
            anchors.centerIn: parent
            width: root.iconSlot - Style.space(2)
            height: width
            source: root.iconSource(iconWrap.modelData.icon)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            scale: iconMouse.containsMouse && !root.dragging ? 1.12 : 1.0

            Behavior on scale {
              NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
          }

          // Running / focused indicator (apps only).
          Rectangle {
            id: runDot
            readonly property bool running: root.itemIsRunning(iconWrap.modelData)
            readonly property bool focused: root.itemIsFocused(iconWrap.modelData)
            visible: running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: focused ? Math.max(6, root.iconSlot * 0.35) : Math.max(4, root.iconSlot * 0.16)
            height: Math.max(2, Math.round(root.iconSlot * 0.08))
            radius: height / 2
            color: root.ink
            opacity: focused ? 0.95 : 0.55
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
            onExited: root.hideIconTip()
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
                root.startIconDrag(iconWrap.modelData)
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
      // Horizontal: follow cursor (tipX already includes a small right offset).
      x: Math.min(Math.max(Style.space(4), root.tipX), parent.width - width - Style.space(4))
      // Vertical: always just above the bottom dock, not the top of the screen.
      y: parent.height - root.dockHeight - height - Style.space(10)

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

  component MenuPanel: PanelWindow {
    id: menuWindow
    readonly property bool forScreen: root.menuScreen === menuWindow.screen
    visible: root.menuOpen && forScreen
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { left: true; right: true; top: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeMenus()
    }

    Rectangle {
      id: menuCard
      width: Style.space(260)
      height: menuColumn.implicitHeight + Style.space(12)
      radius: Style.cornerRadius
      color: root.surface
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
      border.width: 1
      x: Math.min(Math.max(Style.space(8), root.menuX - width / 2), parent.width - width - Style.space(8))
      y: Math.min(Math.max(Style.space(8), parent.height - root.dockHeight - height - Style.space(12)), parent.height - height - Style.space(8))

      Column {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(6)
        spacing: 2

        // Add section: placement + kind pills
        Rectangle {
          visible: !root.menuItem
          width: parent.width
          height: visible ? addSectionColumn.implicitHeight + Style.space(16) : 0
          radius: Style.space(8)
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.top
            textFormat: Text.PlainText
            text: " ADD "
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            // Cover the border line behind the title.
            Rectangle {
              z: -1
              anchors.fill: parent
              anchors.margins: -1
              color: root.surface
            }
          }

          Column {
            id: addSectionColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Style.space(12)
            anchors.margins: Style.space(6)
            spacing: Style.space(4)

            // Kind pills: App / Plugin / Web
            Item {
              width: parent.width
              height: Style.space(32)

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Repeater {
                  model: [
                    { label: "App", action: "add-app" },
                    { label: "Plugin", action: "add-plugin" },
                    { label: "Web", action: "add-web" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    width: Style.space(68)
                    height: Style.space(28)
                    radius: height / 2
                    color: kindPillMouse.containsMouse
                      ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                      : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, kindPillMouse.containsMouse ? 0.45 : 0.22)

                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: root.ink
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }

                    MouseArea {
                      id: kindPillMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (modelData.action === "add-app") root.beginAdd(root.pendingSection)
                        else if (modelData.action === "add-plugin") root.beginAddPlugin(root.pendingSection)
                        else if (modelData.action === "add-web") root.beginWebAdd(root.pendingSection)
                      }
                    }
                  }
                }
              }
            }

            // Placement radios (left / center / right).
            Item {
              width: parent.width
              height: Style.space(28)

              Row {
                id: sectionRadios
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
                    width: radioRow.implicitWidth
                    height: Style.space(24)

                    Row {
                      id: radioRow
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(14)
                        height: Style.space(14)
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, selected ? 0.75 : 0.40)

                        Rectangle {
                          anchors.centerIn: parent
                          width: Style.space(7)
                          height: Style.space(7)
                          radius: width / 2
                          visible: selected
                          color: root.ink
                        }
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: modelData.label
                        color: root.ink
                        font.family: Style.font.family
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
          }
        }

        // Settings: icon size + transparency
        Rectangle {
          visible: !root.menuItem
          width: parent.width
          height: visible ? settingsSectionColumn.implicitHeight + Style.space(16) : 0
          radius: Style.space(8)
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.top
            textFormat: Text.PlainText
            text: " SETTINGS "
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            Rectangle {
              z: -1
              anchors.fill: parent
              anchors.margins: -1
              color: root.surface
            }
          }

          Column {
            id: settingsSectionColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Style.space(12)
            anchors.margins: Style.space(6)
            spacing: Style.space(4)

            GridLayout {
              width: parent.width
              columns: 3
              columnSpacing: Style.space(6)
              rowSpacing: Style.space(4)

              // Icon Size
              Text {
                Layout.fillWidth: true
                Layout.leftMargin: Style.space(4)
                textFormat: Text.PlainText
                text: "Icon Size"
                color: root.ink
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Rectangle {
                Layout.preferredWidth: Style.space(28)
                Layout.preferredHeight: Style.space(28)
                radius: Style.space(8)
                color: iconSizePlusMouse.containsMouse
                  ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                  : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, iconSizePlusMouse.containsMouse ? 0.45 : 0.22)

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "+"
                  color: root.ink
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                MouseArea {
                  id: iconSizePlusMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.bumpIconSize(4)
                }
              }

              Rectangle {
                Layout.preferredWidth: Style.space(28)
                Layout.preferredHeight: Style.space(28)
                radius: Style.space(8)
                color: iconSizeMinusMouse.containsMouse
                  ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                  : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, iconSizeMinusMouse.containsMouse ? 0.45 : 0.22)

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "-"
                  color: root.ink
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                MouseArea {
                  id: iconSizeMinusMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.bumpIconSize(-4)
                }
              }

              // Transparency
              Text {
                Layout.fillWidth: true
                Layout.leftMargin: Style.space(4)
                textFormat: Text.PlainText
                text: "Transparency"
                color: root.ink
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Rectangle {
                Layout.preferredWidth: Style.space(28)
                Layout.preferredHeight: Style.space(28)
                radius: Style.space(8)
                color: transparencyPlusMouse.containsMouse
                  ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                  : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, transparencyPlusMouse.containsMouse ? 0.45 : 0.22)

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "+"
                  color: root.ink
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                MouseArea {
                  id: transparencyPlusMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.bumpBgOpacity(-10)
                }
              }

              Rectangle {
                Layout.preferredWidth: Style.space(28)
                Layout.preferredHeight: Style.space(28)
                radius: Style.space(8)
                color: transparencyMinusMouse.containsMouse
                  ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                  : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, transparencyMinusMouse.containsMouse ? 0.45 : 0.22)

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "-"
                  color: root.ink
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                MouseArea {
                  id: transparencyMinusMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.bumpBgOpacity(10)
                }
              }
            }

            MenuRow {
              text: "Icon popups"
              checkable: true
              checked: root.showTips
              onActivated: root.toggleShowTips()
            }
          }
        }

        // Per-icon menu
        Repeater {
          model: root.menuItem ? [
            { label: "Move to left", action: "move-left" },
            { label: "Move to center", action: "move-center" },
            { label: "Move to right", action: "move-right" },
            { label: "Remove", action: "remove" }
          ] : []
          delegate: MenuRow {
            required property var modelData
            text: modelData.label
            onActivated: {
              var id = root.menuItem ? root.menuItem.id : ""
              if (modelData.action === "remove")
                root.persistLayout(DockModel.removeItem(root.layout, id))
              else if (modelData.action.indexOf("move-") === 0)
                root.persistLayout(DockModel.moveItem(root.layout, id, modelData.action.slice(5)))
              root.closeMenus()
            }
          }
        }
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
    height: Style.space(32)
    radius: Style.space(6)
    color: rowMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent"

    Rectangle {
      id: checkBox
      visible: row.checkable
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      width: Style.space(16)
      height: Style.space(16)
      radius: Style.space(3)
      color: row.checked
        ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
        : "transparent"
      border.width: 1
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, row.checked ? 0.55 : 0.35)

      Text {
        anchors.centerIn: parent
        visible: row.checked
        textFormat: Text.PlainText
        text: "✓"
        color: root.ink
        font.family: Style.font.family
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
      color: root.ink
      font.family: Style.font.family
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

  component PickerPanel: PanelWindow {
    id: pickerWindow
    readonly property bool forScreen: !root.menuScreen || root.menuScreen === pickerWindow.screen
    visible: root.pickerOpen && forScreen
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { left: true; right: true; top: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeMenus()
    }

    Rectangle {
      id: pickerCard
      width: Math.min(Style.space(420), parent.width - Style.space(24))
      height: Math.min(Style.space(460), parent.height - root.dockHeight - Style.space(40))
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.dockHeight + Style.space(16)
      radius: Style.cornerRadius
      color: root.surface
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
      border.width: 1

      MouseArea { anchors.fill: parent } // swallow

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: root.pickerTitle
          color: root.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        TextField {
          id: searchField
          Layout.fillWidth: true
          placeholderText: root.pickerKind === "plugin" ? "Search plugins" : "Search apps"
          text: root.pickerQuery
          color: root.ink
          placeholderTextColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
          background: Rectangle {
            radius: Style.space(8)
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
            border.width: 1
          }
          onTextChanged: root.pickerQuery = text
          Component.onCompleted: forceActiveFocus()
        }

        ListView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: root.pickerModel
          spacing: 2
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: Style.space(40)
            radius: Style.space(8)
            color: appRowMouse.containsMouse
              ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
              : "transparent"

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(10)

              Image {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(24)
                height: width
                source: root.iconSource(
                  root.pickerKind === "plugin"
                    ? (modelData.icon || DockModel.pluginIconFor(modelData.id))
                    : (modelData.icon || modelData.id)
                )
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(40)
                spacing: 0

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: root.pickerKind === "plugin"
                    ? String(modelData.name || modelData.id)
                    : DockModel.entryName(modelData)
                  color: root.ink
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }

                Text {
                  visible: root.pickerKind === "plugin"
                  width: parent.width
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: String(modelData.id || "")
                  color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }

            MouseArea {
              id: appRowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.acceptPickerRow(modelData)
            }
          }
        }
      }
    }

    onVisibleChanged: if (visible) Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  component WebPanel: PanelWindow {
    id: webWindow
    readonly property bool forScreen: !root.menuScreen || root.menuScreen === webWindow.screen
    visible: root.webOpen && forScreen
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "drace3000-bottom-dock-web"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { left: true; right: true; top: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeMenus()
    }

    Rectangle {
      width: Math.min(Style.space(380), parent.width - Style.space(24))
      height: webColumn.implicitHeight + Style.space(24)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.dockHeight + Style.space(16)
      radius: Style.cornerRadius
      color: root.surface
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22)
      border.width: 1

      MouseArea { anchors.fill: parent }

      Column {
        id: webColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: "Add web link"
          color: root.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        TextField {
          id: nameField
          width: parent.width
          placeholderText: "Name"
          text: root.webName
          color: root.ink
          onTextChanged: root.webName = text
          background: Rectangle {
            radius: Style.space(8)
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
            border.width: 1
          }
        }

        TextField {
          id: urlField
          width: parent.width
          placeholderText: "https://"
          text: root.webUrl
          color: root.ink
          onTextChanged: root.webUrl = text
          background: Rectangle {
            radius: Style.space(8)
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
            border.width: 1
          }
        }

        Row {
          spacing: Style.space(8)
          anchors.right: parent.right

          Rectangle {
            width: Style.space(88)
            height: Style.space(32)
            radius: Style.space(8)
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
            Text {
              anchors.centerIn: parent
              text: "Cancel"
              color: root.ink
              font.family: Style.font.family
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeMenus()
            }
          }

          Rectangle {
            width: Style.space(88)
            height: Style.space(32)
            radius: Style.space(8)
            color: Color.flatColor(Color.pick("highlight.color", "accent"), Color.accent)
            Text {
              anchors.centerIn: parent
              text: "Add"
              color: "#F3EFE6"
              font.family: Style.font.family
              font.bold: true
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.acceptWeb()
            }
          }
        }
      }
    }
  }
}

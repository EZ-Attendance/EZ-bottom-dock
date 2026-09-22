// Pure helpers for the bottom dock layout and app search.
.pragma library

function emptyLayout() {
  return { left: [], center: [], right: [] }
}

function cloneItem(item) {
  if (!item || typeof item !== "object") return null
  var kind = String(item.kind || (item.pluginId ? "plugin" : (item.url ? "web" : (item.bindDispatcher ? "keybind" : "app"))))
  if (kind === "separator") return null
  return {
    id: String(item.id || ""),
    label: String(item.label || item.id || ""),
    icon: String(item.icon || ""),
    desktopId: String(item.desktopId || ""),
    pluginId: String(item.pluginId || ""),
    url: String(item.url || ""),
    exec: String(item.exec || ""),
    badge: String(item.badge || ""),
    bindCombo: String(item.bindCombo || ""),
    bindDispatcher: String(item.bindDispatcher || ""),
    bindArg: String(item.bindArg || ""),
    kind: kind
  }
}

function cloneLayout(layout) {
  var src = layout && typeof layout === "object" ? layout : {}
  function cloneSection(name) {
    var arr = Array.isArray(src[name]) ? src[name] : []
    var out = []
    for (var i = 0; i < arr.length; i++) {
      var e = cloneItem(arr[i])
      if (e) out.push(e)
    }
    return out
  }
  return {
    left: cloneSection("left"),
    center: cloneSection("center"),
    right: cloneSection("right")
  }
}

function cloneWorkspaceMap(map) {
  var src = map && typeof map === "object" ? map : {}
  var out = {}
  for (var key in src) {
    if (!Object.prototype.hasOwnProperty.call(src, key)) continue
    out[String(key)] = cloneLayout(src[key])
  }
  return out
}

function workspaceKey(id) {
  var n = Number(id)
  if (!isNaN(n) && n !== 0) return String(n)
  var s = String(id || "").trim()
  return s.length ? s : "1"
}

function layoutForWorkspace(map, id, fallbackLayout) {
  var key = workspaceKey(id)
  var src = map && typeof map === "object" ? map : {}
  if (Object.prototype.hasOwnProperty.call(src, key))
    return cloneLayout(src[key])
  if (fallbackLayout)
    return cloneLayout(fallbackLayout)
  return emptyLayout()
}

function setWorkspaceLayout(map, id, layout) {
  var next = cloneWorkspaceMap(map)
  next[workspaceKey(id)] = cloneLayout(layout)
  return next
}

function removeWorkspaceLayout(map, id) {
  var next = cloneWorkspaceMap(map)
  delete next[workspaceKey(id)]
  return next
}

function firstNonEmptyLayout(map, preferred) {
  if (preferred && !isEmpty(preferred))
    return cloneLayout(preferred)
  var src = map && typeof map === "object" ? map : {}
  var keys = []
  for (var key in src) {
    if (Object.prototype.hasOwnProperty.call(src, key))
      keys.push(String(key))
  }
  keys.sort(function(a, b) {
    var na = Number(a), nb = Number(b)
    if (!isNaN(na) && !isNaN(nb)) return na - nb
    if (a < b) return -1
    if (a > b) return 1
    return 0
  })
  for (var i = 0; i < keys.length; i++) {
    if (!isEmpty(src[keys[i]]))
      return cloneLayout(src[keys[i]])
  }
  return emptyLayout()
}

function pruneEmptyWorkspaceLayouts(map, fallbackLayout) {
  // Keep explicit layouts, including empty ones, so a workspace can hide
  // icons that still live on the shared default.
  return cloneWorkspaceMap(map)
}

function sectionCount(layout, name) {
  return (layout && Array.isArray(layout[name])) ? layout[name].length : 0
}

function totalCount(layout) {
  return sectionCount(layout, "left") + sectionCount(layout, "center") + sectionCount(layout, "right")
}

function isEmpty(layout) {
  return totalCount(layout) === 0
}

function parseShellLayout(rawText, pluginId) {
  return parseDockConfig(rawText, pluginId).layout
}

function parseDockConfig(rawText, pluginId) {
  var cfg = {
    layout: emptyLayout(),
    defaultLayout: emptyLayout(),
    workspaces: {},
    iconSize: 0,
    bgOpacity: -1,
    bgColorKey: "",
    bgColorHex: "",
    showTips: true,
    barEdge: "bottom",
    hasWorkspaceMap: false,
    hasDefaultLayout: false
  }
  try {
    var data = JSON.parse(String(rawText || "{}"))
    var plugins = Array.isArray(data.plugins) ? data.plugins : []
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (entry && entry.id === pluginId) {
        cfg.layout = cloneLayout(entry.layout)
        cfg.iconSize = Number(entry.iconSize || 0)
        if (entry.bgOpacity !== undefined && entry.bgOpacity !== null)
          cfg.bgOpacity = Number(entry.bgOpacity)
        if (entry.bgColorKey !== undefined && entry.bgColorKey !== null)
          cfg.bgColorKey = String(entry.bgColorKey || "")
        if (entry.bgColorHex !== undefined && entry.bgColorHex !== null)
          cfg.bgColorHex = String(entry.bgColorHex || "")
        if (entry.showTips !== undefined && entry.showTips !== null)
          cfg.showTips = entry.showTips !== false && entry.showTips !== 0 && entry.showTips !== "false"
        if (entry.barEdge === "left" || entry.barEdge === "right" || entry.barEdge === "bottom")
          cfg.barEdge = entry.barEdge
        if (entry.defaultLayout && typeof entry.defaultLayout === "object") {
          cfg.defaultLayout = cloneLayout(entry.defaultLayout)
          cfg.hasDefaultLayout = !isEmpty(cfg.defaultLayout)
        }
        if (entry.workspaces && typeof entry.workspaces === "object") {
          cfg.workspaces = cloneWorkspaceMap(entry.workspaces)
          cfg.hasWorkspaceMap = Object.keys(cfg.workspaces).length > 0
        }
        return cfg
      }
    }
  } catch (e) {
  }
  return cfg
}

function clampIconSize(n) {
  var v = Math.round(Number(n) || 0)
  if (v < 20) return 20
  if (v > 96) return 96
  return v
}

function clampBgOpacity(n) {
  var v = Math.round(Number(n))
  if (isNaN(v)) return defaultBgOpacity()
  if (v < 0) return 0
  if (v > 100) return 100
  return v
}

function parseThemeColors(raw) {
  var out = []
  var seen = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (!match) continue
    var key = match[1]
    var hex = String(match[2] || "").toUpperCase()
    if (!hex.length || seen[hex]) continue
    seen[hex] = true
    out.push({ key: key, hex: hex })
  }
  return out
}

function parseWallpaperColors(raw) {
  var out = []
  var seen = {}
  try {
    var data = JSON.parse(String(raw || "[]"))
    if (!Array.isArray(data)) return out
    for (var i = 0; i < data.length; i++) {
      var row = data[i]
      if (!row) continue
      var hex = String(row.hex || "").toUpperCase()
      if (!hex.length || hex.charAt(0) !== "#" || seen[hex]) continue
      seen[hex] = true
      out.push({
        key: String(row.key || ("wall-" + out.length)),
        hex: hex
      })
    }
  } catch (e) {
  }
  return out
}

function resolveThemeColor(palette, key, fallbackHex) {
  var want = String(key || "")
  var list = Array.isArray(palette) ? palette : []
  if (want.length) {
    for (var i = 0; i < list.length; i++) {
      if (list[i] && String(list[i].key) === want && list[i].hex)
        return String(list[i].hex)
    }
  }
  var fallback = String(fallbackHex || "")
  return fallback.charAt(0) === "#" ? fallback : ""
}

function defaultBgOpacity() {
  return 78
}

function dockPadding() {
  return 4
}

function dockHeightForIcons(iconSize) {
  return clampIconSize(iconSize) + dockPadding()
}

function defaultIconSize() {
  return 28
}

function entryName(entry) {
  return String((entry && entry.name) || (entry && entry.id) || "")
}

function entrySearchText(entry) {
  if (!entry) return ""
  var keywords = ""
  try {
    if (entry.keywords && typeof entry.keywords.join === "function")
      keywords = entry.keywords.join(" ")
  } catch (e) {
  }
  return [entry.name, entry.genericName, entry.comment, keywords, entry.id].join(" ").toLowerCase()
}

function sortedDesktopEntries(values, query) {
  var q = String(query || "").trim().toLowerCase()
  var terms = q ? q.split(/\s+/) : []
  var scored = []
  var list = values || []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i]
    if (!entry || !entry.id) continue
    if (entry.noDisplay === true) continue
    var name = entryName(entry)
    if (!name) continue
    var hay = entrySearchText(entry)
    var ok = true
    for (var t = 0; t < terms.length; t++) {
      if (terms[t] && hay.indexOf(terms[t]) < 0) {
        ok = false
        break
      }
    }
    if (!ok) continue
    var score = 0
    var lower = name.toLowerCase()
    if (!q) score = 1000
    else if (lower.indexOf(q) === 0) score = 300
    else if (lower.indexOf(q) >= 0) score = 200
    else score = 100
    scored.push({ score: score, name: lower, entry: entry })
  }
  scored.sort(function(a, b) {
    if (a.score !== b.score) return b.score - a.score
    if (a.name < b.name) return -1
    if (a.name > b.name) return 1
    return 0
  })
  var out = []
  for (var j = 0; j < scored.length; j++) out.push(scored[j].entry)
  return out
}

function keybindWords(description) {
  var cleaned = String(description || "").replace(/[^A-Za-z0-9]+/g, " ").trim()
  if (!cleaned.length) return []
  return cleaned.split(/\s+/)
}

function collectBadges(layout) {
  var used = {}
  var names = ["left", "center", "right"]
  var src = layout && typeof layout === "object" ? layout : {}
  for (var s = 0; s < names.length; s++) {
    var arr = Array.isArray(src[names[s]]) ? src[names[s]] : []
    for (var i = 0; i < arr.length; i++) {
      var item = arr[i]
      if (!item || String(item.kind || "") !== "keybind") continue
      var badge = String(item.badge || "").toUpperCase()
      if (badge) used[badge] = true
    }
  }
  return used
}

function keybindBadge(description, used) {
  var words = keybindWords(description)
  var base = "KEY"
  if (words.length >= 2) {
    base = ""
    for (var i = 0; i < words.length && base.length < 3; i++)
      base += words[i].charAt(0)
  } else if (words.length === 1) {
    base = words[0].slice(0, 3)
  }
  base = base.toUpperCase()
  if (!base.length) base = "KEY"
  var taken = used || {}
  var badge = base.slice(0, 3)
  var n = 2
  while (taken[badge]) {
    badge = (base.slice(0, 2) + String(n)).slice(0, 3)
    n++
    if (n > 99) break
  }
  taken[badge] = true
  return badge
}

function makeKeybindItem(row, layout) {
  var name = String((row && row.name) || "").trim() || "Keybinding"
  var badge = keybindBadge(name, collectBadges(layout))
  var slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "key"
  return {
    id: "keybind-" + slug + "-" + Date.now().toString(36),
    label: name,
    icon: "",
    badge: badge,
    desktopId: "",
    pluginId: "",
    url: "",
    exec: "",
    bindCombo: String((row && row.combo) || ""),
    bindDispatcher: String((row && row.dispatcher) || ""),
    bindArg: String((row && row.arg) || ""),
    kind: "keybind"
  }
}

function filterKeybinds(list, query) {
  var q = String(query || "").trim().toLowerCase()
  var rows = list || []
  if (!q) return rows.slice()
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    var hay = [row.name, row.combo, row.line].join(" ").toLowerCase()
    if (hay.indexOf(q) >= 0) out.push(row)
  }
  return out
}

function makeWebItem(label, url) {
  var safe = String(label || "Web").trim() || "Web"
  var href = String(url || "").trim()
  var slug = safe.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
  return {
    id: "web-" + slug + "-" + Date.now().toString(36),
    label: safe,
    icon: "emblem-web",
    desktopId: "",
    pluginId: "",
    url: href,
    exec: "",
    kind: "web"
  }
}

function pluginIconFor(id) {
  var key = String(id || "")
  var map = {
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
    "io.github.twiking.omasettings": "preferences-system",
    "stappmus.activity-monitor": "utilities-system-monitor"
  }
  return map[key] || "preferences-system"
}

function isExcludedBarWidget(id) {
  var key = String(id || "")
  var excluded = {
    "omarchy.spacer": true,
    "omarchy.workspaces": true,
    "omarchy.tray": true,
    "omarchy.keyboard-layout": true,
    "omarchy.indicators": true,
    "omarchy.active-window": true,
    "omarchy.bar": true,
    "omarchy.microphone": true
  }
  return excluded[key] === true
}

function isSummonablePlugin(plugin, selfId) {
  if (!plugin || !plugin.id) return false
  if (String(plugin.id) === String(selfId || "")) return false
  if (plugin.enabled === false) return false
  var kinds = Array.isArray(plugin.kinds) ? plugin.kinds : []
  var hasUi = false
  var barWidgetOnly = false
  for (var k = 0; k < kinds.length; k++) {
    if (kinds[k] === "panel" || kinds[k] === "overlay" || kinds[k] === "menu")
      hasUi = true
    if (kinds[k] === "bar-widget")
      barWidgetOnly = true
  }
  if (hasUi) return true
  if (barWidgetOnly && !isExcludedBarWidget(plugin.id)) return true
  return false
}

function makePluginItem(plugin) {
  var id = String((plugin && plugin.id) || "")
  var label = String((plugin && plugin.name) || id)
  if (id === "omarchy.menu")
    label = "Oma menu"
  return {
    id: "plugin-" + id,
    label: label,
    icon: pluginIconFor(id),
    desktopId: "",
    pluginId: id,
    url: "",
    exec: "",
    kind: "plugin"
  }
}

function parsePluginCatalog(rawText, selfId) {
  var out = []
  try {
    var list = JSON.parse(String(rawText || "[]"))
    if (!Array.isArray(list)) return out
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!isSummonablePlugin(p, selfId)) continue
      out.push({
        id: String(p.id),
        name: String(p.name || p.id),
        kinds: Array.isArray(p.kinds) ? p.kinds : [],
        icon: pluginIconFor(p.id)
      })
    }
  } catch (e) {
  }
  out.sort(function(a, b) {
    var an = a.name.toLowerCase()
    var bn = b.name.toLowerCase()
    if (an < bn) return -1
    if (an > bn) return 1
    return 0
  })
  return out
}

function filterPlugins(catalog, query) {
  var q = String(query || "").trim().toLowerCase()
  var list = catalog || []
  if (!q) return list.slice()
  var out = []
  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    var hay = [p.name, p.id].join(" ").toLowerCase()
    if (hay.indexOf(q) >= 0) out.push(p)
  }
  return out
}

function makeAppItem(entry) {
  var id = String((entry && entry.id) || "")
  return {
    id: id,
    label: entryName(entry),
    icon: String((entry && entry.icon) || id),
    desktopId: id,
    pluginId: "",
    url: "",
    exec: "",
    kind: "app"
  }
}

function itemLabel(item) {
  if (!item) return ""
  var label = String(item.label || "").trim()
  if (label.length)
    return label
  if (String(item.pluginId || "") === "omarchy.menu" || String(item.id || "") === "plugin-omarchy.menu")
    return "Oma menu"
  return String(item.id || "")
}

function setItemBadge(layout, itemId, badge) {
  var next = cloneLayout(layout)
  var want = String(itemId || "")
  var mark = String(badge || "").replace(/[^A-Za-z0-9]/g, "").toUpperCase().slice(0, 3)
  if (!want.length || !mark.length)
    return next
  var sections = ["left", "center", "right"]
  for (var i = 0; i < sections.length; i++) {
    var key = sections[i]
    for (var j = 0; j < next[key].length; j++) {
      if (next[key][j] && next[key][j].id === want)
        next[key][j].badge = mark
    }
  }
  return next
}

function renameItem(layout, itemId, label) {
  var next = cloneLayout(layout)
  var want = String(itemId || "")
  var name = String(label || "").trim()
  if (!want.length || !name.length)
    return next
  var sections = ["left", "center", "right"]
  for (var i = 0; i < sections.length; i++) {
    var key = sections[i]
    for (var j = 0; j < next[key].length; j++) {
      if (next[key][j] && next[key][j].id === want)
        next[key][j].label = name
    }
  }
  return next
}

function stripId(layout, itemId) {
  var next = cloneLayout(layout)
  var sections = ["left", "center", "right"]
  for (var i = 0; i < sections.length; i++) {
    var key = sections[i]
    var kept = []
    for (var j = 0; j < next[key].length; j++) {
      if (next[key][j].id !== itemId) kept.push(next[key][j])
    }
    next[key] = kept
  }
  return next
}

function addItem(layout, section, item) {
  var key = section === "left" || section === "right" ? section : "center"
  var next = stripId(layout, item.id)
  next[key].push(item)
  return next
}

function removeItem(layout, itemId) {
  return stripId(layout, itemId)
}

function findItem(layout, itemId) {
  var loc = findItemLocation(layout, itemId)
  return loc ? loc.item : null
}

function findItemLocation(layout, itemId) {
  var sections = ["left", "center", "right"]
  for (var i = 0; i < sections.length; i++) {
    var key = sections[i]
    var arr = layout && Array.isArray(layout[key]) ? layout[key] : []
    for (var j = 0; j < arr.length; j++) {
      if (arr[j] && arr[j].id === itemId)
        return { section: key, index: j, item: arr[j] }
    }
  }
  return null
}

function moveItem(layout, itemId, section) {
  var found = findItem(layout, itemId)
  if (!found) return layout
  return addItem(layout, section, found)
}

// Move item into section at index (0..length). Reorder within the same section is supported.
function moveItemAt(layout, itemId, section, index) {
  var loc = findItemLocation(layout, itemId)
  if (!loc) return layout
  var key = section === "left" || section === "right" ? section : "center"
  var next = cloneLayout(layout)
  var item = null
  for (var i = 0; i < next[loc.section].length; i++) {
    if (next[loc.section][i].id === itemId) {
      item = next[loc.section][i]
      next[loc.section].splice(i, 1)
      break
    }
  }
  if (!item) return layout
  var idx = Math.round(Number(index))
  if (isNaN(idx)) idx = next[key].length
  if (loc.section === key && loc.index < idx)
    idx -= 1
  if (idx < 0) idx = 0
  if (idx > next[key].length) idx = next[key].length
  next[key].splice(idx, 0, item)
  return next
}

function normalizeAppId(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\.desktop$/i, "")
    .replace(/\s+/g, "-")
}

function appIdTokens(value) {
  var id = normalizeAppId(value)
  if (!id) return []
  var out = [id]
  var parts = id.split(".")
  if (parts.length > 1) {
    var last = parts[parts.length - 1]
    if (last && out.indexOf(last) < 0) out.push(last)
  }
  return out
}

function idsMatch(a, b) {
  var left = appIdTokens(a)
  var right = appIdTokens(b)
  if (!left.length || !right.length) return false
  for (var i = 0; i < left.length; i++) {
    for (var j = 0; j < right.length; j++) {
      if (left[i] === right[j]) return true
      if (left[i].indexOf(right[j]) >= 0 || right[j].indexOf(left[i]) >= 0)
        return true
    }
  }
  return false
}

// Candidates used to match a dock item against Wayland toplevel appId values.
function keybindWindowKeys(item) {
  var keys = []
  function add(v) {
    var n = normalizeAppId(v)
    if (!n) return
    if (keys.indexOf(n) < 0) keys.push(n)
  }
  if (!item || String(item.kind || "") !== "keybind") return keys
  if (String(item.bindDispatcher || "") !== "exec") return keys
  var arg = String(item.bindArg || "").trim()
  if (!arg.length) return keys
  var url = webAppUrlFromExec(arg)
  if (url) {
    var ids = chromeWebAppIds(url)
    for (var i = 0; i < ids.length; i++) add(ids[i])
    return keys
  }
  var token = arg.split(/\s+/)[0].split("/").pop()
  if (token === "omarchy-launch-nautilus" || token === "nautilus") {
    add("org.gnome.Nautilus")
    add("nautilus")
    return keys
  }
  if (token === "omarchy-agent") {
    add("org.omarchy.agent")
    return keys
  }
  var gtk = arg.match(/gtk-launch\s+(\S+)/)
  if (gtk && gtk[1]) add(String(gtk[1]).replace(/\.desktop$/i, ""))
  if (token && token !== "sh" && token !== "bash") add(token)
  return keys
}

// Full class equality. Substring matching treated a short token such as
// "agent" as still running after that window had closed.
function keybindMatchesClass(item, className) {
  var appId = normalizeAppId(className)
  if (!appId) return false
  var keys = keybindWindowKeys(item)
  for (var i = 0; i < keys.length; i++) {
    if (keys[i] === appId) return true
  }
  return false
}

function itemMatchKeys(item) {
  if (!item) return []
  var kind = String(item.kind || "")
  if (kind === "plugin" || kind === "web") return []
  if (kind === "keybind") return keybindWindowKeys(item)
  var keys = []
  function add(v) {
    var n = normalizeAppId(v)
    if (!n) return
    if (keys.indexOf(n) < 0) keys.push(n)
  }
  add(item.desktopId)
  add(item.id)
  add(item.icon)
  add(item.exec)
  return keys
}

function itemMatchesToplevel(item, toplevel) {
  if (!item || !toplevel) return false
  var appId = normalizeAppId(toplevel.appId)
  if (!appId) return false
  var keys = itemMatchKeys(item)
  for (var i = 0; i < keys.length; i++) {
    if (idsMatch(keys[i], appId)) return true
  }
  return false
}

// omarchy-launch-webapp runs Chrome with --app=URL. Chrome's Wayland id is
// chrome-<host>__<path>-<profile>, not the .desktop file name.
function webAppUrlFromExec(exec) {
  var text = String(exec || "")
  var quoted = text.match(/omarchy-launch-webapp\s+"([^"]+)"/i)
  if (quoted && quoted[1]) return quoted[1]
  var plain = text.match(/omarchy-launch-webapp\s+(\S+)/i)
  if (plain && plain[1]) return plain[1]
  var app = text.match(/--app=(?:"([^"]+)"|(\S+))/i)
  if (app) return app[1] || app[2] || ""
  return ""
}

function chromeWebAppIds(url) {
  var raw = String(url || "").trim()
  var match = raw.match(/^[a-z][a-z0-9+.-]*:\/\/([^\/?#]+)([^?#]*)/i)
  if (!match) return []
  var host = String(match[1] || "").toLowerCase()
  var path = String(match[2] || "/")
  if (!path.length) path = "/"
  if (path.charAt(0) !== "/") path = "/" + path
  var name = (host + "_" + path).replace(/\//g, "_").replace(/^_+|_+$/g, "")
  if (!name.length) return []
  return [name, "chrome-" + name + "-default", "chromium-" + name + "-default"]
}

function itemMatchesToplevelKeys(item, toplevel, extraKeys) {
  if (item && String(item.kind || "") === "keybind")
    return keybindMatchesClass(item, toplevel && toplevel.appId)
  if (itemMatchesToplevel(item, toplevel)) return true
  if (!toplevel) return false
  var appId = normalizeAppId(toplevel.appId)
  if (!appId) return false
  var keys = extraKeys || []
  for (var i = 0; i < keys.length; i++) {
    if (idsMatch(keys[i], appId)) return true
  }
  return false
}

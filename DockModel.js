// Pure helpers for the bottom dock layout and app search.
.pragma library

function maxSections() { return 8 }

function emptySection(span) {
  var n = Math.round(Number(span) || 0)
  return { items: [], span: n > 0 ? n : 0 }
}

function emptyLayout() {
  return { sections: [emptySection(0), emptySection(0), emptySection(0)] }
}

function sectionIndex(section) {
  if (section === "left") return 0
  if (section === "center") return 1
  if (section === "right") return 2
  var n = Math.round(Number(section))
  if (isNaN(n) || n < 0) return 0
  return n
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

function cloneItemList(arr) {
  var list = Array.isArray(arr) ? arr : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var e = cloneItem(list[i])
    if (e) out.push(e)
  }
  return out
}

function cloneLayout(layout) {
  var src = layout && typeof layout === "object" ? layout : {}
  var sections = []
  if (Array.isArray(src.sections)) {
    for (var i = 0; i < src.sections.length && sections.length < maxSections(); i++) {
      var sec = src.sections[i] || {}
      var items = Array.isArray(sec.items) ? sec.items : []
      var span = Math.round(Number(sec.span) || 0)
      sections.push({ items: cloneItemList(items), span: span > 0 ? span : 0 })
    }
  } else {
    sections.push({ items: cloneItemList(src.left), span: 0 })
    sections.push({ items: cloneItemList(src.center), span: 0 })
    sections.push({ items: cloneItemList(src.right), span: 0 })
  }
  return { sections: sections }
}

function sectionsOf(layout) {
  if (layout && Array.isArray(layout.sections)) return layout.sections
  return cloneLayout(layout).sections
}

function groupCount(layout) {
  return sectionsOf(layout).length
}

function sectionItems(layout, index) {
  var sections = sectionsOf(layout)
  var sec = sections[index]
  return sec && Array.isArray(sec.items) ? sec.items : []
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

function normalizeEdge(edge) {
  return edge === "left" || edge === "right" ? edge : "bottom"
}

function flagOn(value, fallback) {
  if (value === undefined || value === null) return !!fallback
  return value !== false && value !== 0 && value !== "false"
}

function defaultLook() {
  return {
    barEdge: "bottom",
    iconSize: defaultIconSize(),
    bgOpacity: defaultBgOpacity(),
    bgColorKey: "",
    bgColorHex: "",
    showTips: true,
    autoHide: false
  }
}

function cloneLook(look, fallback) {
  var base = fallback && typeof fallback === "object" ? fallback : defaultLook()
  var src = look && typeof look === "object" ? look : {}
  var size = Number(src.iconSize)
  var opacity = Number(src.bgOpacity)
  var edge = src.barEdge === "left" || src.barEdge === "right" || src.barEdge === "bottom"
    ? src.barEdge
    : base.barEdge
  return {
    barEdge: normalizeEdge(edge),
    iconSize: size > 0 ? clampIconSize(size) : clampIconSize(base.iconSize || defaultIconSize()),
    bgOpacity: src.bgOpacity !== undefined && src.bgOpacity !== null && !isNaN(opacity) && opacity >= 0
      ? clampBgOpacity(opacity)
      : clampBgOpacity(base.bgOpacity),
    bgColorKey: src.bgColorKey !== undefined && src.bgColorKey !== null
      ? String(src.bgColorKey || "")
      : String(base.bgColorKey || ""),
    bgColorHex: src.bgColorHex !== undefined && src.bgColorHex !== null
      ? String(src.bgColorHex || "")
      : String(base.bgColorHex || ""),
    showTips: flagOn(src.showTips !== undefined ? src.showTips : base.showTips, true),
    autoHide: flagOn(src.autoHide !== undefined ? src.autoHide : base.autoHide, false)
  }
}

function cloneLookMap(map) {
  var src = map && typeof map === "object" ? map : {}
  var out = {}
  for (var key in src) {
    if (!Object.prototype.hasOwnProperty.call(src, key)) continue
    out[workspaceKey(key)] = cloneLook(src[key])
  }
  return out
}

function lookForWorkspace(map, id, fallbackLook) {
  var key = workspaceKey(id)
  var src = map && typeof map === "object" ? map : {}
  var fallback = cloneLook(fallbackLook)
  if (Object.prototype.hasOwnProperty.call(src, key))
    return cloneLook(src[key], fallback)
  return fallback
}

function setWorkspaceLook(map, id, look) {
  var next = cloneLookMap(map)
  next[workspaceKey(id)] = cloneLook(look)
  return next
}

function patchLook(look, patch) {
  var next = cloneLook(look)
  if (!patch || typeof patch !== "object") return next
  if (patch.barEdge !== undefined) next.barEdge = normalizeEdge(patch.barEdge)
  if (patch.iconSize !== undefined) next.iconSize = clampIconSize(patch.iconSize)
  if (patch.bgOpacity !== undefined) next.bgOpacity = clampBgOpacity(patch.bgOpacity)
  if (patch.bgColorKey !== undefined) next.bgColorKey = String(patch.bgColorKey || "")
  if (patch.bgColorHex !== undefined) next.bgColorHex = String(patch.bgColorHex || "")
  if (patch.showTips !== undefined) next.showTips = !!patch.showTips
  if (patch.autoHide !== undefined) next.autoHide = !!patch.autoHide
  return next
}

// ids are workspace keys. Workspaces missing from the map start from fallbackLook.
function applyLookPatch(map, ids, patch, fallbackLook) {
  var next = cloneLookMap(map)
  var list = Array.isArray(ids) ? ids : []
  var fallback = cloneLook(fallbackLook)
  for (var i = 0; i < list.length; i++) {
    var key = workspaceKey(list[i])
    var current = Object.prototype.hasOwnProperty.call(next, key) ? next[key] : fallback
    next[key] = patchLook(current, patch)
  }
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

function sectionLength(layout, index) {
  return sectionItems(layout, index).length
}

function totalCount(layout) {
  var sections = sectionsOf(layout)
  var n = 0
  for (var i = 0; i < sections.length; i++)
    n += (sections[i].items || []).length
  return n
}

function contentSpan(items, iconSlot, keybindSlot, gap) {
  var list = Array.isArray(items) ? items : []
  var slot = Math.max(1, Math.round(Number(iconSlot) || 28))
  var keybind = Math.max(slot, Math.round(Number(keybindSlot) || (slot + 16)))
  var g = Math.max(0, Math.round(Number(gap) || 0))
  if (!list.length) return slot
  var total = 0
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    total += item && String(item.kind || "") === "keybind" ? keybind : slot
  }
  if (list.length > 1) total += g * (list.length - 1)
  return total
}

function floorSpan(iconSlot, gap) {
  var slot = Math.max(1, Math.round(Number(iconSlot) || 28))
  var g = Math.max(0, Math.round(Number(gap) || 0))
  return slot * 3 + g * 2
}

function sectionMinimum(items, iconSlot, keybindSlot, gap) {
  var list = Array.isArray(items) ? items : []
  if (!list.length) return Math.max(1, Math.round(Number(iconSlot) || 28))
  return contentSpan(list, iconSlot, keybindSlot, gap)
}

function assignMissingSpans(layout, iconSlot, keybindSlot, gap) {
  var next = cloneLayout(layout)
  var floor = floorSpan(iconSlot, gap)
  var shared = floor
  var i
  for (i = 0; i < next.sections.length; i++) {
    var content = contentSpan(next.sections[i].items, iconSlot, keybindSlot, gap)
    if (next.sections[i].items.length && content > shared) shared = content
  }
  for (i = 0; i < next.sections.length; i++) {
    var minSpan = sectionMinimum(next.sections[i].items, iconSlot, keybindSlot, gap)
    if (!(next.sections[i].span > 0)) next.sections[i].span = Math.max(shared, minSpan)
    else if (next.sections[i].span < minSpan) next.sections[i].span = minSpan
  }
  return next
}

function scaleSpans(layout, ratio) {
  var next = cloneLayout(layout)
  var r = Number(ratio)
  if (!isFinite(r) || r <= 0) return next
  for (var i = 0; i < next.sections.length; i++) {
    var span = Math.round(next.sections[i].span * r)
    if (span > 0) next.sections[i].span = span
  }
  return next
}

function resizeSection(layout, index, delta, minSpan) {
  var next = cloneLayout(layout)
  var i = Math.round(Number(index))
  if (i < 0 || i >= next.sections.length) return next
  var floor = Math.max(1, Math.round(Number(minSpan) || 1))
  var span = next.sections[i].span + Math.round(Number(delta) || 0)
  if (span < floor) span = floor
  next.sections[i].span = span
  return next
}

function applySpanDeltas(layout, before, after, iconSlot, keybindSlot, gap) {
  var next = cloneLayout(layout)
  var prior = sectionsOf(before)
  var later = sectionsOf(after)
  var n = Math.min(prior.length, later.length, next.sections.length)
  for (var i = 0; i < n; i++) {
    var delta = Math.round(Number(later[i].span) || 0) - Math.round(Number(prior[i].span) || 0)
    if (!delta) continue
    var span = Math.round(Number(next.sections[i].span) || 0) + delta
    var minSpan = sectionMinimum(next.sections[i].items, iconSlot, keybindSlot, gap)
    if (span < minSpan) span = minSpan
    next.sections[i].span = span
  }
  return next
}

function resizeTail(layout, delta, minSpan) {
  var count = groupCount(layout)
  if (!count) return cloneLayout(layout)
  return resizeSection(layout, count - 1, delta, minSpan)
}

function resizeBoundary(layout, index, delta, minA, minB) {
  var next = cloneLayout(layout)
  var i = Math.round(Number(index))
  if (i < 0 || i + 1 >= next.sections.length) return next
  var a = next.sections[i].span
  var b = next.sections[i + 1].span
  var grow = Math.round(Number(delta) || 0)
  var floorA = Math.max(1, Math.round(Number(minA) || 1))
  var floorB = Math.max(1, Math.round(Number(minB) || 1))
  if (grow > 0) {
    var shrink = Math.min(grow, Math.max(0, b - floorB))
    next.sections[i].span = a + grow
    next.sections[i + 1].span = b - shrink
  } else if (grow < 0) {
    var need = -grow
    var shrinkA = Math.min(need, Math.max(0, a - floorA))
    next.sections[i].span = a - shrinkA
    next.sections[i + 1].span = b + need
  }
  return next
}

function addSection(layout, span) {
  var next = cloneLayout(layout)
  if (next.sections.length >= maxSections()) return next
  next.sections.push(emptySection(span))
  return next
}

function removeSection(layout, index) {
  var next = cloneLayout(layout)
  var i = Math.round(Number(index))
  if (i < 0 || i >= next.sections.length) return next
  next.sections.splice(i, 1)
  return next
}

function ensureSections(layout, index, emptySpan) {
  var next = cloneLayout(layout)
  var idx = sectionIndex(index)
  if (idx >= maxSections()) idx = maxSections() - 1
  while (next.sections.length <= idx && next.sections.length < maxSections())
    next.sections.push(emptySection(emptySpan))
  return next
}

function isEmpty(layout) {
  return totalCount(layout) === 0
}

// First shell start after install keeps the gear note up long enough to
// notice behind other windows. Later starts use the short timeout.
function welcomeTimeoutMs(firstRun) {
  return firstRun ? 120000 : 15000
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
    autoHide: false,
    barEdge: "bottom",
    globalChanges: false,
    globalIcons: true,
    globalSections: true,
    welcomeIntroduced: false,
    workspaceLooks: {},
    customMenu: null,
    iconMenu: null,
    helpWindow: null,
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
        if (entry.autoHide !== undefined && entry.autoHide !== null)
          cfg.autoHide = entry.autoHide !== false && entry.autoHide !== 0 && entry.autoHide !== "false"
        if (entry.barEdge === "left" || entry.barEdge === "right" || entry.barEdge === "bottom")
          cfg.barEdge = entry.barEdge
        if (entry.globalChanges !== undefined && entry.globalChanges !== null)
          cfg.globalChanges = entry.globalChanges === true || entry.globalChanges === 1 || entry.globalChanges === "true"
        if (entry.globalIcons !== undefined && entry.globalIcons !== null)
          cfg.globalIcons = entry.globalIcons === true || entry.globalIcons === 1 || entry.globalIcons === "true"
        if (entry.globalSections !== undefined && entry.globalSections !== null)
          cfg.globalSections = entry.globalSections === true || entry.globalSections === 1 || entry.globalSections === "true"
        if (entry.welcomeIntroduced !== undefined && entry.welcomeIntroduced !== null)
          cfg.welcomeIntroduced = entry.welcomeIntroduced === true || entry.welcomeIntroduced === 1 || entry.welcomeIntroduced === "true"
        if (entry.customMenu && typeof entry.customMenu === "object") {
          cfg.customMenu = {
            placed: entry.customMenu.placed === true,
            sized: entry.customMenu.sized === true,
            x: Number(entry.customMenu.x) || 0,
            y: Number(entry.customMenu.y) || 0,
            w: Number(entry.customMenu.w) || 0,
            h: Number(entry.customMenu.h) || 0
          }
        }
        if (entry.iconMenu && typeof entry.iconMenu === "object") {
          cfg.iconMenu = {
            placed: entry.iconMenu.placed === true,
            sized: entry.iconMenu.sized === true,
            x: Number(entry.iconMenu.x) || 0,
            y: Number(entry.iconMenu.y) || 0,
            w: Number(entry.iconMenu.w) || 0,
            h: Number(entry.iconMenu.h) || 0
          }
        }
        if (entry.helpWindow && typeof entry.helpWindow === "object") {
          cfg.helpWindow = {
            placed: entry.helpWindow.placed === true,
            sized: entry.helpWindow.sized === true,
            x: Number(entry.helpWindow.x) || 0,
            y: Number(entry.helpWindow.y) || 0,
            w: Number(entry.helpWindow.w) || 0,
            h: Number(entry.helpWindow.h) || 0
          }
        }
        if (entry.workspaceLooks && typeof entry.workspaceLooks === "object")
          cfg.workspaceLooks = cloneLookMap(entry.workspaceLooks)
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

function iconSizeMin() { return 20 }
function iconSizeMax() { return 96 }

function clampIconSize(n) {
  var v = Math.round(Number(n) || 0)
  if (v < iconSizeMin()) return iconSizeMin()
  if (v > iconSizeMax()) return iconSizeMax()
  return v
}

// Smallest icon reads as 10%, largest as 100%.
function iconSizePercent(n) {
  var v = clampIconSize(n)
  var span = iconSizeMax() - iconSizeMin()
  if (span <= 0) return 100
  return Math.round(10 + (v - iconSizeMin()) * 90 / span)
}

// 0% is solid, 100% is fully see-through. bgOpacity is the inverse.
function transparencyPercent(opacity) {
  return 100 - clampBgOpacity(opacity)
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
  var sections = sectionsOf(layout)
  for (var s = 0; s < sections.length; s++) {
    var arr = sections[s] && Array.isArray(sections[s].items) ? sections[s].items : []
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

function systemEntries() {
  return [
    { id: "logout", name: "Logout", label: "Logout", icon: "system-log-out", exec: "omarchy-system-logout" },
    { id: "lock", name: "Lock", label: "Lock", icon: "system-lock-screen", exec: "omarchy-system-lock" },
    { id: "shutdown", name: "Shutdown", label: "Shutdown", icon: "system-shutdown", exec: "omarchy-system-shutdown" }
  ]
}

function filterSystem(list, query) {
  var q = String(query || "").trim().toLowerCase()
  var rows = list || []
  if (!q) return rows.slice()
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    var hay = [row.label, row.name, row.id].join(" ").toLowerCase()
    if (hay.indexOf(q) >= 0) out.push(row)
  }
  return out
}

function makeSystemItem(row) {
  var id = String((row && row.id) || "action")
  var label = String((row && (row.label || row.name)) || id)
  return {
    id: "system-" + id,
    label: label,
    icon: String((row && row.icon) || "applications-system"),
    desktopId: "",
    pluginId: "",
    url: "",
    exec: String((row && row.exec) || ""),
    kind: "system"
  }
}

function systemPrompt(id) {
  var key = String(id || "")
  if (key.indexOf("system-") === 0) key = key.slice(7)
  var copy = {
    screensaver: {
      title: "Screensaver",
      warnings: [
        "The screensaver will cover the screen.",
        "Move the pointer or press a key to leave it."
      ]
    },
    lock: {
      title: "Lock",
      warnings: [
        "The screen will lock.",
        "Sign in again to continue. Open windows stay as they are."
      ]
    },
    suspend: {
      title: "Suspend",
      warnings: [
        "The computer will sleep.",
        "Wake it to continue. Unsaved work can be lost if the battery runs out."
      ]
    },
    hibernate: {
      title: "Hibernate",
      warnings: [
        "The session will be written to disk and the computer will power off.",
        "Wake it to continue. A failed wake can lose unsaved work."
      ]
    },
    logout: {
      title: "Logout",
      warnings: [
        "You will be logged out of this session.",
        "Open windows will close. Save your work before you proceed."
      ]
    },
    reboot: {
      title: "Reboot",
      warnings: [
        "The computer will restart.",
        "Open windows will close. Save your work before you proceed."
      ]
    },
    shutdown: {
      title: "Shutdown",
      warnings: [
        "The computer will shut down.",
        "Open windows will close. Save your work before you proceed."
      ]
    }
  }
  return copy[key] || {
    title: "System",
    warnings: ["This system action will run.", "Save your work before you proceed."]
  }
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
  if (!want.length || !mark.length) return next
  for (var i = 0; i < next.sections.length; i++) {
    var arr = next.sections[i].items
    for (var j = 0; j < arr.length; j++) {
      if (arr[j] && arr[j].id === want) arr[j].badge = mark
    }
  }
  return next
}

function renameItem(layout, itemId, label) {
  var next = cloneLayout(layout)
  var want = String(itemId || "")
  var name = String(label || "").trim()
  if (!want.length || !name.length) return next
  for (var i = 0; i < next.sections.length; i++) {
    var arr = next.sections[i].items
    for (var j = 0; j < arr.length; j++) {
      if (arr[j] && arr[j].id === want) arr[j].label = name
    }
  }
  return next
}

function stripId(layout, itemId) {
  var next = cloneLayout(layout)
  for (var i = 0; i < next.sections.length; i++) {
    var kept = []
    var arr = next.sections[i].items
    for (var j = 0; j < arr.length; j++) {
      if (arr[j].id !== itemId) kept.push(arr[j])
    }
    next.sections[i].items = kept
  }
  return next
}

function addItem(layout, section, item) {
  var idx = sectionIndex(section)
  var next = stripId(layout, item && item.id)
  if (!next.sections.length) next.sections.push(emptySection(0))
  if (idx >= next.sections.length) idx = next.sections.length - 1
  var copy = cloneItem(item)
  if (copy) next.sections[idx].items.push(copy)
  return next
}

function addItemClamped(layout, section, item, emptySpan) {
  var next = cloneLayout(layout)
  if (!next.sections.length) next.sections.push(emptySection(emptySpan))
  var idx = sectionIndex(section)
  if (idx >= next.sections.length) idx = next.sections.length - 1
  return addItem(next, idx, item)
}

function addItemGrowing(layout, section, item, emptySpan) {
  var idx = sectionIndex(section)
  if (idx >= maxSections()) idx = maxSections() - 1
  var next = ensureSections(layout, idx, emptySpan)
  return addItem(next, idx, item)
}

function removeItem(layout, itemId) {
  return stripId(layout, itemId)
}

function findItem(layout, itemId) {
  var loc = findItemLocation(layout, itemId)
  return loc ? loc.item : null
}

function findItemLocation(layout, itemId) {
  var sections = sectionsOf(layout)
  for (var i = 0; i < sections.length; i++) {
    var arr = sections[i] && Array.isArray(sections[i].items) ? sections[i].items : []
    for (var j = 0; j < arr.length; j++) {
      if (arr[j] && arr[j].id === itemId)
        return { section: i, index: j, item: arr[j] }
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
  var key = sectionIndex(section)
  var next = cloneLayout(layout)
  if (key < 0 || key >= next.sections.length) return layout
  var from = next.sections[loc.section].items
  var item = null
  for (var i = 0; i < from.length; i++) {
    if (from[i].id === itemId) {
      item = from[i]
      from.splice(i, 1)
      break
    }
  }
  if (!item) return layout
  var dest = next.sections[key].items
  var idx = Math.round(Number(index))
  if (isNaN(idx)) idx = dest.length
  if (loc.section === key && loc.index < idx) idx -= 1
  if (idx < 0) idx = 0
  if (idx > dest.length) idx = dest.length
  dest.splice(idx, 0, item)
  return next
}

function moveItemAtGrowing(layout, itemId, section, index, emptySpan, item) {
  var idx = sectionIndex(section)
  if (idx >= maxSections()) idx = maxSections() - 1
  var next = ensureSections(layout, idx, emptySpan)
  if (!findItem(next, itemId) && item) next = addItem(next, idx, item)
  return moveItemAt(next, itemId, idx, index)
}

function normalizeAppId(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\.desktop$/i, "")
    .replace(/\s+/g, "-")
}

// Hostnames used by Chrome web apps end in a public suffix. That suffix is
// not an application name: "plugins.omarchy.org" must not match the agent
// window "org.omarchy.agent" through the token "org".
function isPublicSuffix(label) {
  var tlds = {
    "org": true, "com": true, "net": true, "io": true, "dev": true,
    "app": true, "ai": true, "sh": true, "so": true, "me": true,
    "tv": true, "gg": true, "co": true, "uk": true, "de": true,
    "fr": true, "page": true, "site": true, "xyz": true, "id": true,
    "to": true, "cc": true, "ly": true, "be": true, "nl": true,
    "cloud": true, "design": true, "software": true, "edu": true,
    "gov": true, "info": true, "biz": true
  }
  return tlds[String(label || "")] === true
}

function appIdTokens(value) {
  var id = normalizeAppId(value)
  if (!id) return []
  var out = [id]
  var parts = id.split(".")
  if (parts.length > 1) {
    var last = parts[parts.length - 1]
    if (last && !isPublicSuffix(last) && out.indexOf(last) < 0) out.push(last)
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
      var shorter = left[i].length <= right[j].length ? left[i] : right[j]
      var longer = shorter === left[i] ? right[j] : left[i]
      if (isPublicSuffix(shorter)) continue
      if (longer.indexOf(shorter) >= 0) return true
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
  if (kind === "plugin" || kind === "web" || kind === "system") return []
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

hl.unbind("SUPER + mouse:272")
hl.unbind("mouse:272")
-- Super+left-drag moves a window. Over the dock, that chord moves the bar.
-- A plain left drag that starts on the dock also moves the bar. The dock is
-- only a thin strip, so the pointer enters the window above it immediately.
-- Hyprland keeps this gesture; the dock surface stops receiving motion then.
-- Clicks that stay on the dock are passed through, so icons still activate.
-- A press that starts on a separator never moves the bar. The dock publishes
-- those hit rectangles for the cursor check below.
-- This file must not start with "--": hyprctl eval treats that as its own flag.
if dock_edge_timer ~= nil then
  pcall(function() dock_edge_timer:set_enabled(false) end)
end
dock_edge_timer = nil
dock_edge_drag = nil

local function point_over_dock(pos)
  if not pos then return false end
  local layers = hl.get_layers() or {}
  for _, layer in ipairs(layers) do
    local ns = layer.namespace or ""
    if layer.mapped and (ns == "drace3000-bottom-dock" or ns == "drace3000-bottom-dock-edge") then
      if pos.x >= layer.x and pos.y >= layer.y and pos.x < layer.x + layer.w and pos.y < layer.y + layer.h then
        return true
      end
    end
  end
  return false
end

local function dock_cursor_over()
  local pos = hl.get_cursor_pos()
  if not pos then return false, nil end
  return point_over_dock(pos), pos
end

local function runtime_dir()
  local runtime = os.getenv("XDG_RUNTIME_DIR")
  if not runtime or runtime == "" then runtime = "/tmp" end
  return runtime
end

local function separator_hold_active()
  local f = io.open(runtime_dir() .. "/drace3000-bottom-dock-separator-hold", "r")
  if not f then return false end
  local body = f:read("*a") or ""
  f:close()
  return string.find(body, "1", 1, true) ~= nil
end

local function point_on_separator(pos)
  if not pos then return false end
  local f = io.open(runtime_dir() .. "/drace3000-bottom-dock-separators", "r")
  if not f then return false end
  local px, py = pos.x, pos.y
  for line in f:lines() do
    local x, y, w, h = line:match("^(%-?%d+)%s+(%-?%d+)%s+(%d+)%s+(%d+)$")
    if x then
      x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
      if px >= x and py >= y and px < x + w and py < y + h then
        f:close()
        return true
      end
    end
  end
  f:close()
  return false
end

local function dock_shell(args)
  hl.exec_cmd("omarchy-shell -q drace3000.bottom-dock " .. args)
end

local function release_separator_hold()
  if separator_hold_active() then
    dock_shell("separatorReleased")
  end
end

local function stop_timer()
  if dock_edge_timer ~= nil then
    pcall(function() dock_edge_timer:set_enabled(false) end)
    dock_edge_timer = nil
  end
end

local function finish_drag()
  local drag = dock_edge_drag
  dock_edge_drag = nil
  stop_timer()
  if not drag or drag == "window" then return end
  local pos = hl.get_cursor_pos()
  if not pos then return end
  dock_shell(string.format(
    "moveBarByDrag %d %d %d %d",
    math.floor(drag.x), math.floor(drag.y), math.floor(pos.x), math.floor(pos.y)
  ))
end

local function preview_drag()
  local drag = dock_edge_drag
  if not drag or drag == "window" then return end
  local now = hl.get_cursor_pos()
  if not now then return end
  dock_shell(string.format(
    "previewBarDrag %d %d %d %d",
    math.floor(drag.x), math.floor(drag.y), math.floor(now.x), math.floor(now.y)
  ))
end

local function super_held()
  return hl.is_key_down("Super_L") == true or hl.is_key_down("Super_R") == true
end

local function watch_drag(plain)
  local ticks = 0
  local saw_super = super_held()
  stop_timer()
  dock_edge_timer = hl.timer(function()
    if not dock_edge_drag or dock_edge_drag == "window" then
      stop_timer()
      return
    end
    ticks = ticks + 1
    local now = hl.get_cursor_pos()
    if now and not point_over_dock(now) then
      dock_edge_drag.left = true
    end
    if plain then
      if ticks > 200 then
        if dock_edge_drag.left then finish_drag() else
          dock_edge_drag = nil
          stop_timer()
        end
        return
      end
      if dock_edge_drag.left and ticks % 2 == 0 then
        preview_drag()
      end
      return
    end
    local super_down = super_held()
    if super_down then saw_super = true end
    if (saw_super and not super_down) or ticks > 200 then
      finish_drag()
      return
    end
    if now and ticks % 3 == 0 then
      preview_drag()
    end
  end, { timeout = 40, type = "repeat" })
end

hl.bind("SUPER + mouse:272", function()
  if dock_edge_drag == "window" then
    dock_edge_drag = nil
    return
  end
  if dock_edge_drag then
    return
  end

  local over, pos = dock_cursor_over()
  if over and pos and point_on_separator(pos) then
    return { ok = false }
  end
  if separator_hold_active() then
    release_separator_hold()
  end
  if not over or not pos then
    dock_edge_drag = "window"
    hl.dispatch(hl.dsp.window.drag())
    return
  end

  dock_edge_drag = { x = pos.x, y = pos.y, plain = false, left = false }
  watch_drag(false)
end, { auto_consuming = true, description = "Move window" })

hl.bind("SUPER + mouse:272", function()
  local moved = false
  if dock_edge_drag == "window" then
    dock_edge_drag = nil
  elseif dock_edge_drag then
    finish_drag()
    moved = true
  end
  if not moved then
    release_separator_hold()
  end
end, { release = true, auto_consuming = true })

-- Plain left button. Returning ok = false keeps the click on the dock, so an
-- icon still opens. The bar moves only after the pointer leaves the strip.
hl.bind("mouse:272", function()
  if dock_edge_drag and dock_edge_drag ~= "window" then
    return { ok = false }
  end
  local over, pos = dock_cursor_over()
  if over and pos and separator_hold_active() and not point_on_separator(pos) then
    release_separator_hold()
  end
  if not over or not pos or point_on_separator(pos) then
    return { ok = false }
  end
  dock_edge_drag = { x = pos.x, y = pos.y, plain = true, left = false }
  watch_drag(true)
  return { ok = false }
end, { auto_consuming = true, description = "Move task bar" })

hl.bind("mouse:272", function()
  local moved = false
  if dock_edge_drag and dock_edge_drag ~= "window" and dock_edge_drag.plain then
    if dock_edge_drag.left then
      finish_drag()
      moved = true
    else
      dock_edge_drag = nil
      stop_timer()
    end
  end
  if not moved then
    release_separator_hold()
  end
  return { ok = false }
end, { release = true, auto_consuming = true })

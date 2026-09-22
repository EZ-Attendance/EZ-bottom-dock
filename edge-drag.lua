hl.unbind("SUPER + mouse:272")
-- Super+left-drag moves a window. Over the dock, the same chord moves the bar.
-- Hyprland 0.56 does not report mouse buttons from hl.is_key_down (it checks
-- XKB keycodes, and a mouse press is stored as keyName "mouse:272" with
-- keycode 0). A second bind on button release commits the edge.
-- This file must not start with "--": hyprctl eval treats that as its own flag.
if dock_edge_timer ~= nil then
  pcall(function() dock_edge_timer:set_enabled(false) end)
end
dock_edge_timer = nil
dock_edge_drag = nil

local function dock_cursor_over()
  local pos = hl.get_cursor_pos()
  if not pos then return false, nil end
  local layers = hl.get_layers() or {}
  for _, layer in ipairs(layers) do
    local ns = layer.namespace or ""
    if layer.mapped and (ns == "drace3000-bottom-dock" or ns == "drace3000-bottom-dock-edge") then
      if pos.x >= layer.x and pos.y >= layer.y and pos.x < layer.x + layer.w and pos.y < layer.y + layer.h then
        return true, pos
      end
    end
  end
  return false, pos
end

local function dock_shell(args)
  hl.exec_cmd("omarchy-shell -q drace3000.bottom-dock " .. args)
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
  if not drag then return end
  local pos = hl.get_cursor_pos()
  if not pos then return end
  dock_shell(string.format(
    "moveBarByDrag %d %d %d %d",
    math.floor(drag.x), math.floor(drag.y), math.floor(pos.x), math.floor(pos.y)
  ))
end

local function super_held()
  return hl.is_key_down("Super_L") == true or hl.is_key_down("Super_R") == true
end

hl.bind("SUPER + mouse:272", function()
  -- window.drag() marks this bind release-pending, so mouse-up calls it again.
  if dock_edge_drag == "window" then
    dock_edge_drag = nil
    return
  end
  if dock_edge_drag then
    return
  end

  local over, pos = dock_cursor_over()
  if not over or not pos then
    dock_edge_drag = "window"
    hl.dispatch(hl.dsp.window.drag())
    return
  end

  dock_edge_drag = { x = pos.x, y = pos.y }
  local saw_super = super_held()
  local ticks = 0
  stop_timer()
  dock_edge_timer = hl.timer(function()
    if not dock_edge_drag or dock_edge_drag == "window" then
      stop_timer()
      return
    end
    ticks = ticks + 1
    local super_down = super_held()
    if super_down then saw_super = true end
    -- Mouse-up is handled by the release bind. If Super is let go first,
    -- or the release never arrives, commit from the latest cursor position.
    if (saw_super and not super_down) or ticks > 200 then
      finish_drag()
      return
    end
    local now = hl.get_cursor_pos()
    if now and ticks % 3 == 0 then
      dock_shell(string.format(
        "previewBarDrag %d %d %d %d",
        math.floor(dock_edge_drag.x), math.floor(dock_edge_drag.y), math.floor(now.x), math.floor(now.y)
      ))
    end
  end, { timeout = 40, type = "repeat" })
end, { description = "Move window" })

hl.bind("SUPER + mouse:272", function()
  if dock_edge_drag == "window" then
    dock_edge_drag = nil
    return
  end
  finish_drag()
end, { release = true })

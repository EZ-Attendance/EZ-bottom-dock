hl.unbind("SUPER + mouse:272")
if dock_edge_timer ~= nil then
  pcall(function() dock_edge_timer:set_enabled(false) end)
end
dock_edge_timer = nil

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

local function dock_finish_drag(x0, y0)
  if dock_edge_timer ~= nil then
    pcall(function() dock_edge_timer:set_enabled(false) end)
    dock_edge_timer = nil
  end
  local pos = hl.get_cursor_pos()
  if not pos then return end
  dock_shell(string.format("moveBarByDrag %d %d %d %d", math.floor(x0), math.floor(y0), math.floor(pos.x), math.floor(pos.y)))
end

hl.bind("SUPER + mouse:272", function()
  local over, pos = dock_cursor_over()
  if not over or not pos then
    hl.dispatch(hl.dsp.window.drag())
    return
  end
  local x0, y0 = pos.x, pos.y
  local seen_mouse = false
  local seen_super = false
  local ticks = 0
  if dock_edge_timer ~= nil then
    pcall(function() dock_edge_timer:set_enabled(false) end)
  end
  dock_edge_timer = hl.timer(function()
    ticks = ticks + 1
    local mouse_down = hl.is_key_down(272) == true
    local super_down = hl.is_key_down("Super_L") == true or hl.is_key_down("Super_R") == true
    if mouse_down then seen_mouse = true end
    if super_down then seen_super = true end
    local now = hl.get_cursor_pos()
    local released = (seen_mouse and not mouse_down) or (seen_super and not super_down) or ticks > 200
    if released then
      dock_finish_drag(x0, y0)
      return
    end
    if now and ticks % 3 == 0 then
      dock_shell(string.format("previewBarDrag %d %d %d %d", math.floor(x0), math.floor(y0), math.floor(now.x), math.floor(now.y)))
    end
  end, { timeout = 40, type = "repeat" })
end, { mouse = true, description = "Move window" })

-- Helpers pequenos sobre a API retida (retained-mode) do BUI.

local bui = require("bui")

local M = { bui = bui }

local function apply(node, key, value)
  if type(value) == "table" then
    local all_strings = #value > 0
    for _, item in ipairs(value) do
      if type(item) ~= "string" then
        all_strings = false
        break
      end
    end
    if all_strings then
      node:set_strs(key, value)
      return
    end
  end
  node:set(key, value)
end

function M.node(kind, props)
  local node = bui.Node(kind)
  assert(node, "tipo de node BUI desconhecido: " .. tostring(kind))

  props = props or {}
  local children = props.children

  for key, value in pairs(props) do
    if key ~= "children" then
      apply(node, key, value)
    end
  end

  if children then
    for _, child in ipairs(children) do
      node:add(child)
    end
  end

  return node
end

function M.add(parent, child, geom)
  parent:add(child)
  if geom then
    child:geom(bui.GEOM_PACK, geom)
  end
  return child
end

function M.pack(node, opts)
  node:geom(bui.GEOM_PACK, opts or {})
  return node
end

-- Containers
function M.frame(props)  return M.node("frame", props) end
function M.column(props) return M.node("column", props) end
function M.row(props)    return M.node("row", props) end
function M.scroll(props) return M.node("scroll", props) end
function M.grid(props)   return M.node("grid", props) end

function M.panel(title, props)
  props = props or {}
  local body_padding = props.body_padding
  props.body_padding = nil
  props.text = title

  local panel = M.node("panel", props)
  local body = panel:child(0)
  if body then
    body:set("padding", body_padding == nil and 6 or body_padding)
  end
  return panel, body
end

-- Texto
function M.label(text, props)
  props = props or {}
  props.text = text
  return M.node("label", props)
end

function M.title(text, props)
  props = props or {}
  props.font_scale = props.font_scale or 1.35
  return M.label(text, props)
end

function M.heading(text, props)
  props = props or {}
  props.font_scale = props.font_scale or 1.1
  return M.label(text, props)
end

function M.muted(text, props)
  props = props or {}
  props.text_color = props.text_color or 0xFF8A8A8A
  return M.label(text, props)
end

function M.separator(props)
  return M.node("separator", props)
end

-- Controles
function M.button(text, on_click, props)
  props = props or {}
  props.text = text
  local button = M.node("button", props)
  if on_click then
    button:on(bui.EV_CLICK, on_click)
  end
  return button
end

function M.icon_button(icon, tooltip, on_click, props)
  props = props or {}
  props.icon = bui.icon_id(icon)
  if tooltip then
    props.description = tooltip
  end
  local button = M.node("button", props)
  if on_click then
    button:on(bui.EV_CLICK, on_click)
  end
  return button
end

function M.field(text, control, props)
  props = props or {}
  local row = M.node("row", {
    padding = props.padding == nil and 2 or props.padding,
    spacing = props.spacing,
  })
  row:add(M.label(text, { weight = 0 }))
  control:set("weight", 1)
  row:add(control)
  return row
end

return M

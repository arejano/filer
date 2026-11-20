-- Tela inicial: raiz da UI.
-- Compõe componentes; não conhece janela, contexto nem ciclo de vida.

local ui = require("app.ui")
local status_bar = require("app.components.status_bar")
local left_panel = require("app.components.left_panel")
local right_panel = require("app.components.right_panel")
local main_panel = require("app.components.main_panel")

local M = { title = "Inicio", icon = "HOME" }

function M.build(deps)
  local page = ui.node("frame", { padding = 4 })

  local content = ui.node("column", { spacing = 4 })
  ui.add(page, content, { side = 0, expand = 1, fill = 3 })

  local left = left_panel.build({
    api = deps.api,
    state = deps.state,
  })

  local right = right_panel.build({
    api = deps.api,
    state = deps.state,
  })

  local main = main_panel.build({
    api = deps.api,
    state = deps.state,
  })

  -- REMOVE: Ui Mock

  local menu_box = ui.node("box")
  menu_box:add(ui.muted("menu"))
  content:add(menu_box)

  local body_row = ui.node("row", { expand = 1, fill = 3 })
  content:add(body_row)

  body_row:add(left.node)
  body_row:add(main.node)
  body_row:add(right.node)

  -- REMOVE: Ui Mock

  local status = status_bar.build({
    state = deps.state,
    theme = deps.theme,
    date = deps.date,
  })
  ui.add(content, status.node, { side = 1, fill = 1 })

  return {
    node = page,
    refs = { status_bar = status.refs },
    destroy = function()
      if status.destroy then
        status.destroy()
      end
    end,
  }
end

return M

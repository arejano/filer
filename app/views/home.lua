-- Tela base inicial.
-- Use este arquivo como ponto de partida para novas telas.

local bui = require("bui")
local ui = require("app.ui")

local M = { title = "Inicio", icon = "HOME" }

function M.build(api)
  local page = ui.node("scroll")
  local col = ui.node("column", { padding = 16, spacing = 12 })
  page:add(col)

  return {
    node = page,
    refs = {},
  }
end

return M

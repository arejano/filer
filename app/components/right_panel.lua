-- Contrato: build(deps) -> { node, refs, destroy? }
local ui = require("app.ui")

local M = {}

function M.build(deps)
  local state = assert(deps.state, "right_panel precisa de state")

  local col = ui.node("column", { padding = 6, spacing = 8 })
  local left_panel_box = ui.node("box")
  col:add(ui.muted("right_panel"))

  left_panel_box:add(col)

  local unsubscribes = {}
  local function watch(key, label)
    unsubscribes[#unsubscribes + 1] = state.on(function(changed, value)
      if changed == key then
        label:set("text", tostring(value))
      end
    end)
  end

  -- watch("status", status_label)
  -- watch("date", date_label)
  -- watch("theme", theme_label)

  return {
    node = left_panel_box,
    refs = {
      -- label = status_label,
      -- date_label = date_label,
      -- theme_label = theme_label,
    },
    destroy = function()
      for _, off in ipairs(unsubscribes) do
        off()
      end
    end,
  }
end

return M

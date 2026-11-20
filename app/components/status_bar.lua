-- Contrato: build(deps) -> { node, refs, destroy? }
local ui = require("app.ui")

local M = {}

function M.build(deps)
  local state = assert(deps.state, "status_bar precisa de state")

  if deps.theme then
    state.set("theme", deps.theme.current())
  end
  if deps.date and state.get("date") == state.defaults().date then
    state.set("date", deps.date():fmt("%d/%m/%Y"))
  end

  local status_label = ui.label(state.get("status"), { weight = 1 })
  local date_label = ui.label(state.get("date"), { weight = 0 })
  local theme_label = ui.label(state.get("theme"), { weight = 0 })

  local row = ui.node("row", { padding = 6, spacing = 8 })
  local status_box = ui.node("box")

  row:add(status_label)
  row:add(date_label)
  row:add(theme_label)

  status_box:add(row)

  local unsubscribes = {}
  local function watch(key, label)
    unsubscribes[#unsubscribes + 1] = state.on(function(changed, value)
      if changed == key then
        label:set("text", tostring(value))
      end
    end)
  end

  watch("status", status_label)
  watch("date", date_label)
  watch("theme", theme_label)

  return {
    node = status_box,
    refs = {
      label = status_label,
      date_label = date_label,
      theme_label = theme_label,
    },
    destroy = function()
      for _, off in ipairs(unsubscribes) do
        off()
      end
    end,
  }
end

return M

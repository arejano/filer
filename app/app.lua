-- Monta a janela e a arvore de widgets com a interface Blender do BUI.
--
-- `M.build(opts)` cria UI + contexto (util para testes e screenshots).
-- `M.open(opts)` cria a janela nativa.

local bui = require("bui")
local ui = require("app.ui")
local api_module = require("app.api")
local state = require("app.state")
local theme = require("app.theme")
local date = require("libs.date")

local M = {}

M.TITLE = "/home/noh"
M.WIDTH = 980
M.HEIGHT = 640

-- Registre novas paginas aqui. Cada modulo precisa de:
--   title, icon e build(api) -> { node = <widget>, refs = { ... } }
local VIEWS = {
  (require("app.views.home")),
}

function M.build(opts)
  opts = opts or {}

  local root = ui.node("frame", { padding = 0 })

  state.set("date", date():fmt("%d/%m/%Y"))

  local date_label = ui.label(state.get("date"))
  local status_label = ui.label(state.get("status"))
  local theme_label = ui.label(theme.current())

  state.on(function(key, value)
    if key == "status" then
      status_label:set("text", tostring(value))
    elseif key == "theme" then
      theme_label:set("text", tostring(value))
    elseif key == "date" then
      date_label:set("text", tostring(value))
    end
  end)

  local ctx
  local api = api_module.new({ views = VIEWS })

  -- Cabecalho
  local header_row = ui.node("row")
  header_row:geom(bui.GEOM_PACK, { padx0 = 8, padx1 = 8, pady0 = 8, pady1 = 4 })
  local header_box = ui.node("box")
  local header = ui.node("row", { padding = 2, spacing = 8 })
  -- header:add(ui.muted(M.TITLE, { weight = 3 }))

  header:add(bui.Node("text", { weight = 3 }))
  header:add(bui.Node("search", { weight = 1 }))
  header:add(ui.icon_button("LIGHT", "Alternar tema", function()
    api.toggle_theme()
  end, { wieght = 0 }))

  header_box:add(header)
  header_row:add(header_box)
  ui.add(root, header_row, { side = 0, fill = 1 })

  local refs = {}
  for _, view in ipairs(VIEWS) do
    local built = view.build(api)
    -- nav:add(built.node)
    refs[view.title] = built.refs
  end
  -- nav:set("current", 0)

  local body = ui.node("row", { padding = 0 })
  -- body:add(nav)
  ui.add(root, body, { side = 0, expand = 1, fill = 3 })
  -- ui.add(root, body, { side = 0, expand = 1, fill = 3 })
  body:geom(bui.GEOM_PACK, { padx0 = 8, padx1 = 8 })

  local box = ui.node("box", { weight = 1 })
  local box2 = ui.node("box", { weight = 3 })
  body:add(box)
  body:add(box2)

  root:add(body)
  -- Barra de status
  local status_bar = ui.node("row", { padding = 6, spacing = 8 })
  theme_label:set("weight", 0)
  status_bar:add(status_label)
  status_bar:add(date_label)
  status_bar:add(theme_label)
  ui.add(root, status_bar, { side = 1, fill = 1 })

  ctx = bui.Context(root)
  api.set_context(ctx)
  init_keybinds(ctx, api)

  state.set("theme", theme.current())

  return {
    ctx = ctx,
    root = root,
    nav = nav,
    api = api,
    refs = refs,
    status_label = status_label,
    date_label = date_label,
    theme_label = theme_label,
  }
end

function init_keybinds(ctx, api)
  ctx:bind("ctrl+q", function()
    bui.quit()
  end)
  ctx:bind("ctrl+t", function()
    api.toggle_theme()
  end)
  ctx:bind("ctrl+t", function()
    api.teste()
  end)
end

function M.open(opts)
  local app = M.build(opts)
  app.win = bui.Window(app.ctx, M.TITLE, M.WIDTH, M.HEIGHT)
  return app
end

return M

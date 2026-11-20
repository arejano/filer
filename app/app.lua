-- Bootstrap da aplicação: configura janela, API e delega a UI à view inicial.
--
-- `M.build(opts)` cria contexto e monta a view, sem criar widgets de tela.
-- `M.open(opts)` cria a janela nativa.

local bui = require("bui")
local ui = require("app.ui")
local api_module = require("app.api")
local state = require("app.state")
local theme = require("app.theme")
local date = require("libs.date")
local view = require("app.views.home")

local M = {}

M.TITLE = "/home/noh"
M.WIDTH = 980
M.HEIGHT = 640

local function bind_keys(ctx, api)
  ctx:bind("ctrl+q", function()
    bui.quit()
  end)
  ctx:bind("ctrl+t", function()
    api.toggle_theme()
  end)
  -- Atalho de debug separado: um bind repetido substitui o anterior.
  ctx:bind("ctrl+d", function()
    api.teste()
  end)
end

function M.build(opts)
  opts = opts or {}

  local initial_view = opts.view or view
  local api = opts.api or api_module.new({ views = { initial_view } })

  local deps = {
    api = api,
    state = opts.state or state,
    theme = opts.theme or theme,
    date = opts.date or date,
  }

  local screen = initial_view.build(deps)

  local root = ui.node("frame", { padding = 0 })
  ui.add(root, screen.node, { side = 0, expand = 1, fill = 3 })

  local ctx = bui.Context(root)
  api.set_context(ctx)
  bind_keys(ctx, api)

  return {
    ctx = ctx,
    root = root,
    api = api,
    screen = screen,
    refs = screen.refs,
  }
end

function M.open(opts)
  local app = M.build(opts)
  app.win = bui.Window(app.ctx, M.TITLE, M.WIDTH, M.HEIGHT)
  return app
end

return M

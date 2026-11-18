-- Monta a janela e a arvore de widgets com a interface Blender do BUI.
--
-- `M.build(opts)` cria UI + contexto (util para testes e screenshots).
-- `M.open(opts)` cria a janela nativa.

local bui = require("bui")
local ui = require("app.ui")
local state = require("app.state")
local theme = require("app.theme")

local M = {}

M.TITLE = "Base BUI Lua"
M.WIDTH = 980
M.HEIGHT = 640

-- Registre novas paginas aqui. Cada modulo precisa de:
--   title, icon e build(api) -> { node = <widget>, refs = { ... } }
local VIEWS = {
  (require("app.views.home")),
}

local function build_menu(api)
  local menu = ui.node("menubar")
  menu:set_menus({
    {
      text = "Arquivo",
      sub = {
        {
          text = "Sair",
          icon = bui.icon_id("QUIT"),
          shortcut = "Ctrl Q",
          fn = function()
            bui.quit()
          end,
        },
      },
    },
    {
      text = "Exibir",
      sub = {
        {
          text = "Alternar tema",
          shortcut = "Ctrl T",
          icon = bui.icon_id("LIGHT"),
          fn = api.toggle_theme,
        },
      },
    },
    {
      text = "Ajuda",
      sub = {
        {
          text = "Sobre",
          icon = bui.icon_id("INFO"),
          fn = function()
            api.set_status("Base BUI Lua - boilerplate funcional")
          end,
        },
      },
    },
  })
  return menu
end

function M.build(opts)
  opts = opts or {}

  local root = ui.node("frame", { padding = 0 })

  local status_label = ui.label(state.get("status"))
  local theme_label = ui.label(theme.current())

  state.on(function(key, value)
    if key == "status" then
      status_label:set("text", tostring(value))
    elseif key == "theme" then
      theme_label:set("text", tostring(value))
    end
  end)

  local ctx
  local api = {}

  function api.set_status(message)
    state.set("status", message)
  end

  function api.commit_edit()
    if ctx then
      ctx:focus_node(nil)
    end
  end

  function api.focus_node(node)
    if ctx then
      ctx:focus_node(node)
    end
  end

  function api.set_theme(name)
    if theme.set(name) then
      state.set("theme", name)
      api.set_status("Tema: " .. name)
    end
  end

  function api.toggle_theme()
    api.set_theme(theme.current() == "dark" and "light" or "dark")
  end

  -- Barra de menus (interface Blender)
  -- ui.add(root, build_menu(api), { side = 0, fill = 1 })

  -- Cabecalho
  local header = ui.node("row", { padding = 10, spacing = 8 })
  header:add(ui.title(M.TITLE, { weight = 1 }))
  header:add(ui.icon_button("LIGHT", "Alternar tema", function()
    api.toggle_theme()
  end, { weight = 0 }))
  ui.add(root, header, { side = 0, fill = 1 })

  -- Navegacao lateral + paginas
  local nav = ui.node("sidetabs", { weight = 1 })
  local titles, icons, groups = {}, {}, {}
  for i, view in ipairs(VIEWS) do
    titles[i] = view.title
    icons[i] = view.icon or "DOT"
    groups[i] = "0"
  end
  nav:set_strs("items", titles)
  nav:set_strs("icons", icons)
  nav:set_strs("groups", groups)

  local refs = {}
  for _, view in ipairs(VIEWS) do
    local built = view.build(api)
    nav:add(built.node)
    refs[view.title] = built.refs
  end
  nav:set("current", 0)

  function api.show_page(index)
    index = math.max(1, math.min(#VIEWS, index))
    nav:set("current", index - 1)
    api.set_status("Pagina: " .. VIEWS[index].title)
  end

  nav:on(bui.EV_CHANGE, function()
    local index = nav:get("value") + 1
    local view = VIEWS[index]
    if view then
      api.set_status("Pagina: " .. view.title)
    end
  end)

  local body = ui.node("row", { padding = 0 })
  body:add(nav)
  ui.add(root, body, { side = 0, expand = 1, fill = 3 })

  -- Barra de status
  local status_bar = ui.node("row", { padding = 6, spacing = 8 })
  theme_label:set("weight", 0)
  status_bar:add(status_label)
  status_bar:add(theme_label)
  ui.add(root, status_bar, { side = 1, fill = 1 })

  ctx = bui.Context(root)
  ctx:bind("ctrl+q", function()
    bui.quit()
  end)
  ctx:bind("ctrl+t", function()
    api.toggle_theme()
  end)

  state.set("theme", theme.current())

  return {
    ctx = ctx,
    root = root,
    nav = nav,
    api = api,
    refs = refs,
    status_label = status_label,
    theme_label = theme_label,
  }
end

function M.open(opts)
  local app = M.build(opts)
  app.win = bui.Window(app.ctx, M.TITLE, M.WIDTH, M.HEIGHT)
  return app
end

return M

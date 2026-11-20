-- API de acoes compartilhada entre views, atalhos e a aplicacao.
--
-- `M.new(opts)` cria uma instancia por build. O contexto BUI e associado
-- depois, pois so existe apos a arvore de widgets ser montada.

local state = require("app.state")
local theme = require("app.theme")
local filer = require("app.core.filer")

local M = {}

function M.new(opts)
  opts = opts or {}

  local views = opts.views or {}
  local ctx = opts.ctx

  local api = {
    filer = filer.buid(),
  }

  function api.set_context(value)
    ctx = value
    return api
  end

  function api.set_status(message)
    state.set("status", message)
  end

  function api.set_date(value)
    state.set("date", value)
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

  function api.show_page(index)
    index = math.max(1, math.min(#views, index))
    api.set_status("Pagina: " .. views[index].title)
  end

  function api.teste()
    api.filer:teste()
  end

  return api
end

return M

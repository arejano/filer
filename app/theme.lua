-- Tema do BUI: "dark" (padrao do Blender) ou "light".

local bui = require("bui")

local M = {}

function M.current()
  return bui.theme_name()
end

function M.set(name)
  if name ~= "dark" and name ~= "light" then
    return false
  end
  bui.set_theme(name)
  return true
end

function M.toggle()
  return M.set(M.current() == "dark" and "light" or "dark")
end

return M

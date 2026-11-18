-- Estado compartilhado da aplicacao.

local M = {}

local DEFAULTS = {
  status = "Pronto",
  theme = "dark",
  date = "00/00/0000",
}

local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = copy(v)
  end
  return out
end

local values = {}
for key, value in pairs(DEFAULTS) do
  values[key] = copy(value)
end

local listeners = {}

function M.get(key)
  return values[key]
end

function M.set(key, value)
  values[key] = value
  for _, listener in ipairs(listeners) do
    listener(key, value)
  end
end

function M.on(listener)
  listeners[#listeners + 1] = listener
  return function()
    for i, item in ipairs(listeners) do
      if item == listener then
        table.remove(listeners, i)
        return
      end
    end
  end
end

function M.reset()
  for key, value in pairs(DEFAULTS) do
    M.set(key, copy(value))
  end
end

function M.defaults()
  return copy(DEFAULTS)
end

return M

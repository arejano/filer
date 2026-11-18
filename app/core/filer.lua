local lfs = require("lfs")

local M = {}

local Filer = {}
Filer.__index = Filer

function M.buid(opts)
  opts = opts or {}
  local self = setmetatable({}, Filer)
  return self
end

function Filer:teste()
  print(self:get_config_dir())
  self:check_config_dir()
end

function Filer:get_config_dir()
  return os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
end

function Filer:check_config_dir()
  local config_patch = self:get_config_dir()

  local target = config_patch .. "/filer"
  print(target)

  local dir_attr = lfs.attributes(target)
  -- criar o dir de config
  if dir_attr == nil then
    lfs.mkdir(target)

    -- criar o arquivo inicial
    local file = assert(io.open(target .. "/config.lua", "w"))
    file:write("{}")
    file:close()
  end
end

return M

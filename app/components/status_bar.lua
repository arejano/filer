local M = {}

local StatusBarComponent = {}
StatusBarComponent.__index = StatusBarComponent

function M.buid(opts, api)
  opts = opts or {}

  local self = setmetatable({}, StatusBarComponent)
  self.api = api
end

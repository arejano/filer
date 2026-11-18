local M = {}

local FilerUtils = {}
FilerUtils.__index = FilerUtils

function M.buid(opts)
  opts = opts or {}
  local self = setmetatable({}, FilerUtils)
end

return M

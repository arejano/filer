-- Ponto de entrada: `make run` (ou build/base-bui-lua app/main.lua).

local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local root = here:match("^(.*)[/\\]") or here
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local bui = require("bui")
local app = require("app.app")

local instance = app.open()

if instance.win then
  instance.win:show()
  bui.run()
else
  local pixels, regions, width, height = instance.ctx:render(app.WIDTH, app.HEIGHT, 1)
  print(string.format(
    "Sem janela nativa. Render headless: %dx%d, %d regiao(oes), %d bytes",
    width, height, regions, #pixels
  ))
end

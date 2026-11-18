-- Renderiza a UI em modo headless e grava um PPM (RGB).
-- Uso: base-bui-lua --headless scripts/screenshot.lua [saida.ppm]

local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local root = here:match("^(.*)[/\\]") or here
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local app = require("app.app")

local output = (arg and arg[1]) or "screenshot.ppm"

local built = app.build()
local pixels, regions, width, height = built.ctx:render(app.WIDTH, app.HEIGHT, 1)

assert(pixels, "falha ao renderizar")
assert(#pixels == width * height * 4, "buffer de pixels inesperado")

local file = assert(io.open(output, "wb"), "nao consegui abrir " .. output)
file:write(string.format("P6\n%d %d\n255\n", width, height))

for y = 0, height - 1 do
  local row = {}
  local index = y * width * 4 + 1
  for _ = 0, width - 1 do
    row[#row + 1] = string.char(
      pixels:byte(index + 2),
      pixels:byte(index + 1),
      pixels:byte(index)
    )
    index = index + 4
  end
  file:write(table.concat(row))
end

file:close()

print(string.format("screenshot: %s (%dx%d, %d regiao(oes))", output, width, height, regions))

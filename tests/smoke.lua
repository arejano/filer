-- Teste de fumaça headless: monta a UI, renderiza e valida layout basico.

local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local root = here:match("^(.*)[/\\]") or here
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local app = require("app.app")
local state = require("app.state")
local theme = require("app.theme")

local function fail(message)
  error(message, 2)
end

local function check(condition, message)
  if not condition then fail(message) end
end

local function check_eq(actual, expected, message)
  if actual ~= expected then
    fail(string.format("%s (esperado %s, obtido %s)", message, tostring(expected), tostring(actual)))
  end
end

local built = app.build()
local pixels, regions, width, height = built.ctx:render(app.WIDTH, app.HEIGHT, 1)

check_eq(width, app.WIDTH, "largura do render")
check_eq(height, app.HEIGHT, "altura do render")
check_eq(#pixels, width * height * 4, "tamanho do buffer BGRA")
check(regions >= 1, "o primeiro frame deveria desenhar ao menos uma regiao")

local rx, ry, rw, rh = built.root:rect()
check_eq(rx, 0, "root.x")
check_eq(ry, 0, "root.y")
check_eq(rw, app.WIDTH, "root.w")
check_eq(rh, app.HEIGHT, "root.h")

local _, status_y = built.status_label:rect()
check(status_y > app.HEIGHT * 0.8, "a barra de status deveria ficar na parte de baixo")

local seen = {}
local colors = 0
for y = 0, height - 1, 19 do
  for x = 0, width - 1, 19 do
    local index = (y * width + x) * 4 + 1
    local key = pixels:sub(index, index + 3)
    if not seen[key] then
      seen[key] = true
      colors = colors + 1
    end
  end
end
check(colors > 3, "o render parece vazio (poucas cores distintas)")

-- Navegacao basica
built.api.set_status("Teste ok")
built.ctx:render(app.WIDTH, app.HEIGHT, 0)
check_eq(state.get("status"), "Teste ok", "status atualizado")

-- Data (libs.date integrada na barra de status)
check(state.get("date"):match("^%d%d/%d%d/%d%d%d%d$"), "data inicial")
built.api.set_date("01/01/2025")
check_eq(state.get("date"), "01/01/2025", "api.set_date")

-- Tema
local before = theme.current()
built.api.toggle_theme()
check(theme.current() ~= before, "toggle_theme deveria trocar o tema")
built.api.toggle_theme()
check_eq(theme.current(), before, "toggle_theme deveria voltar ao tema original")

print(string.format(
  "smoke ok: %dx%d, %d regiao(oes), %d cores, tema=%s",
  width, height, regions, colors, theme.current()
))

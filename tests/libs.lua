-- Testes das dependencias compartilhadas: lfs (modulo C embutido) e
-- libs.date (modulo Lua puro copiado do noh-control).

local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local root = here:match("^(.*)[/\\]") or here
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local function check_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s (esperado %s, obtido %s)", message,
      tostring(expected), tostring(actual)), 2)
  end
end

-- LuaFileSystem: compilado dentro do host como `app_lfs`.
local lfs = require("lfs")

check(type(lfs._VERSION) == "string", "lfs._VERSION")
check(lfs._VERSION:match("LuaFileSystem"), "versao do lfs: " .. tostring(lfs._VERSION))
check(lfs.attributes(".", "mode") == "directory", "lfs.attributes('.', 'mode')")

local iter, dir_obj = lfs.dir(".")
check(type(iter) == "function", "lfs.dir() retorna o iterador")
local entries = 0
for _ in iter, dir_obj do
  entries = entries + 1
end
check(entries > 0, "lfs.dir('.') deveria listar entradas")

-- date: modulo Lua em libs/date.lua, carregado via package.path.
local date = require("libs.date")

check(type(date) == "table" and type(date.version) == "number", "date.version")
local today = date()
check(type(today:fmt("%Y-%m-%d")) == "string", "date():fmt()")

local d = date(2026, 11, 18)
check_eq(d:fmt("%Y-%m-%d"), "2026-11-18", "date(y, m, d):fmt ISO")
check_eq(d:fmt("%d/%m/%Y"), "18/11/2026", "date(y, m, d):fmt pt-BR")

local parsed = date("2024-02-29T12:34:56")
check_eq(parsed:fmt("%Y-%m-%d %H:%M:%S"), "2024-02-29 12:34:56", "parse ISO")

check(date.isleapyear(2024) and not date.isleapyear(2023), "date.isleapyear")
check_eq(d:copy():adddays(1):fmt("%Y-%m-%d"), "2026-11-19", "adddays")
check_eq(date.diff(date(2026, 11, 20), date(2026, 11, 18)):spandays(), 2, "date.diff")

local utc = today:copy():toutc()
check(utc ~= nil and utc:copy():tolocal() ~= nil, "toutc/tolocal")

print(string.format("libs ok: %s, date %d, %d entradas em '.'",
  lfs._VERSION, date.version, entries))

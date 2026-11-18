# base_bui_lua — boilerplate BUI + Lua + SQLite

Boilerplate funcional baseado em [BUI](https://github.com/ppmpreetham/BUI) (Blender UI), **Lua 5.4**, **SQLite3** e **LuaFileSystem** embutidos.

A aplicação já inicia com a **interface Blender ativa** (barra de menus, cabeçalho, navegação lateral/sidetabs e barra de status) e uma **tela base** (`app/views/home.lua`) para servir de ponto de partida para novos projetos com a mesma estrutura.

## Requisitos

| Plataforma | Dependências |
|---|---|
| Linux | CMake 3.20+, compilador C/C++ (GCC/Clang), `libx11-dev` |
| macOS | CMake 3.20+, Xcode Command Line Tools |
| Windows | CMake 3.20+, Visual Studio Build Tools (MSVC) ou MinGW-w64 |

O primeiro build baixa e compila o BUI e as dependências Lua/SQLite (requer internet). Builds seguintes são incrementais.

## Uso

```sh
make            # configura + compila
make run        # abre a aplicação
```

Sem `make`:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target base-bui-lua -j
./build/base-bui-lua app/main.lua
```

### Comandos

```sh
make run                          # abre a janela
make run BUI_ARGS="--theme light" # tema claro
make run BUI_ARGS="--scale 1.25"  # escala da UI
make smoke                        # teste headless
make screenshot                   # gera build/screenshot.png
make clean                        # limpa objetos
make distclean                    # apaga build/ e dependências baixadas
```

## Estrutura

```
.
├── CMakeLists.txt        # build do host + dependências embutidas
├── Makefile              # atalhos
├── src/
│   └── main.c            # host Lua: registra bui, lsqlite3/sqlite3 e lfs
├── app/
│   ├── main.lua          # entrada
│   ├── app.lua           # monta janela, menu, navegação e status (API para views)
│   ├── ui.lua            # helpers de widgets/layout
│   ├── state.lua         # estado compartilhado
│   ├── theme.lua         # tema dark/light
│   └── views/
│       └── home.lua      # tela base (ponto de partida)
├── libs/
│   └── date.lua          # calculos de data/hora (copiado do noh-control)
├── scripts/
│   └── screenshot.lua    # render headless -> PPM
└── tests/
    ├── smoke.lua         # teste básico headless
    └── libs.lua          # testes de lfs e libs.date
```

## Adicionar uma nova tela

1. Crie `app/views/minha_tela.lua`:

```lua
local ui = require("app.ui")

local M = { title = "Minha tela", icon = "WORLD" }

function M.build(api)
  local page = ui.node("scroll")
  local col = ui.node("column", { padding = 12, spacing = 10 })
  page:add(col)

  col:add(ui.title("Minha tela"))
  col:add(ui.button("Acao", function()
    api.set_status("Feito!")
  end))

  return { node = page, refs = {} }
end

return M
```

2. Registre em `app/app.lua` na tabela `VIEWS`:

```lua
local VIEWS = {
  (require("app.views.home")),
  (require("app.views.minha_tela")),
}
```

## API disponível nas views

- `api.set_status(msg)` — atualiza a barra de status
- `api.set_theme("dark"|"light")` / `api.toggle_theme()` — altera tema
- `api.show_page(index)` — navega para uma aba
- `api.commit_edit()` — confirma edição de texto pendente
- `api.focus_node(node)` — foca um nó

## Módulos embutidos

- `require("bui")` — binding da UI
- `require("lsqlite3")` ou `require("sqlite3")` — SQLite3
- `require("lfs")` — LuaFileSystem (alvo `app_lfs` no CMake, embutido no host)

### Modulos Lua em `libs/`

O `libs/date.lua` e um modulo Lua puro (o mesmo do `noh-control`), carregado
pelo `package.path` ajustado em `app/main.lua`. Uso:

```lua
local date = require("libs.date")

print(date():fmt("%d/%m/%Y"))        -- data atual
print(date("2024-02-29"):fmt("${iso}"))
print(date.diff(date(2026, 11, 20), date(2026, 11, 18)):spandays()) -- 2.0
```

A data atual também aparece na barra de status e pode ser alterada com
`api.set_date(valor)`.

## Atalhos

- `Ctrl+T` — alterna tema
- `Ctrl+Q` — sai

## Licença

O BUI é distribuído sob **GPL-3.0**; aplicações que o embutem/linkam devem respeitar a GPL. Ajuste a licença do seu projeto conforme necessário.

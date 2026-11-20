# AGENTS.md

## Build / verificação

- `make` reconfigura o CMake e compila apenas o alvo `base-bui-lua`; o caminho do binário fica em `build/base-bui-lua.path`, então execuções pontuais usam `$(cat build/base-bui-lua.path) <flags> <script>`.
- O primeiro configure baixa BUI (v0.5.0), Lua 5.4.7, lsqlite3 e lfs (requer internet). Para BUI local/offline: `cmake -S . -B build -DFETCHCONTENT_SOURCE_DIR_BUI=/caminho/para/BUI` (tag via `BUI_GIT_TAG`); `make distclean` também apaga as fontes baixadas.
- Rode o app com `make run` (script `app/main.lua`); flags de UI em `BUI_ARGS="--theme light"`, argumentos do script em `ARGS="..."`.
- Os testes são scripts Lua executados pelo host compilado: `make smoke` roda `tests/smoke.lua` e depois `tests/libs.lua`. Um teste isolado: `$(cat build/base-bui-lua.path) --headless tests/libs.lua`. `--headless` define `BUI_HEADLESS=1`, sem necessidade de display. `make screenshot` gera `build/screenshot.ppm`; PNG só se `magick`/`convert` estiver instalado.
- `make smoke` passa. `app.build()` devolve `refs` da view inicial (`refs.status_bar.label`, `.date_label`, `.theme_label`) e `screen.destroy` para cancelar inscrições. `docs/tutorial_guia.md` descreve a arquitetura adotada.

## Entrypoints / responsabilidades

- `src/main.c` embute Lua e registra `bui`, `lsqlite3` (também como `sqlite3`) e `lfs`; execute Lua pelo host (`-e`, script ou REPL), não com um `lua` do sistema.
- Todo script que usa `require("app.*")` precisa ajustar `package.path` a partir de `debug.getinfo(1, "S")`, como em `app/main.lua`, `tests/*.lua` e `scripts/screenshot.lua`. `examples/*.lua` só usam `bui` e rodam direto: `$(cat build/base-bui-lua.path) --headless examples/hello.lua`.
- `app/app.lua` é o bootstrap/composition root: guarda `TITLE/WIDTH/HEIGHT`, cria API e contexto, chama a view inicial e anexa o nó dela ao `root`. `app/views/home.lua` é a raiz da UI e compõe `app/components/*`. `app/app_base.lua` é referência do boilerplate antigo; mudanças lá não têm efeito em runtime.
- Views e componentes seguem `build(deps) -> { node, refs, destroy? }`; componentes recebem `state`, `theme`, `date` ou `api` por injeção e não dependem de `app.app`, `bui.Window` nem `bui.run()`.
- `app/api.lua` é a API por build; `app/core/filer.lua` cuida da config em `$XDG_CONFIG_HOME/filer/config.lua`. `api.teste` está no Ctrl+D e a troca de tema no Ctrl+T: um bind repetido substitui o anterior no BUI.

## Particularidades do BUI

- Leia `docs/node-types.md` e `docs/geom.md` antes de adivinhar APIs de UI: eles foram derivados do `build/_deps/bui-src` vendido (fixado por `BUI_GIT_TAG`) e prevalecem sobre a documentação upstream.
- Armadilhas: geometria só gerencia filhos de `frame` (e canvas); `row`/`column`/`grid`/`box`/`panel` usam propriedades do nó (`weight`, `fill`, `columns`, `padding`). `fill` é bitmask (`1`=X, `2`=Y, `3`=XY), âncoras são numéricas (`N=1,S=2,W=4,E=8`), chaves com tipo errado são ignoradas silenciosamente, e não misture filhos PACK e GRID no mesmo frame.
- Tipos de nó são strings exatas (`ui.node` dá assert em tipo desconhecido). Propriedades de lista (`items`, `icons`, `groups`, `headers`) exigem `set_strs`; `app.ui.node` faz isso automaticamente para arrays de strings.

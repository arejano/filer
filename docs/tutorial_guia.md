# Tutorial-guia: como estruturar o fluxo Lua do filer

Este guia explica **como pensar a arquitetura** deste projeto, partindo do código que existe hoje e chegando ao modelo que você descreveu:

> `app/app.lua` deve ser o ponto de partida da **aplicação**, mas não deve montar UI.  
> `app/views/home.lua` deve ser o ponto de partida da **UI**.  
> A UI deve ser montada com **componentes** em `app/components/`.

> Nota: a Seção 2 registra o estado **anterior** à refatoração (o "antes"). As etapas 1–4 já foram aplicadas; o código atual segue o modelo das Seções 3–7, com `status_bar` também mostrando data e tema. A Etapa 5 (navegação/router) segue pendente. Os trechos marcados como **ilustração** estão simplificados em relação ao código real.

---

## 1. Antes de tudo: dois significados de "ponto inicial"

Há uma distinção importante:

| Arquivo | Papel |
|---|---|
| `app/main.lua` | **Primeiro arquivo Lua executado**. Ajusta `package.path`, chama `app.open()` e decide entre janela nativa e render headless. |
| `app/app.lua` | **Primeiro módulo da camada de aplicação**. É o *composition root*: cria API, contexto, janela e delega a construção da tela. |

Então sua ideia está correta, mas com uma nuance: `app/app.lua` não é o primeiro arquivo interpretado — `app/main.lua` é. O que você quer dizer é que `app/app.lua` é o **único lugar que sabe como a aplicação começa**. Isso é exatamente o papel de um *bootstrap*.

O fluxo real de execução hoje é:

```
make run
  -> build/base-bui-lua app/main.lua
       -> app/main.lua ajusta package.path
       -> require("app.app")
       -> app.open()
            -> app.build()
                 -> cria root, api, ctx, keybinds
                 -> chama home.build(api) ...
            -> bui.Window(ctx, TITLE, W, H)
       -> se houver janela: win:show() + bui.run()
       -> se não houver: ctx:render(W, H, 1)
```

Repare no último trecho: **quem decide mostrar a janela e chamar `bui.run()` é `app/main.lua`**, não uma view. Views e componentes nunca devem fazer isso.

---

## 2. Diagnóstico do código atual

Antes de propor o modelo alvo, vale entender o que o código faz hoje. Essas observações são a base da refatoração.

### 2.1 A `home` é construída, mas não aparece

Em `app/app.lua`:

```lua
for _, view in ipairs(VIEWS) do
  local built = view.build(api)
  -- nav:add(built.node)
  refs[view.title] = built.refs
end
```

O `built.node` da `home.lua` é criado e **descartado**. O `root` recebe apenas o `body` com dois `box` vazios:

```lua
local body = ui.node("row", { padding = 0 })
local box = ui.node("box", { weight = 1 })
local box2 = ui.node("box", { weight = 3 })
body:add(box)
body:add(box2)
root:add(body)
```

No BUI (modo retido), um nó só desenha se ele estiver na árvore ligada ao `bui.Context`. Esse é o primeiro erro conceitual a corrigir: **a view inicial precisa ser anexada ao `root`**.

### 2.2 `app/app.lua` ainda faz trabalho de UI e de apresentação

Hoje `app/app.lua` faz ao mesmo tempo:

- configuração (`TITLE`, `WIDTH`, `HEIGHT`) — ok, isso é bootstrap;
- criação do `root` e do `body` — UI;
- inicialização de `date`, `theme` e `status` no `state` — apresentação/estado;
- criação de labels — apresentação;
- keybinds — entrada de usuário;
- criação de `Context` e `Window` — ciclo de vida da aplicação.

Isso é uma violação clara de **Responsabilidade Única**. Qualquer mudança visual obriga a editar o bootstrap, e qualquer mudança de lifecycle obriga a editar a view.

### 2.3 Os labels comentados quebraram o smoke test

`tests/smoke.lua:39` ainda espera:

```lua
local _, status_y = built.status_label:rect()
```

Isso era o que quebrava `make smoke` antes da refatoração. O contrato foi corrigido: `app.build()` agora devolve `refs` da view inicial e o teste usa `built.refs.status_bar.label`.

Lição importante: **o retorno de `build()` é um contrato público**. Se você muda o que ele devolve, testes e consumidores precisam mudar junto.

### 2.4 Sinais pequenos que merecem atenção

- `app/views/home.lua` faz `require("bui")`, mas não usa `bui`. A view deve depender de `app.ui`, não do framework diretamente.
- `app/api.lua` faz `require("libs.inspect")`, mas não usa.
- `init_keybinds` em `app/app.lua` é declarada sem `local`, ou seja, vira global. Prefira `local function`.
- `M.buid(...)` aparece em `app/core/filer.lua`, `app/core/utils.lua` e `app/components/status_bar.lua`. Parece typo de `build`. Como `app/api.lua` chama `filer.buid()`, renomear exige atualizar os chamadores — é um contrato, mesmo com o nome estranho.

---

## 3. Modelo mental alvo: camadas

Pense em quatro camadas simples. Não são "pastas bonitas": cada uma tem uma razão diferente para mudar.

```
app/main.lua                 execução (host Lua + BUI)
  |
  v
app/app.lua                  aplicação / bootstrap / composition root
  |        |
  |        +--> app/api.lua  porta de casos de uso (o que a UI pode pedir)
  |                 |
  |                 +--> app/core/filer.lua  regras de domínio (config, arquivos)
  |                 +--> app/state.lua       estado compartilhado
  |                 +--> app/theme.lua       adaptador de tema
  |
  +--> app/views/home.lua     raiz da UI da tela inicial
            |
            +--> app/components/status_bar.lua   pedaço reutilizável de UI
            +--> app/components/...              futuros componentes
                     |
                     +--> app/ui.lua   adaptador de widgets do BUI
```

Regras de seta:

- a seta aponta de **quem depende** para **de quem se depende**;
- `views/` e `components/` **nunca** devem depender de `app/app.lua`;
- `core/` **nunca** deve depender de `ui`, `views` ou `bui`;
- o framework BUI fica isolado nos adaptadores (`app/ui.lua`, `app/theme.lua`) e no bootstrap (`Context`/`Window`).

### 3.1 Papel de cada camada

#### `app/main.lua` — execução

É o adaptador entre o host C e o mundo Lua. Faz três coisas:

1. ajusta `package.path` a partir do próprio caminho do script;
2. chama `app.open()`;
3. reage ao resultado: abre janela ou renderiza headless.

Não monta widgets. Não conhece `home`.

#### `app/app.lua` — aplicação

É o **composition root**. Responsabilidades:

- guardar configuração global da janela (`TITLE`, `WIDTH`, `HEIGHT`);
- criar a `api` (ou recebê-la, em testes);
- pedir à view inicial que construa sua árvore;
- anexar o nó da view ao `root`;
- criar `bui.Context(root)`;
- registrar keybinds globais;
- criar `bui.Window(...)` em `open()`;
- devolver `{ ctx, root, api, refs, ... }`.

O que ele **não** faz: criar labels, decidir padding de tela, escolher componentes, formatar data, montar `row`/`box` de conteúdo.

#### `app/views/home.lua` — raiz da UI

É o **ponto inicial da UI**. Responsabilidades:

- escolher quais componentes aparecem na tela inicial;
- definir o layout desses componentes;
- repassar dependências (`api`, `state`) para os componentes;
- devolver `{ node, refs, destroy? }`.

Ela sabe *quais* componentes existem, mas não sabe como a janela é aberta.

#### `app/components/*.lua` — peças reutilizáveis

Um componente é uma unidade pequena de apresentação:

- recebe dependências por parâmetro;
- cria seus próprios nós;
- reage a eventos/estado dentro do seu escopo;
- devolve `{ node, refs, destroy? }`;
- não conhece a janela, o `bui.run()`, nem outras views.

Exemplos naturais para o filer: `status_bar`, `breadcrumb`, `file_list`, `toolbar`, `path_input`.

#### `app/core/*.lua` — domínio

Regras que não dependem de UI: ler/escrever config, resolver caminhos, filtrar arquivos, montar modelos. `app/core/filer.lua` já começa esse papel com `get_config_dir()` e `check_config_dir()`.

#### `app/ui.lua` e `app/theme.lua` — adaptadores

Traduzem a API do BUI para uma API do projeto. É aqui que `bui.Node`, `set_strs`, `GEOM_PACK`, `set_theme` etc. ficam confines. Assim, a view fala `ui.node("frame", ...)`, não `bui.Node(...)`.

---

## 4. Contratos mínimos

Um dos maiores ganhos de SOLID em Lua é definir **contratos pequenos e repetíveis**. Você não precisa de classes, interfaces formais ou metatabelas complexas. Uma tabela com funções já basta.

### 4.1 Bootstrap

```lua
-- ilustração: formato alvo de app/app.lua
M.build(opts) -> { ctx, root, api, refs, screen }
M.open(opts)  -> build(opts) + bui.Window(...)
```

`opts` existe para injetar dependências em testes:

```lua
app.build({ api = api_falso, view = view_falsa })
```

### 4.2 View

```lua
-- ilustração
view.build(deps) -> {
  node    = <widget raiz da tela>,
  refs    = { nome_do_componente = { ... }, ... },
  destroy = function() ... end,   -- opcional
}
```

`deps` normalmente contém `api` e `state`.

### 4.3 Componente

Mesmo formato da view, em escala menor:

```lua
-- ilustração
component.build(deps) -> { node, refs, destroy? }
```

Essa igualdade é o que permite trocar um componente por outro sem mudar a view (Princípio da Substituição de Liskov aplicado de forma pragmática).

### 4.4 API

`app/api.lua` é a fachada de ações. Hoje ela expõe `set_status`, `set_date`, `set_theme`, `toggle_theme`, `show_page`, `commit_edit`, `focus_node`, `set_context`, `filer` e `teste`.

No modelo alvo, continue com isso, mas trate `api` como **porta de entrada**: a UI pede ações, e a implementação decide como executá-las. Se um componente só precisa saber o status, passe `state` — ou um subconjunto da api — em vez de passar a api inteira.

### 4.5 Estado

`app/state.lua` já tem o mecanismo de `on(listener)` com unsubscribe. Use-o:

```lua
local off = state.on(function(key, value) ... end)
-- ao destruir o componente:
off()
```

Esse `destroy` é importante: sem ele, listeners acumulam toda vez que a tela é reconstruída.

---

## 5. SOLID "mínimo", aplicado a este projeto

Não vá criar interfaces abstratas para tudo. A versão útil aqui é:

| Princípio | Como fica no filer |
|---|---|
| **S** — Responsabilidade Única | `app.lua` = ciclo de vida; `home.lua` = layout da tela; `status_bar.lua` = status; `filer.lua` = config/domínio. |
| **O** — Aberto/Fechado | Adicionar um componente não exige editar `app.lua`. Trocar a tela inicial exige editar só o composition root. |
| **L** — Substituição | Todo componente devolve `{ node, refs, destroy? }`; assim `status_bar` pode ser trocado por outro componente com o mesmo contrato. |
| **I** — Segregação de Interface | Injete só o que o módulo usa: um componente de status recebe `state`; um botão de tema recebe `api.toggle_theme`. |
| **D** — Inversão de Dependência | Views/componentes dependem de `api`/`state` injetados e de `app.ui`; não dependem de `bui.Window`, `bui.run()` ou `app.app`. |

### Por que `app.lua` não deve montar UI

Três motivos concretos:

1. **Mudança visual** passa a mexer no bootstrap — risco de quebrar janela/headless.
2. **Teste** não consegue isolar a tela: para testar um label você precisa construir a aplicação inteira.
3. **Reuso** some: um `status_bar` preso dentro de `app.lua` não pode ser usado em outra tela.

### Por que `home.lua` deve ser a raiz da UI

Porque ela é o lugar onde a tela "existe". Ela responde perguntas de composição:

- Quais componentes aparecem?
- Em que ordem?
- Quem ocupa o espaço restante?
- O que fica no rodapé?

Ela não responde perguntas de aplicação:

- Como a janela é criada?
- Quando `bui.run()` é chamado?
- Como os atalhos globais são registrados?

---

## 6. Plano de migração em etapas

A ordem abaixo reduz risco. Cada etapa pode ser verificada separadamente.

### Etapa 1 — Enxugar `app/app.lua`

Objetivo: transformar `build()` em orquestração.

O que muda conceitualmente:

- remover criação de `body`, `box`, `box2`;
- remover labels e `state.on` comentados;
- remover formatação de data;
- manter `TITLE/WIDTH/HEIGHT`;
- criar `api`;
- chamar `view.build({ api = api, state = state })`;
- **anexar** `screen.node` ao `root`;
- criar `ctx`, ligar `api.set_context(ctx)`, registrar keybinds;
- devolver `refs` vindos da view.

Keybinds: transforme `init_keybinds` em `local function bind_keys(ctx, api)`. Se quiser ir um passo além, crie `app/keys.lua` como adaptador de entrada — mas isso não é necessário para o mínimo SOLID.

Sobre o Ctrl+T duplicado: hoje há dois `ctx:bind("ctrl+t", ...)`; o segundo chama `api.teste()`, que cria `$XDG_CONFIG_HOME/filer/config.lua`. Mesmo sem decidir ainda como o BUI resolve binds repetidos, esse efeito colateral é surpreendente. Separe "tema" de "debug" antes de continuar.

### Etapa 2 — Fazer `home.lua` montar a tela

Objetivo: `home.build` devolver um `frame` com os componentes já dentro.

- `home` continua com `title` e `icon` (metadados úteis para navegação futura).
- `home` não faz `require("bui")`.
- `home` chama `status_bar.build(...)` e anexa o nó com `ui.add(...)`.
- `home` devolve `refs.status_bar` e um `destroy` que chama o `destroy` dos componentes.

### Etapa 3 — Criar componentes de verdade

Objetivo: `app/components/` deixar de ser esqueleto.

Hoje `status_bar.lua` tem só `M.buid(opts, api)` e não retorna nada. O formato alvo é o contrato da seção 4.3.

Ao criar novos componentes, use este checklist mental:

- [ ] recebe dependências por `deps`;
- [ ] devolve `node`, `refs`, `destroy?`;
- [ ] não faz `require("app.app")`;
- [ ] não chama `bui.Window`, `bui.run()` ou `bui.quit()`;
- [ ] usa `app.ui` para criar widgets;
- [ ] se assina eventos de `state`, devolve unsubscribe.

### Etapa 4 — Ajustar os testes para o novo contrato

Objetivo: trocar `built.status_label` por `built.refs.status_bar.label`.

O smoke test passa a verificar peças nomeadas, não labels globais da aplicação:

```lua
-- ilustração
local built = app.build()
local label = assert(built.refs.status_bar.label)
built.api.set_status("Teste ok")
assert(label:get("text") == "Teste ok")
```

Isso torna o teste mais estável: se o componente mudar de lugar na tela, o teste continua válido; se o contrato mudar, o teste falha no lugar certo.

### Etapa 5 — Só depois, navegação

Se amanhã você quiser mais telas, aí sim introduce um registro/router. Até lá, `"a view inicial é home"` é uma regra simples e suficiente.

Quando chegar esse momento, o registro pode ficar em `app/views/init.lua` ou `app/views/registry.lua`, e `app.lua` passa a escolher a view a partir de `opts.view`. Isso preserva o princípio Aberto/Fechado sem complicar o começo.

---

## 7. Exemplos ilustrativos completos

### 7.1 `app/app.lua` enxuto

```lua
-- Formato adotado — trecho simplificado
local bui = require("bui")
local ui = require("app.ui")
local api_module = require("app.api")
local state = require("app.state")
local view = require("app.views.home")

local M = {}

M.TITLE = "/home/noh"
M.WIDTH = 980
M.HEIGHT = 640

local function bind_keys(ctx, api)
  ctx:bind("ctrl+q", function() bui.quit() end)
  ctx:bind("ctrl+t", function() api.toggle_theme() end)
end

function M.build(opts)
  opts = opts or {}

  local api = opts.api or api_module.new({ views = { view } })
  local screen = (opts.view or view).build({
    api = api,
    state = state,
  })

  local root = ui.node("frame", { padding = 0 })
  ui.add(root, screen.node, { side = 0, expand = 1, fill = 3 })

  local ctx = bui.Context(root)
  api.set_context(ctx)
  bind_keys(ctx, api)

  return {
    ctx = ctx,
    root = root,
    api = api,
    screen = screen,
    refs = screen.refs,
  }
end

function M.open(opts)
  local app = M.build(opts)
  app.win = bui.Window(app.ctx, M.TITLE, M.WIDTH, M.HEIGHT)
  return app
end

return M
```

Pontos a notar:

- `app.lua` ainda usa `ui.node`/`ui.add` **uma vez**, só para anexar a raiz da tela ao frame da aplicação. Isso é responsabilidade de bootstrap, não layout de tela.
- `api_module.new({ views = { view } })` mantém `show_page` funcionando com uma view só.
- `refs` vem da view; o bootstrap não sabe o que há dentro dele.

### 7.2 `app/views/home.lua` como raiz da UI

```lua
-- Formato adotado — trecho simplificado
local ui = require("app.ui")
local status_bar = require("app.components.status_bar")

local M = { title = "Inicio", icon = "HOME" }

function M.build(deps)
  local page = ui.node("frame", { padding = 8 })

  local status = status_bar.build({ state = deps.state })
  ui.add(page, status.node, { side = 1, fill = 1 })

  return {
    node = page,
    refs = { status_bar = status.refs },
    destroy = function()
      if status.destroy then status.destroy() end
    end,
  }
end

return M
```

Aqui `home` decide: "minha tela tem uma barra de status no rodapé". Ela não decide como a janela abre.

### 7.3 `app/components/status_bar.lua`

```lua
-- Formato adotado — trecho simplificado
local ui = require("app.ui")

local M = {}

function M.build(deps)
  local state = assert(deps.state, "status_bar precisa de state")

  local label = ui.label(state.get("status"))
  local row = ui.node("row", { padding = 6, spacing = 8 })
  row:add(label)

  local off = state.on(function(key, value)
    if key == "status" then
      label:set("text", tostring(value))
    end
  end)

  return {
    node = row,
    refs = { label = label },
    destroy = off,
  }
end

return M
```

Repare que:

- não há `require("bui")`;
- o componente recebe `state`, não procura o estado global sozinho;
- `api.set_status("...")` continua funcionando, porque ele chama `state.set("status", ...)` e o listener do componente reage.

Se quiser incluir data e tema nesse componente, a responsabilidade continua sendo "apresentar o rodapé": basta inscrever-se em `date` e `theme` também e devolver um `destroy` que cancele as três inscrições.

---

## 8. Particularidades do BUI que afetam essa arquitetura

Mesmo com a arquitetura certa, o layout pode "não aparecer" por regras do BUI. Consulte sempre `docs/geom.md` e `docs/node-types.md` — eles foram derivados do fonte vendido em `build/_deps/bui-src` e são mais confiáveis que a documentação upstream.

Resumo do que mais importa aqui:

- **Nó não anexado não desenha.** Foi exatamente o caso da `home` atual.
- `ui.node(kind, props)` chama `bui.Node(kind)` e faz `assert` se o tipo não existe. Use `app.ui`, não `bui.Node` direto nas views.
- `ui.add(parent, child, geom)` é `parent:add(child)` seguido de `child:geom(bui.GEOM_PACK, geom)`. As opções são de `geom`, não do `ui.add`.
- `geom` só gerencia filhos de `frame` (e canvas). `row`, `column`, `grid`, `box` e `panel` usam propriedades do nó (`weight`, `fill`, `columns`, `padding`).
- `fill` é bitmask: `1` = X, `2` = Y, `3` = X|Y. Âncoras são numéricas: `N=1, S=2, W=4, E=8`. Chaves com tipo errado são **ignoradas silenciosamente**.
- Não misture filhos PACK e GRID no mesmo `frame`: eles se sobrepõem.
- Listas (`items`, `icons`, `groups`, `headers`) usam `set_strs`; `app.ui.node` já faz isso para arrays de strings.
- Em headless (`--headless`), não há janela: o render vem de `ctx:render(W, H, 1)`. Views devem funcionar tanto com janela quanto sem.

---

## 9. Como estudar este projeto na prática

Uma boa ordem de leitura:

1. `app/main.lua` — veja o ponto de execução e o fallback headless.
2. `src/main.c` — entenda quais módulos estão embutidos (`bui`, `lsqlite3`, `lfs`).
3. `app/app.lua` — compare o código atual com o modelo de bootstrap desta guia.
4. `app/api.lua`, `app/state.lua`, `app/theme.lua` — veja as dependências que podem ser injetadas.
5. `app/views/home.lua` e `app/components/status_bar.lua` — exercite o contrato `build -> { node, refs, destroy? }`.
6. `docs/node-types.md` — quando precisar de um widget novo.
7. `docs/geom.md` — quando o layout não sair como esperado.
8. `tests/smoke.lua` e `tests/libs.lua` — veja o que é verificável sem display.

Comandos úteis durante o estudo:

```sh
make                                      # compila
make run                                  # abre a janela
make smoke                                # headless: roda os dois testes
$(cat build/base-bui-lua.path) --headless tests/libs.lua   # um teste só
$(cat build/base-bui-lua.path) --headless examples/hello.lua  # exemplo isolado
make screenshot                           # gera build/screenshot.ppm
```

---

## 10. Checklist final antes de considerar a refatoração "no caminho certo"

- [ ] `app/app.lua` não cria labels, botões, colunas nem define layout de tela.
- [ ] `app/main.lua` continua sendo o único lugar que chama `bui.run()`.
- [ ] `app/views/home.lua` é a única view chamada pelo bootstrap inicial.
- [ ] `home.build()` anexa seu `node` ao `root` (direta ou indiretamente via `app.lua`).
- [ ] Componentes em `app/components/` devolvem `{ node, refs, destroy? }`.
- [ ] Nenhum componente faz `require("app.app")` nem cria `bui.Window`.
- [ ] Inscrições em `state.on()` são canceladas no `destroy`.
- [ ] `tests/smoke.lua` consulta `refs` em vez de labels globais.
- [ ] `docs/geom.md` foi consultado antes de ajustar `fill`, `side` ou `padding`.

Se esses itens estiverem ok, você terá uma arquitetura pequena, testável e fiel à sua ideia — sem excessos: é SOLID aplicado ao tamanho real deste projeto.

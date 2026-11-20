# Tipos de `Node` no BUI — catálogo completo

Este documento responde: **quais tipos posso passar para `bui.Node("tipo")` e para
que cada um serve normalmente.**

A lista definitiva é a tabela `g_classes` em
`build/_deps/bui-src/kit/intern/kit_core.c:151-165`. As listas em
`docs/c-api.md:92-95`, `bindings/lua/README.md:75-82` e no `README.md` principal
estão **desatualizadas/incompletas** — não use como fonte. Há **48 tipos**
registrados; apenas `filebrowser` é condicional (compilado com `BUI_FILEBROWSER`).

Documento complementar: [`docs/geom.md`](geom.md) cobre o layout dos filhos de
`frame`, que é um assunto separado destes tipos.

---

## 0. Como criar

```lua
local bui = require("bui")

local n = bui.Node("button")          -- API crua
n:set("text", "OK")

-- ou, no projeto, com props e children de uma vez:
local ui = require("app.ui")
local btn = ui.button("OK", function() ... end)
local col = ui.node("column", { padding = 8, spacing = 4, children = { btn } })
```

`bui.Node(name)` chama `BK_node_new(name)` → `bk_class_find(name)`, que compara a
**string exata** — não há aliases (`kit_core.c:167-175`,
`bindings/lua/src/bui_lua.c:286-289`). O helper `ui.node` faz `assert` se o tipo
não existe (`app/ui.lua:39-41`), então um typo falha rápido.

Todo node começa com `visible`, `enabled`, `emboss`, `weight = 1`, `spacing = -1`,
`rows = 5`, `split = 0.4`, `precision = 3`, `step = 0.1`, `vmin = 0`, `vmax = 1`
(`kit_core.c:177-197`).

### Propriedades e eventos comuns a todos

| Categoria | Chaves |
|---|---|
| Flags (bool) | `visible`, `enabled`, `align`, `emboss`, `vertical`, `icon_only`, `collapsed`, `integer`, `live`, `alpha`, `square`, `directory`, `line`, `bold`, `events`, `noscrollbar` |
| Números | `value`, `default`, `min`, `max`, `step`, `precision`, `weight`, `fill`, `factor`, `spacing`, `padding`, `columns`, `rows`, `height`, `tile`, `split`, `scroll`, `current`, `icon` |
| Texto | `text` (ou `title`), `label`, `description`, `placeholder`, `mask`, `suffix`, `category`, `icon`, `icon_on`, `text_align` |
| Cor | `color` (RGBA), `bg`, `text_color` |
| Listas (`set_strs`) | `items`, `icons`, `groups`, `headers` |
| Eventos | `EV_CHANGE`, `EV_CLICK`, `EV_CALL`, `EV_RENAME`, `EV_ACTIVATE`, `EV_TOGGLE`, `EV_SUBMIT`, `EV_VIEW`, `EV_SCROLL` |

Referências: `kit_core.c:766-783`, `:902-1062`, `:1153-1234`, `:1269-1355`;
`BUI_kit.h:92-116`. Eventos brutos (`EV_PRESS`, `EV_MOTION`, `EV_WHEEL`,
`EV_KEY`, `EV_CONFIGURE`...) exigem `node:set("events", 1)` (`kit_core.c:3442-3461`).

---

## 1. Mapa rápido (48 tipos)

| Grupo | Tipos |
|---|---|
| **Layout / containers** | `frame`, `column`, `row`, `split`, `grid`, `box`, `panel`, `tabs`, `sidetabs`, `sidebar`, `areaheader`, `scroll`, `scrollbar`, `nodeeditor`, `graphnode` |
| **Botões e estados** | `button`, `toggle`, `checkbox`, `radio`, `decorator`, `meter`, `progress`, `separator`, `label` |
| **Texto e números** | `text`, `search`, `hotkey`, `number`, `slider`, `textarea` |
| **Escolha e menus** | `dropdown`, `enum`, `swatch`, `popover`, `menubutton`, `menubar` |
| **Views e mídia** | `list`, `tree`, `gridview`, `image`, `video` |
| **Editores visuais e baixo nível** | `ramp`, `curve`, `normal`, `histogram`, `canvas`, `custom`, `filebrowser` |

---

## 2. Layout e containers

⚠️ **Divisão fundamental:** `frame` usa os managers Tk (`pack`/`grid`/`place`) via
`node:geom(...)`. `column`, `row`, `split`, `grid` e `box` têm **arranjo próprio**
controlado por propriedades do nó (`weight`, `fill`, `spacing`, `padding`,
`columns`) — `geom` neles não faz o que você espera. Ver `docs/geom.md`.

| Tipo | Uso normal | Props principais | Eventos / notas |
|---|---|---|---|
| `frame` | Contêiner bruto, quando você quer controlar cada filho com `pack`/`grid`/`place`. Raiz típica do app. | Genéricas; layout em `child:geom(...)` | Filho sem manager fica com retângulo zero e não desenha (`kit_frame.c:527-549`) |
| `column` | Pilha vertical: campos de formulário, seções, cartões. | `padding`, `spacing`, `fill` (filhos com `fill` dividem a altura excedente), `align` | `align=1` junta os widgets (sem gap, cantos conectados) (`kit_widgets.c:177-234,288`) |
| `row` | Pilha horizontal: barra de botões, cabeçalho, linha de propriedades. | `weight` por filho (divide a largura; `<=0` = natural), `spacing`, `padding`, `align` | É o tipo mais usado no `app/`; `weight` é do **filho** (`kit_widgets.c:291-361`) |
| `split` | Linha "rótulo / valor" de property editor: mesmo arranjo de `row`, mas gap fixo de `0.4 * unit` (estilo `layout.split` do Blender). | Mesmas de `row`; `spacing` sobrescreve o gap | Não há divisor arrastável nesta classe (`kit_widgets.c:148-160,363-364`) |
| `grid` | Grade simples com N colunas ignorando ordem de fluxo. | `columns` (default `2`), `padding` | O gap vem de `space_x/space_y`, **não** de `spacing` (`kit_widgets.c:366-423`) |
| `box` | Agrupamento visual com moldura/título e conteúdo empilhado — equivalente a `layout.box()` do Blender. | `text`, `padding` (default `0.3 * unit`), `factor` | Reusa o arranjo de `column` (`kit_widgets.c:425-441`) |
| `panel` | Painel colapsável com cabeçalho e corpo; base das abas de propriedades. | `text`/`title`, `description`, `icon`, `category`, `collapsed`, `padding` | O corpo é **filho 0** (`panel:child(0)`); clique alterna e emite `EV_CHANGE`; Ctrl+clique "solo", alça reordena (`kit_widgets.c:513-520,584-731`, `app/ui.lua:86-99`). Use `collapsed`, não `value` |
| `tabs` | Abas horizontais no topo; `items` = títulos, filhos = páginas. | `items`, `current`/`value` | `EV_CHANGE` com o índice; Ctrl+roda troca de aba (`kit_widgets.c:840-960`) |
| `sidetabs` | Barra vertical de ícones à esquerda, estilo Properties Editor. | `icons`, `groups` (`"1"` inicia um grupo), `items` (tooltip), filhos = páginas | É o tipo usado pela navegação do app (`app/app.lua:219-237`); `current` seleciona (`kit_widgets.c:1001-1149`) |
| `sidebar` | Região lateral do Blender: abas rotacionadas agrupadas por `category` dos filhos (até 32). | `category` (nos filhos), `current`/`value` | Só mostra abas se houver >1 categoria; `EV_CHANGE` por clique/Ctrl+roda (`kit_regions.c:103-255`) |
| `areaheader` | Cabeçalho de área do Blender: linha de menus no topo da região. | Filhos; um `separator` com `weight > 0` funciona como spacer | Altura fixa `26 * scale`; usado junto de `nodeeditor` (`kit_regions.c:309-384`) |
| `scroll` | Rolagem de **um único filho** (o filho 0) com clip e thumb. | `rows` (default `5`), `height`, `scroll`, `noscrollbar` | Roda e thumb; **não** emite `EV_SCROLL` — quem emite é `scrollbar` (`kit_widgets.c:1163-1277`) |
| `scrollbar` | Barra de rolagem Tk standalone, para controlar um valor externo. | `value`/`factor`, `first`/`last`, `vertical` (default `1`) | Emite `EV_SCROLL` (`a=0 moveto`, `a=1 units`); sozinha não rola conteúdo (`kit_widgets.c:1287-1408`) |
| `nodeeditor` | Editor de grafos (Shader/Geometry Nodes): pan, zoom, links, seleção. | `items` = links `"de saida entrada"`, `zoom`, `view_all`, `panx`, `pany` | `EV_CHANGE a=10` links, `a=11` delete; MMB pan, Ctrl+MMB/wheel zoom, Home, Ctrl+RMB corta (`kit_nodes.c:8-16,896-1245`) |
| `graphnode` | Nó filho de `nodeeditor`; sockets e posição. | `items` = `"i|Nome|tipo|valor"` / `"o|Nome|tipo"`, `nx`, `ny`, `nwidth`, `collapsed`, `selected` | `EV_CHANGE a=1 move, 2 select, 3 valor, 4 colapso` (`kit_nodes.c:8-16,307-374`) |

Exemplo de `sidetabs` no app (`app/app.lua:219-237`): `items` com os títulos,
`icons` com nomes Blender, `groups` marcando separadores e um filho por página.

---

## 3. Botões, estados e feedback

| Tipo | Uso normal | Props principais | Eventos / notas |
|---|---|---|---|
| `label` | Texto estático, com ícone opcional. | `text`, `icon`, `bold`, `text_align`, `text_color` | Sem eventos próprios (`kit_widgets.c:1453-1476`) |
| `separator` | Divisor entre seções. | `factor` (default `0.5`, controla a altura), `line` (linha fina) | Sem eventos (`kit_widgets.c:1478-1501`) |
| `progress` | Barra de progresso passiva (mostra `factor`, texto opcional). | `factor`, `text` | Não é valor editável; use `meter` se quiser faixas de cor (`kit_widgets.c:1503-1521`) |
| `meter` | **Medidor**, não botão: barra com faixas verde/amarelo/vermelho por `low`/`high`/`optimum`. | `value`, `low`, `high`, `optimum`, `min`/`max` | Não emite eventos (`kit_widgets.c:4074-4186`) |
| `button` | Ação pontual: Apply, OK, Delete. | `text`, `icon`, `emboss`, `active_default` | `EV_CLICK`; Enter/TKPEnter também ativa (`kit_widgets.c:1529-1613`) |
| `toggle` | Booleano com aparência de interruptor; comum em toolbars. | `value`, `label`, `icon`, `icon_on`, `emboss` | `EV_CHANGE`; arrastar alterna (`kit_widgets.c:1617-1771,1743`) |
| `checkbox` | Booleano quadrado de formulário. | Mesmas de `toggle` | `EV_CHANGE`; drift em grupo alterna vários (`kit_widgets.c:1710`) |
| `radio` | Escolha exclusiva: só liga, nunca desliga sozinho. | `value` (0/1), `label` | `EV_CHANGE` ao ligar; agrupe logicamente você mesmo (`kit_frame.c:619-673`) |
| `decorator` | Marcador de keyframe ao lado de uma propriedade (o pontinho do Blender). | `value`, `label`, `icon`, `icon_on` | `EV_CHANGE` (`kit_widgets.c:1767`) |

---

## 4. Texto e números

| Tipo | Uso normal | Props principais | Eventos / notas |
|---|---|---|---|
| `text` | Campo de texto de uma linha (nome, valor livre). | `value`, `placeholder`, `icon`, `mask`, `label`, `live` | `EV_CHANGE`; `EV_SUBMIT` exige `events` (`kit_widgets.c:2332-2516`) |
| `search` | **É um `text` especializado**: mesma base, com ícone de busca, `live=1` e placeholder padrão "Search". | Iguais a `text` | `EV_CHANGE` enquanto digita (`kit_widgets.c:2509-2525`) |
| `hotkey` | Captura a próxima combinação de teclas e mostra `"Ctrl Shift A"`. | `value`, `placeholder` | `EV_CHANGE`; modificadores sozinhos são ignorados, Esc cancela (`kit_widgets.c:2527-2661`) |
| `number` | Campo numérico com setas, clique para digitar e drag por pixel. | `min`, `max`, `step`, `precision`, `integer`, `suffix`, `value`, `default` | `EV_CHANGE`; Shift/Ctrl/Alt alteram granularidade (`kit_widgets.c:1785-2294`) |
| `slider` | Barra deslizante para intervalo (0..1 por padrão); mesma base numérica. | Mesmas de `number` (`min`, `max`, `value`...) | `EV_CHANGE`; drag proporcional com retorno do cursor (`kit_widgets.c:2318`) |
| `textarea` | Editor multilinha UTF-8 com caret, seleção, spans coloridos e scroll. | `value`, `rows`, `scroll`, `spans` | `EV_CHANGE` com `a=caret`; métodos `ta_*` (`kit_textarea.c:107-138,776-792`) |

`number` e `slider` compartilham `NUMBER_CLASS_COMMON`; `text` e `search`
compartilham `TEXT_CLASS_COMMON`. `hotkey` **não** usa essa base.

---

## 5. Escolha, cor e menus

| Tipo | Uso normal | Props principais | Eventos / notas |
|---|---|---|---|
| `dropdown` | Escolha em lista popup, quando há muitos itens. | `items`, `icons`, `value` = **índice**, `icon_only` | `EV_CHANGE` ao escolher (`kit_widgets.c:2698-2834`) |
| `enum` | Escolha com todos os segmentos visíveis inline (horizontal ou vertical). | `items`, `icons`, `value` = **índice**, `vertical`, `icon_only` | `EV_CHANGE` no clique do segmento (`kit_widgets.c:2836-2971`) |
| `swatch` | Amostra de cor RGBA que abre o seletor. | `color`/`value` (RGBA), `alpha`, `square` | `EV_CHANGE`; aceita hex por texto (`kit_widgets.c:2979-3092`) |
| `popover` | Botão que abre um **painel filho** em popup. | `text`, `icon`; o corpo são os filhos | **Não** emite `EV_CLICK` — abra reagindo a `EV_CHANGE`/estado do popup (`kit_widgets.c:3100-3157`) |
| `menubutton` | Botão que abre menu (File/Edit...), com submenus e atalhos. Itens via API, não `set`. | `text`, `icon`; itens com `node:set_menus({...})` | Itens com `fn`/`ref` disparam `EV_CALL`; `{text="-"}` é separador (`kit_widgets.c:3159-3257`, `examples/menus.lua:28-57`) |
| `menubar` | Barra de menu de topo: organiza `menubutton`s à esquerda e outros filhos à direita. | Genéricas | Sem eventos próprios (`kit_widgets.c:3259-3307`) |

Diferença prática: `enum` = poucas opções, sempre visíveis; `dropdown` = muitas
opções, abre popup; `menubutton` = comandos (não é um valor); `popover` = um
pedaço de UI arbitrário dentro de um popup.

---

## 6. Views e mídia

| Tipo | Uso normal | Props / API | Eventos / notas |
|---|---|---|---|
| `list` | Lista selecionável com colunas, ícones e renomeação. | `items`, `icons`, `headers`, `value` = índice, `rows`, `selmode`, `markN` | `EV_CHANGE` seleção, `EV_RENAME` (F2/duplo clique), `EV_CLICK` no header (`kit_views.c:188-496`) |
| `tree` | Árvore Outliner: itens com `ref`, expand/collapse e colunas de toggle. | `headers`, `icons` (pares off/on), `set_roots({...})`, `tree_row`, `toggleN` | `EV_CHANGE` traz o `ref` do item; `EV_TOGGLE` com `a`=coluna ou `-1` (`kit_views.c:533-1055`) |
| `gridview` | Grade de miniaturas/ícones (material browser). | `items`, `icons`, `tile` (default `4`), `height`, `set_grid_colors` | `EV_CHANGE` clique, `EV_ACTIVATE` duplo clique/Enter (`kit_views.c:1068-1285`) |
| `image` | Imagem PNG/JPEG/WebP/GIF/BMP/TGA/QOI/HDR/PNM/SVG com tamanho natural do header. | `set_image`, `set_imbuf`, `set_image_source(src, fit)`, `set_image_frame` | Sem eventos; decodes em worker threads (`image/draw.c:184-254`, `BUI_kit.h:289-315`) |
| `video` | Vídeo decodificado pelo SO, com play/pause/scrubber opcionais. | `set_video`, `controls`, `autoplay`, `loop` | Estado vem do callback do player, não de `EV_CHANGE` do node (`image/video.c:288-359`, `BUI_kit.h:352-392`) |

`list` indexa por posição; `tree` indexa por `ref` de item; `gridview` indexa por
posição e foca ativação por duplo clique.

---

## 7. Editores visuais, canvas e casos especiais

| Tipo | Uso normal | Props / API | Eventos / notas |
|---|---|---|---|
| `ramp` | Editor de rampa de cor (ColorRamp). | `interpolation` (0 Linear, 1 Ease, 2 BSpline, 3 Constant), `active`, `active_pos`; `ramp_*` | `EV_CHANGE` com `a=active`; Ctrl+clique adiciona stop, Delete remove (`kit_color.c:574-861`) |
| `curve` | Editor de curva com até 4 canais. | `channels`, `channel`, `selected`, `height`, `curve_*` | `EV_CHANGE` com `a=channel`; Ctrl+clique adiciona ponto, drag move, Delete remove (`kit_color.c:905-1226`) |
| `normal` | Bola de normal para vetores 3D. | `color`/`value` (RGBA **com sinal preservado**), `height` (default `4`) | `EV_CHANGE` ao arrastar; é a exceção à regra de clamp de cor (`kit_color.c:1264-1322`) |
| `histogram` | Histograma somente leitura. | `set_histogram(bins, n, channels)`, `height` | Sem eventos (`kit_color.c:1324-1401`) |
| `canvas` | Display list estilo Tk Canvas: retângulos, linhas, texto, imagens; filhos com `GEOM_PLACE`. | `canvas_set/delete/raise`, `bg`, `scroll`, `scroll_x` | Eventos brutos exigem `events`; não é interativo por padrão (`kit_frame.c:681-1010,1685`) |
| `custom` | Node cujo desenho e entrada são implementados pelo host (é assim que Dear ImGui roda). | `custom_set` com callbacks `draw/event/frame/free/natural_*`, `custom_request_frame`, `custom_set_cursor` | Recebe press/motion/wheel/keys com grab; sem evento BUI semântico próprio (`kit_custom.c:86-231`, `BUI_kit.h:467-534`) |
| `filebrowser` | Navegação de arquivos / diálogo abrir-salvar do Blender. **Condicional** (`#ifdef BUI_FILEBROWSER`). | `dir`, `file`, `button`, `search`, `filters`, `mode` (0 open, 1 save, 2 directory), `multiple`, `hidden`, `sort`; ações `execute`, `cancel`, `refresh`; leia `state`/`result` | `EV_SUBMIT` com `a=state`, `EV_CHANGE` ao trocar de pasta (`kit_filebrowser.c:482-673`, `BUI_kit.h:778-806`) |

---

## 8. Matriz "quando usar o quê"

| Preciso de... | Use |
|---|---|
| Controlar posição de cada filho com `side/fill/expand` | `frame` + `geom` (ver `docs/geom.md`) |
| Empilhar vertical / horizontal com pesos | `column` / `row` |
| Linha rótulo-valor com espaçamento padrão do Blender | `split` |
| Caixa agrupada com título | `box` ou `panel` (painel se precisar colapsar) |
| Alternar entre páginas | `tabs` (topo) / `sidetabs` (ícones) / `sidebar` (categorias) |
| Conteúdo grande com rolagem | `scroll` com **um** filho |
| Botão de ação / bool / exclusiva | `button` / `toggle` ou `checkbox` / `radio` |
| Número com drag ou slider | `number` / `slider` |
| Texto curto / busca / atalho / multilinha | `text` / `search` / `hotkey` / `textarea` |
| Poucas opções visíveis / muitas opções | `enum` / `dropdown` |
| Comando com submenu / painel popup | `menubutton` / `popover` |
| Lista / árvore / miniaturas | `list` / `tree` / `gridview` |
| Curva / rampa / vetor / histograma | `curve` / `ramp` / `normal` / `histogram` |
| Desenho próprio com display list | `canvas` |
| Integrar outro motor de UI (ImGui) | `custom` |
| Escolher arquivo | `filebrowser` (se habilitado no build) |

---

## 9. Métodos Lua específicos por tipo

Além de `set/get/set_strs/get_strs/on/geom/add/child...` (`bindings/lua/src/bui_node.c:981-1050`):

| Tipo | Métodos |
|---|---|
| `frame` | `grid_weight(axis, idx, weight, minsize)` |
| `scroll` | (usa apenas `set`) |
| `list`, `tree`, `gridview` | `set_roots`, `selected`, `select`, `row_count`, `tree_row`, `tree_row_rect`, `set_grid_colors` |
| `textarea` | `ta_insert`, `ta_delete`, `ta_spans`, `ta_see`, `text_at`, `caret`, `set_caret`, `selection`, `ta_set_selection` |
| `menubutton` | `set_menus({ text=, icon=, fn=, sub=, enabled=, checked= })` |
| `image` | `set_image`, `set_imbuf`, `set_image_source`, `set_image_frame` |
| `video` | `set_video` |
| `canvas` | `canvas_set`, `canvas_delete`, `canvas_raise`, `canvas_count` |
| `ramp` | `ramp_count`, `ramp_get`, `ramp_set`, `ramp_eval`, `ramp_set_color`, `ramp_active` |
| `curve` | `curve_count`, `curve_get`, `curve_set`, `curve_eval` |
| `histogram` | `set_histogram` |
| `custom` | `custom_set`, `custom_data`, `custom_request_frame`, `custom_set_cursor`, `custom_has_focus` |

Tipos sem API específica em Lua: `nodeeditor`, `graphnode`, `sidebar`,
`areaheader`, `scrollbar`, `filebrowser` — use `set`/`set_strs`/`get` e eventos.
Isso não significa que não funcionem: a classe existe no C, apenas não ganhou
wrappers dedicados na binding Lua.

---

## 10. Referências

- `build/_deps/bui-src/kit/intern/kit_core.c:151-175` — `g_classes` e busca por nome;
  `:177-197` — defaults; `:766-1355` — propriedades genéricas.
- `build/_deps/bui-src/kit/intern/kit_widgets.c` — layouts e widgets básicos.
- `build/_deps/bui-src/kit/intern/kit_frame.c` — `frame`, `radio`, `canvas`.
- `build/_deps/bui-src/kit/intern/kit_views.c` — `list`, `tree`, `gridview`.
- `build/_deps/bui-src/kit/intern/kit_color.c` — `ramp`, `curve`, `normal`, `histogram`.
- `build/_deps/bui-src/kit/intern/kit_nodes.c` — `nodeeditor`, `graphnode`.
- `build/_deps/bui-src/kit/intern/kit_regions.c` — `sidebar`, `areaheader`.
- `build/_deps/bui-src/kit/intern/kit_textarea.c`, `kit_menus.c`, `kit_custom.c`,
  `kit_filebrowser.c`, `image/draw.c`, `image/video.c` — demais tipos.
- `build/_deps/bui-src/bindings/lua/src/bui_node.c:325-352,519-528,981-1050` — API Lua.
- `build/_deps/bui-src/docs/components.md:74-215` — descrições em nível de componente.
- Exemplos locais: `examples/forms.lua`, `listview.lua`, `data_table.lua`, `menus.lua`,
  `menubar.lua`, `popover.lua`, `canvas.lua`, `textarea.lua`, `ramp.lua`, `curve.lua`,
  `histogram.lua`, `image_viewer.lua`, `filebrowser_demo.lua`.

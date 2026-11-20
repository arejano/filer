# Geometria BUI (`geom`) — referência completa

Documento escrito a partir do código do BUI vendido em `build/_deps/bui-src` (a fonte
de verdade, espelhando o Tk e o Blender). Quando uma linha é citada, ela é do estado
atual deste repositório.

---

## 1. Visão geral

`geom` é o sistema de layout dos filhos de um nó **container**. Ele é uma porta do
Tk para C: `pack`, `grid` e `place` (ver `kit/intern/kit_frame.c:1-10`). Os três
gerenciadores são selecionados no `node:geom(manager, opts)`:

| Manager | Constante Lua | Valor | Ideia |
|---|---|---|---|
| nenhum | `bui.GEOM_NONE` | `0` | filho não gerenciado: fica com `w=h=0`, não desenha nem recebe clique |
| pack | `bui.GEOM_PACK` | `1` | empilha faixas a partir de uma borda; o padrão deste projeto |
| grid | `bui.GEOM_GRID` | `2` | tabela de linhas/colunas com pesos |
| place | `bui.GEOM_PLACE` | `3` | posicionamento manual absoluto/relativo |

Definição em `kit/include/BUI_kit.h:273-287`; constantes Lua em
`bindings/lua/src/bui_lua.c:496-497`. **Atenção:** as constantes `ANCHOR_*` *não* são
exportadas para Lua — use os valores numéricos da seção 2.2.

### 1.1 Como a chamada chega ao C

```lua
node:geom(bui.GEOM_PACK, { side = 0, expand = 1, fill = 3 })
```

`bindings/lua/src/bui_node.c:325-344` faz, nesta ordem:

1. `BK_geom_set_manager(node, mgr)`;
2. itera a tabela de opções;
3. número → `BK_geom_set(node, chave, valor)`; booleano → `1.0`/`0.0`;
4. qualquer outro tipo é **ignorado silenciosamente**.

Não há validação de chave nem de faixa de valor: uma chave tipada errado simplesmente
não faz nada (`BK_geom_set`, `kit_frame.c:65-98`). Cada `BK_geom_set` chama
`bk_relayout(node)` (`:97`), então trocar uma opção já dispara o recálculo.

Valores inteiros são arredondados com `floor(v + 0.5)` (`:68`); apenas `x`, `y`,
`relx`, `rely`, `width`, `height`, `relwidth` e `relheight` mantêm float (`:85-92`).

### 1.2 O wrapper do projeto

`app/ui.lua:61-74`:

```lua
function M.add(parent, child, geom)
  parent:add(child)
  if geom then child:geom(bui.GEOM_PACK, geom) end
  return child
end

function M.pack(node, opts)
  node:geom(bui.GEOM_PACK, opts or {})
  return node
end
```

Ou seja: `ui.add(root, body, {...})` é exatamente `body:geom(bui.GEOM_PACK, {...})`
após o `add`. As opções não são do `ui.add`, são do pack do BUI.

### 1.3 Onde o `geom` atua — e onde não atua

O gerenciamento vale para filhos de **`frame`** (e `canvas`, conforme
`docs/c-api.md:79`). A lógica está em `frame_arrange` (`kit_frame.c:527-544`):
roda `do_pack`, depois `do_grid`, depois `do_place` para os filhos de cada manager.

Containers como `row`, `column`, `grid`, `box` e `panel` **não** são frames: têm
layout próprio, controlado por propriedades do nó, não por `geom`:

- `row`/`split`: `weight` por filho (`0` = largura natural) e `spacing`/`padding`
  (`kit_widgets.c:310-359`);
- `column`: `fill` por filho para dividir a altura excedente e `padding`
  (`kit_widgets.c:196-224`);
- `grid`: `columns`, `spacing`, `padding` (`kit_widgets.c:366+`).

⚠️ Não confundir `geom.fill` (bitmask do pack) com a propriedade do nó `fill`
usada por `column` (`kit_intern.h:393`): são coisas diferentes.

---

## 2. Todas as chaves de `geom`

A tabela abaixo cobre **todas** as chaves reconhecidas por `BK_geom_set`
(`kit_frame.c:65-98`) mais a ação especial `reset_place`.

| Chave | Manager | Tipo / padrão | Finalidade |
|---|---|---|---|
| `side` | pack | int `0..3`, padrão `0` | borda do pai de onde a faixa é retirada |
| `fill` | pack | bitmask `0..3`, padrão `0` | estica o filho dentro da faixa nos eixos marcados |
| `expand` | pack | `0`/`1`, padrão `0` | dá ao filho parte do espaço excedente da cavidade |
| `anchor` | pack, place | bits `N=1,S=2,W=4,E=8`, padrão `0` | posiciona o filho quando sobra espaço na faixa |
| `padx0` | todos | int `>=0`, padrão `0` | margem externa à esquerda |
| `padx1` | todos | int `>=0`, padrão `0` | margem externa à direita |
| `pady0` | todos | int `>=0`, padrão `0` | margem externa em cima |
| `pady1` | todos | int `>=0`, padrão `0` | margem externa embaixo |
| `ipadx` | todos | int `>=0`, padrão `0` | acrescenta ao pedido de largura natural |
| `ipady` | todos | int `>=0`, padrão `0` | acrescenta ao pedido de altura natural |
| `row` | grid | int `0..63`, padrão `0` | linha da célula |
| `column` | grid | int `0..63`, padrão `0` | coluna da célula |
| `rowspan` | grid | int `>=1`, padrão `1` | quantas linhas a célula ocupa |
| `columnspan` | grid | int `>=1`, padrão `1` | quantas colunas a célula ocupa |
| `sticky` | grid | bits `N=1,S=2,W=4,E=8`, padrão `0` | a quais bordas da célula o filho gruda |
| `x` | place | float, padrão `0` | deslocamento absoluto em X |
| `y` | place | float, padrão `0` | deslocamento absoluto em Y |
| `relx` | place | float, padrão `0` | fração da largura do pai em X (`0..1` usual) |
| `rely` | place | float, padrão `0` | fração da altura do pai em Y (`0..1` usual) |
| `width` | place | float, padrão `0` | largura absoluta (só vale se foi setada) |
| `height` | place | float, padrão `0` | altura absoluta (só vale se foi setada) |
| `relwidth` | place | float, padrão `0` | largura como fração do pai |
| `relheight` | place | float, padrão `0` | altura como fração do pai |
| `reqwidth` | qualquer | int, padrão `0` | força a largura natural (Tk `width=`) |
| `reqheight` | qualquer | int, padrão `0` | força a altura natural (Tk `height=`) |
| `reset_place` | place | ação | zera `x/y/relx/rely` e os flags de tamanho |

"Padrão" aqui é o valor do `calloc` do `BKGeom` (`geom_ensure`, `kit_frame.c:43-50`),
que só inicializa `rowspan=columnspan=1`.

### 2.1 Leitura de volta

`BK_geom_get` (`kit_frame.c:100-121`), exposto como `node:geom_get("chave")`, retorna
`manager`, `side`, `fill`, `expand`, `anchor`, `row`, `column`, `rowspan`,
`columnspan`, `sticky`, `reqwidth`, `reqheight`. **Não** retorna pads, `ipad`s nem
as coordenadas/tamanhos de `place` — para esses, devolva `0`.

### 2.2 Constantes numéricas

```lua
local N, S, W, E = 1, 2, 4, 8       -- BK_ANCHOR_*, BUI_kit.h:281
local fill_x, fill_y = 1, 2         -- fill = 3 é x|y
local sticky_we = W + E             -- 12: estica na horizontal no grid
```

---

## 3. PACK — o gerenciador do dia a dia

### 3.1 Motivação e modelo mental

É o `pack` do Tk (`kit_frame.c:4-6`). A "cavidade" é a área útil do pai, descontado
o `padding` do frame e o cabeçalho, se houver (`frame_insets`, `:190-195`). Cada
filho, na ordem em que foi adicionado, retira uma **faixa** (`parcel`) de um dos
lados da cavidade (`do_pack`, `:291-344`). Depois disso:

- `expand` decide quanto crescimento extra vai para a faixa;
- `fill`/`anchor` decidem onde e com que tamanho o filho fica dentro da faixa.

Essa ordem importa muito: o mesmo conjunto de filhos com ordens diferentes de
`add` produz layouts diferentes. É por isso que tabelas, listas e barras de rolagem
são empacotadas por último na maioria dos exemplos.

### 3.2 `side`

| Valor | Lado | Direção da faixa |
|---|---|---|
| `0` | topo | altura natural, ocupa toda a largura da cavidade |
| `1` | base | idem, grudado embaixo |
| `2` | esquerda | largura natural, ocupa toda a altura da cavidade |
| `3` | direita | idem, grudado à direita |

O código agrupa `side <= 1` como vertical (`:303`) e `side >= 2` como horizontal
(`:320`). Na medição do pai (`pack_request`, `:208-230`), filhos verticais somam
altura e definem a largura máxima; filhos horizontais somam largura e definem a
altura máxima.

Exemplo real (`app.lua:253-263`): `body` com `side=0, expand=1, fill=3` ocupa o
meio; `status_bar` com `side=1, fill=1` fica na base com altura natural.

### 3.3 `expand`

`expand=1` faz a faixa receber parte do espaço que sobrou na cavidade. O cálculo
está em `x_expansion` (`:232-259`) e `y_expansion` (`:261-288`):

- conta só os filhos **posteriores** ao atual (`from = i`) com `expand=1`;
- subtrai deles o tamanho já consumido;
- divide o restante igualmente: `min(cavidade / n, ...)` com arredondamento
  inteiro;
- `expand` é direcional: com `side=0/1` cresce a altura da faixa (`fh += y_expansion`,
  `:306-307`); com `side=2/3` cresce a largura (`fw += x_expansion`, `:323-324`).

Detalhes importantes:

- `expand` aumenta a **faixa**, não o widget. Para o widget crescer de fato,
  combine com `fill` na direção correspondente: `expand=1, fill=3`.
- Vários filhos com `expand` dividem o espaço; a divisão é feita com inteiros e
  sobras pequenas podem ser descartadas.
- O resultado é limitado à cavidade (`BK_CLAMP`, `:309`, `:326`).
- Sem `expand`, um widget com `fill` apenas preenche a própria faixa (tamanho
  natural), não o espaço livre do pai.

### 3.4 `fill` — bitmask

De `:337-342`:

```c
const int aw = MAX(0, fw - padx0 - padx1);
const int ah = MAX(0, fh - pady0 - pady1);
const int ww = ((g->fill & 1) || rw > aw) ? aw : rw;
const int hh = ((g->fill & 2) || rh > ah) ? ah : rh;
```

| `fill` | Bits | Efeito |
|---|---|---|
| `0` | — | tamanho natural; sobra é distribuída por `anchor` (padrão: centrado) |
| `1` | X | largura = faixa menos pads horizontais |
| `2` | Y | altura = faixa menos pads verticais |
| `3` | X\|Y | preenche a faixa inteira nos dois eixos |

Note a segunda condição: se o tamanho natural **pedido** (`rw`/`rh`, que já
inclui `ipad`) for maior que a faixa disponível, o widget é forçado a ocupar a
faixa mesmo sem o bit correspondente. O `fill` é uma autorização para crescer,
não para encolher abaixo do necessário.

`fill=2` sozinho, portanto, mantém a largura natural — combinação típica de
barra lateral/botão empacotado à direita; `fill=3` é o padrão para "conteúdo
principal".

### 3.5 `anchor`

Bits `N=1, S=2, W=4, E=8`; `0` = centro (`anchor_off`, `:132-143`):

- só o bit baixo (`N` ou `W`): offset `0` (gruda no início);
- só o bit alto (`S` ou `E`): offset `extra` (gruda no fim);
- nenhum ou ambos: `extra / 2` (centro).

No pack, ele só tem efeito **quando sobra espaço dentro da faixa**, ou seja,
geralmente com `fill=0` ou com `fill` em apenas um eixo.

### 3.6 Pads e ipads

- `padx0/padx1/pady0/pady1` são somados à faixa (`fw = rw + padx0 + padx1`,
  `:321`; `fh = rh + pady0 + pady1`, `:305`) e descontados antes de posicionar
  o filho (`:337`). São margens **externas**: o fundo do pai aparece nelas.
- `ipadx/ipady` são somados ao tamanho natural em `child_req` (`:123-130`) e ao
  pedido que o widget faz a `bk_natural`. São margens **internas** ao pedido de
  tamanho — o widget ocupa a área com esse extra já contado.
- O `padding` do **pai** é uma propriedade do nó (`frame_insets`, `:190-195`),
  não uma chave de `geom`. Ele reduz a cavidade para todos os filhos de uma vez.

### 3.7 Exemplos do projeto

```lua
-- app.lua:263 — barra de status: base, largura toda, altura natural
ui.add(root, status_bar, { side = 1, fill = 1 })

-- examples/dashboard.lua:32 — conteúdo: topo, herda o resto da cavidade
content_area:geom(bui.GEOM_PACK, { side = 0, expand = 1, fill = 3 })

-- painel lateral: altura toda, colado à direita
sidebar:geom(bui.GEOM_PACK, { side = 3, fill = 2 })
-- (dentro de um `row`, use a propriedade `weight` do nó, não `geom.fill`:
--  em examples/data_table.lua:41 o `geom` do rótulo é ignorado pelo row)
```

---

## 4. GRID

### 4.1 Motivação

Quando o layout é uma tabela (formulários, propriedades), o pack exigiria
containers aninhados para cada linha. O grid é o `tkGrid.c` (`kit_frame.c:7-9`):
cada filho declara `row`/`column`; o tamanho de cada linha/coluna vem do maior
filho; o espaço extra é distribuído por pesos configurados **no pai**.

### 4.2 Células

`row`, `column` começam em `0`; `rowspan`/`columnspan` começam em `1` e são
limitados a `GRID_MAX = 64` (`:151`, `:362-365`, `:475-476`). Valores negativos
de `row`/`column` são fixados em `0` no arranjo; `rowspan`/`columnspan` já são
limitados a `>= 1` em `BK_geom_set` (`:82-83`).

Medição (`grid_sizes`, `:348-405`): duas passagens — primeiro as células de
span 1 definem os mínimos de cada coluna/linha; depois as de span maior esticam
a última coluna/linha do seu alcance se o mínimo não bastar. `colmin`/`rowmin`
são impostos pelo segundo argumento de `grid_weight`.

### 4.3 Pesos (no pai, não no filho)

`BK_frame_grid_weight(frame, column_axis, index, weight, minsize)`
(`kit_frame.c:168-183`), em Lua:

```lua
frame:grid_weight(axis, index, weight, minsize)
-- axis: 1 = coluna, 0 = linha; minsize é opcional (padrão 0)
-- bindings/lua/src/bui_node.c:519-528
```

`distribute` (`:420-441`) reparte `w - soma_das_colunas` entre as colunas com
`weight > 0`, proporcionalmente; a sobra por arredondamento vai para a última
coluna ponderada. `weight = 0` mantém a coluna no tamanho natural.

### 4.4 `sticky`

Mesmos bits de `anchor`, com semântica de "grudar na borda da célula"
(`do_grid`, `:443-488`):

- `W|E` (`12`) → filho ocupa toda a largura da célula;
- `N|S` (`3`) → ocupa toda a altura;
- `W|E|N|S` (`15`) → ocupa a célula inteira;
- um único bit (ex.: `E = 8`) → tamanho natural alinhado àquela borda;
- `0` → tamanho natural centrado.

Pads são descontados da célula antes: `cw = colx[c1] - colx[c0] - padx0 - padx1`
(`:478-479`).

Equivalência Tk → BUI: `sticky="we"` → `sticky = 12`; `sticky="nsew"` → `15`.

### 4.5 Armadilhas

- `frame_measure` (`:510-525`) faz `max(pack_request, grid_request)` e
  `frame_arrange` roda `do_pack` **e** `do_grid` na mesma cavidade. Portanto,
  **não misture filhos PACK e GRID no mesmo frame**: eles vão se sobrepor.
- Filhos sem manager não participam e ficam invisíveis (`:540-549`).

---

## 5. PLACE

### 5.1 Motivação

Para sobreposições, marcadores, widgets ancorados a percentuais da janela ou
posições calculadas à mão — casos em que o fluxo de pack/grid não serve.

### 5.2 Fórmulas

De `do_place` (`kit_frame.c:490-508`), com `pw/ph` sendo a cavidade do pai:

```
x = relx * pw + x        y = rely * ph + y
w = relwidth * pw + width
h = relheight * ph + height
```

`width`/`height`/`relwidth`/`relheight` **só** entram se a chave correspondente
tiver sido setada (flags `HAS_W`, `HAS_H`, `HAS_RW`, `HAS_RH`, `:63`, `:89-92`,
`:497-502`). Se nenhuma foi, o tamanho natural é usado. Isso permite escrever
`{ x = 10 }` sem precisar declarar a largura.

`anchor` diz **qual ponto do filho** fica em `(x, y)`: o padrão em place é
`N|W = 5` (canto superior esquerdo), diferente do pack/grid, onde `0` = centro
(`:503-506`). O offset é subtraído da posição.

`place` não participa de `frame_measure` (`:515-518`): o pai **não cresce** por
causa de filhos place. Se o pai for dimensionado só por eles, use
`reqwidth`/`reqheight` ou defina o tamanho do pai.

`reset_place` (`:95`) zera `x`, `y`, `relx`, `rely` e limpa os flags de tamanho —
útil para reaproveitar um nó trocando de overlay.

---

## 6. Tamanho natural, `reqwidth`/`reqheight` e ipads

`bk_natural` (`kit/intern/kit_core.c:405-433`) mede cada widget uma vez por
"geração" de layout (`nat_gen`), cacheando `nat_w/nat_h`. Depois aplica:

```
se reqwidth  > 0: w = reqwidth
se reqheight > 0: h = reqheight
```

São o equivalente a `width=`/`height=` do Tk e funcionam com qualquer manager
(`BUI_kit.h:279`). Valores `<= 0` são ignorados. Como o resultado é cacheado,
mudar `reqwidth` invalida o cache pelo próprio `bk_relayout` disparado em
`BK_geom_set`.

`ipadx`/`ipady` entram antes do cache? Não: entram em `child_req`
(`kit_frame.c:123-130`), que chama `bk_natural` e **depois** soma `2*ipad` ao
pedido. Ou seja, o ipad não altera o cache do widget, apenas o tamanho que o
gerenciador considera ao calcular a faixa/célula.

---

## 7. Receitas rápidas

```lua
-- Cabeçalho: topo, largura toda, altura natural
ui.add(root, header, { side = 0, fill = 1 })

-- Conteúdo principal: topo, herda todo o espaço restante nos dois eixos
ui.add(root, body, { side = 0, expand = 1, fill = 3 })

-- Rodapé/base: altura natural, largura toda, margem superior
ui.add(root, status, { side = 1, fill = 1, pady0 = 6 })

-- Painel lateral direito: altura toda, largura natural, colado à direita
ui.add(root, sidebar, { side = 3, fill = 2 })

-- Botão pequeno sem esticar, alinhado à direita da faixa
ui.add(bar, button, { side = 0, anchor = 8 })  -- E

-- Formulário em grid: coluna 1 elástica, rótulos alinhados à direita
form:grid_weight(1, 1, 1.0)                     -- axis=1 → coluna 1
label:geom(bui.GEOM_GRID, { row = 0, column = 0, sticky = 4 })       -- W
field:geom(bui.GEOM_GRID, { row = 0, column = 1, sticky = 12 })      -- W|E

-- Overlay centralizado em 50% da largura, 20% da altura, tamanho natural
overlay:geom(bui.GEOM_PLACE, { relx = 0.5, rely = 0.2, anchor = 5 }) -- N|W
```

---

## 8. Resumo dos "por quês"

| Opção | Motivo de existir | Cavalgar com |
|---|---|---|
| `side` | define a direção do fluxo e a prioridade espacial (ordem de `add`) | `fill`, `expand` |
| `expand` | distribui espaço livre entre irmãos, em vez de deixar buraco | `fill` na mesma direção |
| `fill` | evita widgets "ilha" dentro de faixas grandes | `expand` para crescer de verdade |
| `anchor` | alinhar quando há sobra e não se quer preencher | `fill=0` ou parcial |
| `pad*` | separar irmãos sem criar frames espaçadores | qualquer manager |
| `ipad*` | dar folga interna ao pedido de tamanho do widget | qualquer manager |
| `row/col/span` | substituir pilhas de frames por uma tabela | `grid_weight` no pai, `sticky` |
| `sticky` | dizer quais bordas da célula o filho segue | `grid_weight` para a célula crescer |
| `x/y/rel*` | sobreposição e posições proporcionais | `anchor`, `reset_place` |
| `reqwidth/reqheight` | impor tamanho quando a medição natural não serve | qualquer manager |

---

## 9. Referências no código

- `app/ui.lua:61-74` — `ui.add` / `ui.pack`.
- `build/_deps/bui-src/kit/include/BUI_kit.h:273-287` — tabela oficial de chaves e constantes.
- `build/_deps/bui-src/kit/intern/kit_frame.c`
  - `:43-98` — `geom_ensure`, `BK_geom_set`, `BK_geom_get`;
  - `:123-143` — `child_req`, `anchor_off`;
  - `:208-230` — `pack_request`;
  - `:232-288` — `x_expansion` / `y_expansion`;
  - `:291-344` — `do_pack`;
  - `:348-441` — `grid_sizes`, `distribute`, `grid_weight`;
  - `:443-488` — `do_grid`;
  - `:490-508` — `do_place`;
  - `:510-549` — medição e arranjo do frame, filhos não gerenciados.
- `build/_deps/bui-src/kit/intern/kit_core.c:405-433` — `bk_natural`, `reqwidth`/`reqheight`.
- `build/_deps/bui-src/bindings/lua/src/bui_node.c:325-344` — `node:geom`;
  `:346-352` — `node:geom_get`; `:519-528` — `grid_weight`.
- `build/_deps/bui-src/bindings/lua/src/bui_lua.c:496-497` — constantes `GEOM_*`.
- `build/_deps/bui-src/docs/c-api.md:79` — resumo da API de geometria.
- `build/_deps/bui-src/docs/tkinter.md:63-79` — equivalência com `pack`/`grid` do Tk.

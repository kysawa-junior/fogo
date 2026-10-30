# Inventário — cards compactos + modal de detalhes

- **Status:** design aprovado pelo usuário
- **Date:** 2026-10-30

## Goal

Na tela de Inventário, os cards de Equipamento passam a ser compactos (para
enxergar muitos equipamentos de uma vez) e o clique no card abre um modal com
overlay exibindo **todas** as informações do equipamento.

## Current state

- `_EquipmentRow` (360×92+) mostra tile 36px, nome, categoria·id, coordenadas
  e chip de estado. A coordenada compete com o id e o estado na mesma linha.
- O clique no card faz `selectEquipment(id)` + `context.go('/')` — o mapa não
  renderiza painel de equipamento, então o clique "some" num estado sem UI.
- Não há `showDialog`/`showGeneralDialog` no projeto; a raiz é `WidgetsApp`
  (nenhum widget Material). O `Overlay` do Navigator é o caminho idiomático.
- API: só `GET /equipment` — sem endpoint de detalhe. Dados disponíveis:
  id, nome, categoria, localização, estado, `lastSeenAt`, `telemetry`,
  `roadId`.

## Approved design

1. **Card compacto** (`equipment_row.dart`, 360px, ~48px): tile de ícone 32px
   com tint do estado; linha 1 = nome (`subtitle`, elide); linha 2 =
   `categoria · id` (`caption`); `FogoChip` de estado à direita. Fundo
   `bg-surface` (`surfaceRaised`), **sem borda**; hover = `surfaceHover`;
   `Semantics(button: true)`.
   Coordenadas, última leitura, via e telemetria saem do card.
2. **Fundo da tela = `bg-canvas`** (`FogoColors.bg`). A lista NÃO usa
   `FogoPanel`: o box que agrupa os cards é transparente (sem vidro, sem
   sombra) — o canvas é o fundo, os cards `bg-surface` são as superfícies.
3. **Clique abre o modal.** O card não navega mais. O `Overlay` do Navigator
   recebe um `OverlayEntry` com barrier `bg` 72% (clique fora fecha), fade de
   entrada de 120ms (`TweenAnimationBuilder`), ESC fecha (`Focus` +
   `onKeyEvent`).
4. **Conteúdo do modal** (`equipment_details_modal.dart`, `part` da page),
   `FogoPanel(modal: true)` com 520px de largura máxima: cabeçalho (tile 40 +
   nome + id mono + X), chips de estado e categoria, grade de 2 colunas
   (Categoria | Estado · Localização | Via associada · Última atualização),
   telemetria como pares chave/valor em 2 colunas (vazio → "Sem telemetria
   disponível") e ações "Ver no mapa" (primary) + "Fechar" (ghost).
5. **"Ver no mapa"** fecha o modal e faz o que o clique fazia antes:
   `selectEquipment(id)` + `context.go('/')`.
6. **Dados**: só o domínio atual. A via aparece como `roadId` cru (sem
   acoplamento com `mapEngineProvider`).

## Accepted tradeoffs

- O card não mostra a última leitura nem coordenadas — a informação existe,
  mas exige um clique. Ganho de densidade compensa.
- A via aparece como id cru, não como nome legível.
- `EquipmentContextPanel` (órfão, do mapa) não é reutilizado: mostra dados
  "DEMO" e não é usado em lugar nenhum.
- Card de viatura fica fora do escopo.

## Validation

- `test/inventory_equipment_details_test.dart`: clique abre o modal com
  atributos + telemetria; ESC fecha; "Ver no mapa" navega e seleciona.
- `flutter analyze` e `flutter test` limpos.

## Risks and limits

- O `OverlayEntry` não é uma rota: não participates de back do Navigator
  (app desktop, sem botão voltar nativo) e não bloqueia o mapa atrás.
- `Equipment` continua sem `roadId` resolvido — quem quiser o nome da via
  precisa do motor do mapa.

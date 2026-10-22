# Arquitetura F.O.G.O.

## Organização

MVVM + feature-based. Estado de UI nunca vive em widgets puramente visuais;
fica em providers Riverpod (viewmodels) ou em domínio puro.

```text
lib/
├── main.dart                     # ProviderScope + FogoApp
├── app/
│   ├── fogo_app.dart             # WidgetsApp.router (sem MaterialApp)
│   └── router/app_router.dart    # GoRouter, CustomTransitionPage
├── core/
│   ├── constants/                # tiles, marca, disclaimers demo
│   ├── design_system/            # FogoColors, FogoSpacing, componentes
│   ├── theme/fogo_typography.dart
│   └── utils/geo_utils.dart      # haversine, hit-test ponto→polilinha
└── features/
    ├── map/                      # workspace: seleção, camadas, busca, painéis
    ├── road/                     # domínio viário + propostas de alteração
    ├── inventory/                # domínio de equipamentos + página de consulta
    └── predictive_city/          # módulo em preparação (honesto, sem simulação)
```

Cada feature segue: `domain/` (entidades e regras puras, testáveis),
`data/` (fontes — hoje `demo_*` claramente identificados), `providers/`
(viewmodels Riverpod) e `presentation/` (widgets).

## Regras de estado

- **Seleção**: `selectionProvider` (`NoSelection | RoadSelection | EquipmentSelection`).
- **Painel lateral**: `sidePanelProvider` (`hidden | context | proposals | proposalForm`)
  — um único slot; o painel contextual só renderiza o objeto da seleção atual.
- **Camadas**: `layersProvider` com registro `kLayerSpecs`; camadas sem fonte de
  dados real ficam **desabilitadas com motivo visível** (não decorativas).
- **Filtros**: conjuntos vazios = "todos". Afetam `visibleRoadsProvider` /
  `visibleEquipmentProvider`, consumidos pelo mapa e pela busca.
- Nota Riverpod 3: notifiers com estado **não fazem `ref.watch` dentro de
  `build`** (seriam reconstruídos e perderiam estado); dados derivados ficam
  em `Provider` separados.

## Fluxo de alteração viária (local)

`draft → pendingReview → (approved → applied | rejected)` com matriz de
transições em `RoadChangeProposal.canTransition`, validação de valores em
`RoadChangeValidation` e trilha de auditoria (`AuditEntry`) por transição.
`apply()` altera a via em `roadsProvider` (representação operacional).

**Limitações declaradas**: persistência, autorização (papéis revisor/aprovador)
e auditoria inviolável exigem backend — hoje tudo é local e o ator é
`usuario-local (demo)`.

## Integrações futuras (pontos preparados)

- `roadsProvider` / `equipmentProvider`: trocar a fonte demo por repositórios
  HTTP (`data/`), mantendo o contrato do notifier.
- Células ausentes são normais; corrupção de célula/manifesto produz status e
  erros tipados sem substituir a câmera nem buscar dados remotos.
- Camadas `agentsVehicles`, `alerts`, `riskAreas`: registrar fonte em
  `kLayerSpecs` e criar providers derivados.

## SDK cartográfico, dados offline e pitch

**Atual (implementado)** — `MapWorkspacePage` usa `packages/fogo_map_sdk`.
O pacote possui projeção Web Mercator, transformações inversas, câmera,
gestos, seleção por coordenada, carregamento/cache de células e desenho
`CustomPainter`. É um renderer regional de células OSM para F.O.G.O., não um
motor genérico MVT nem uma integração Mapbox.

- **Limites de propriedade**: o SDK é independente do app e da camada de estado.
  O app mantém rotas/busca/estado operacional, controles de região, persistência
  de centro e zoom e fornece overlays de rota/marcadores. O SDK publica estado
  de câmera/eventos imutáveis e fornece transformação compartilhada para os
  overlays. Pitch contínuo 0°–60° e bearing são transitórios e não são
  persistidos.
- **Fonte e cobertura**: o bundle local contém 58 células OSM e
  `assets/map/manifest.json`; cobertura limitada a Marília-SP, Vera Cruz-SP,
  Garça-SP e corredor. O manifesto define bounds geográficos e o clipping exato.
  Áreas/água/limites, ferrovias, vias, edifícios e POIs/rótulos são desenhados
  a partir das células; conteúdo vazio/fora da cobertura usa fundo `#0D0F14`.
- **Carregamento e cache**: carrega L0 visível e células L1 de edifícios a partir
  de zoom 15.5, com prefetch de 40% do viewport; poda estado fora dessa janela
  e limita LRU a 64 células L0 / 24 L1. A saída gzip por célula tem limite de
  8 MiB. Ausência de célula é normal; dados corrompidos viram erros tipados e
  não impedem a renderização das demais células válidas.
- **Desenho e overlays**: camadas OSM e geometria geográfica são recortadas aos
  bounds exatos do manifesto. Preservam-se ordem/filtro viário, casing/fill,
  pontes/túneis, marcas de mão única, colisão de rótulos e controles de
  edificações/rótulos. Larguras de vias, polilinhas e contornos de marcador são
  expressos em pixels de tela. Rota/marcadores e atribuição OSM ficam acima da
  base, inclusive fora da cobertura.
- **Rede**: SDK e mapa-base não fazem requests de rede. Busca Nominatim e
  roteamento OSRM são integrações separadas do app e continuam dependentes de
  rede.
- **Câmera 3D e curvas**: projeção pinhole perspectiva própria (ADR-0005),
  com clipping de near-plane para geometria que cruza o horizonte. Vias,
  ferrovias, hidrografia linear e rotas passam por spline `FogoSmooth`
  (Catmull-Rom que preserva extremos e cantos vivos) antes do desenho, sem
  mover nós compartilhados de cruzamentos.
- **Generalização cartográfica (ADR-0006)**: larguras de via vêm de rampas
  contínuas por classe/zoom (`FogoCartography`, buckets de 1/4 de zoom) com
  halo de casing proporcional à largura; buffers de via são construídos em
  metros Mercator absolutos e cacheados por bucket — pan, rotação e pitch
  reutilizam a geometria. Em pitch, as vias pintam antes das extrusões
  ordenadas por profundidade (paredes próximas ocluem corretamente as ruas
  atrás). Setas de mão única respeitam cruzamentos (exclusão de borda, piso
  de 120 px, teto de 250 por quadro). Rótulos de lugar seguem faixas por
  tipo com orçamento por prioridade (cidade > vila > bairro). Fills de áreas
  levam um fio de contorno da mesma cor para fechar seams de antialiasing
  entre polígonos vizinhos.
- **Estilo e altura**: paleta noturna v3 é inspirada na hierarquia visual do
  Mapbox Standard night (fitas de via claras sobre terreno azul quase
  preto), mas os tokens são próprios do F.O.G.O.; não há alegação de
  equivalência exata. A partir de pitch, extrusão usa `height` numérico real
  quando existe; sem altura real, o motor estima alturas determinísticas
  (por área da pegada, com jitter estável) apenas no render — células e
  manifesto ficam intactos e `FogoMapStyle.estimateBuildingHeights = false`
  restringe a extrusão às alturas reais (ADR-0005). `building:levels` nunca
  vira altura. Gramática, unidades e contadores estão em
  [`tool/map_data/README.md`](../tool/map_data/README.md).
- **Portabilidade**: o pacote SDK evita `dart:io`, canais/plugins nativos,
  `flutter_map`, estado do app e rede de mapa. `compute` usa isolate onde
  suportado; no Flutter Web executa no mesmo event loop. Isso não declara
  suporte Web para o app F.O.G.O.

Detalhes da API pública e exemplos: [`packages/fogo_map_sdk/README.md`](../packages/fogo_map_sdk/README.md).
Decisão vigente: [ADR-0004](adr/ADR-0004-fogo-map-sdk.md), que supersede
historicamente [ADR-0003](adr/ADR-0003-offline-hybrid-map.md).

## Roteamento real (modelo Fleetbase)

O motor de roteamento opera sobre a **rede viária real** (OSRM; dados OSM):

| Papel | Implementação |
|---|---|
| Routing Service (geometria/ETA) | `OsrmRouteService` — `/route/v1/driving` |
| Distance Matrix (custo real) | `OsrmRouteService` — `/table/v1/driving` |
| Route Optimization Engine | `RouteOptimizer` (NN + 2-opt) com custo injetável |
| Renderização | polyline + badges sobre o mapa |

Paradas são criadas pelo usuário (botão direito/toque longo) — dado real.
Falha de serviço = erro explícito na UI; **nunca** fallback com linha reta
apresentado como real (haversine existe apenas como custo de teste).
`OSRM_BASE_URL` (dart-define) aponta para instância própria em produção.

## Evolução

- Places de backend sobre os contratos existentes (`Place`/propostas).
- OSRM/Valhalla auto-hospedado + geocoder próprio.
- Maior cobertura geográfica ou novos formatos exigem escopo e decisão
  arquitetural próprios; o SDK atual permanece regional e baseado em células.

## Dados

- **Base cartográfica real** (`assets/map/`): 58 células OSM locais e
  `manifest.json`, gerados por `tool/map_data/` — cobertura Marília-SP,
  Vera Cruz-SP, Garça-SP e corredor. Consulte o manifesto para bounds,
  contagens, fonte e data de geração.
- **Operacional**: sem dados fictícios por padrão. Vias (propostas de
  alteração) e equipamentos (inventário) aguardam backend — providers vazios,
  testes injetam fixtures via `RoadsNotifier(seed: ...)`.
- Paradas de rota: criadas pelo usuário no mapa (dado real).

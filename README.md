# F.O.G.O. — Plataforma de inteligência e controle urbano

Aplicação Flutter nativa de central operacional urbana orientada a mapas reais.
A rota `/` é a Central de Operações no Motor 3D próprio: extrato OSM único
(OpenStreetMap XML) convertido em malhas 3D pelo motor — sem WebView, sem
Mapbox GL JS, sem tiles Mapbox. A base regional empacotada tem as três cidades
juntas (Marília-SP, Vera Cruz-SP e Garça-SP + corredor); a navegação inferior
centraliza a câmera em cada cidade.

**Extrato OSM único da região (`.osm.gz`)** — processado localmente a partir
do PBF já presente em `tool/map_data/raw/` (ver `tool/map_data/README.md`).
Nenhum dado operacional fictício é carregado por padrão.

> Atribuição: dados © OpenStreetMap contributors (visível no rodapé).
> Busca geográfica real via Nominatim/OSM.

## Capturas de tela

| Captura 1 | Captura 2 |
| :--------: | :--------: |
| ![Captura de tela 1 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-21-42.png) | ![Captura de tela 2 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-22-08.png) |
| ![Captura de tela 3 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-22-19.png) | ![Captura de tela 4 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-22-47.png) |
| ![Captura de tela 5 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-23-33.png) | ![Captura de tela 6 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-23-51.png) |
| ![Captura de tela 7 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-24-11.png) | ![Captura de tela 8 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-24-23.png) |
| ![Captura de tela 9 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-24-31.png) | ![Captura de tela 10 do aplicativo F.O.G.O.](screenshots/Captura%20de%20tela%20de%202026-10-30%2015-25-11.png) |

## Módulos

| Rota          | Módulo               | Estado nesta etapa                                        |
| ------------- | -------------------- | --------------------------------------------------------- |
| `/`           | Central de Operações | Motor 3D F.O.G.O. com extrato OSM regional único          |
| `/inventory`  | Inventário Inteligente | Vazio (fonte de equipamentos aguarda backend); consulta pronta |
| `/predictive` | Cidade Preditiva     | Em preparação — sem simulações                              |

## F.O.G.O. 3D Engine

Pipeline próprio, desacoplado da biblioteca de renderização:

```
.osm / .osm.gz → OsmXmlReader → OsmDataStore (ids/tags/refs preservados)
  → OsmFeatureMapper (entidades: Road, Building, LandArea,
    PedestrianCrossing, TrafficSignal; known/estimated/defaulted explícitos)
  → MapTopologyBuilder (rede viária por nós compartilhados — viadutos
    SEM nó compartilhado não conectam)
  → projeção local equiretangular (X=leste, Y=cima, Z=sul, metros;
    sem lat/lon na geometria)
  → RoadMeshBuilder / BuildingMeshBuilder / CrossingMeshBuilder /
    TrafficSignalMeshBuilder (Float32/Uint32, índices válidos, finitos)
  → SpatialPartitioner/TileManager (tiles de 800 m, culling por nó)
  → MapScene → FlutterSceneAdapter (única camada que toca a API gráfica)
```

No viewport legado do motor (não montado em `/`): ruas com **contorno por
lado** (junções internas por interseção das linhas de offset, arco circular no lado externo das
curvas, limite de miter 2h com fallback bevel — matemática herdada e
comprovada do motor 2D), **capas retas** nas extremidades e **caixas de
junção** sobre cada nó compartilhado: o contorno da pad é construído
pela INTERSEÇÃO DAS LINHAS DE BORDA reais das vias conectadas (cruzamento
ortogonal vira a caixa exata; junção em L vira o hexágono da união dos
retângulos) — as bordas da pad continuam as bordas das vias, sem fendas
nem entalhes, com degradê local entre as cores e `Material.depthLayer`
acima do plano das vias. Vias em níveis distintos (pontes/túneis) nunca
recebem junção conjunta.

Edifícios extrudados com volumetria legível (fachadas sombreadas por luz
direcional fake, cobertura na cor base — vertex colors multiplicando a
paleta, sem custo de material), anéis deduplicados no plano XZ (nós OSM
repetidos com `ele` divergente não geram paredes degeneradas),
triangulação de cobertura sem slivers e **pós-filtro de triângulos de
área nula** (slivers residuais: 0 nas três regiões). Plantas côncavas e
pátios internos preservados; **edifícios multipartes** (relations com
múltiplos anéis externos) viram um bloco por anel, cada pátio atribuído
ao anel que o contém (20 complexos em Marília antes perdidos).

**Infraestrutura (ETAPA 04)**: o motor consome só geometrias EXPLÍCITAS
— `area:highway=footway/traffic_island` viram superfícies próprias (11
polígonos recuperados em Marília), calçadas lineares
(`highway=sidewalk`/`footway`, 110 ways em Marília) renderizam como vias
finas independentes e **nunca conectam topologicamente** às vias; pistas
separadas de rodovia (dual carriageways) permanecem entidades distintas;
rampas (`*_link`) no nível do próprio `layer`. Política vertical
explícita: `layer × 4 m` e, sem `layer`, **ponte +4 m / túnel −4 m** —
nada de junção visual entre níveis (pads só agrupam vias do mesmo lift).
Sem dados de `sidewalk=*` (1 caso em 3 cidades), calçada inferida não
existe — não se inventa passeio. Estacionamentos (`amenity=parking`,
49 em Marília) e áreas de pedestre são polígonos fora do grafo viário.

**Rótulos e LOD (ETAPA 08)**: rótulos cartográficos como OVERLAY DE
TELA (`Camera.worldToScreen` projeta o ponto 3D do meio da via/área
para coordenadas de pixel) — sempre legíveis em perspectiva, nunca
deformados. Prioridade: motorway/trunk/primary sempre visíveis >
secondary/tertiary até 6 km > residential até 2 km > serviço até 800 m;
parques até 4 km. Colisão AABB por prioridade (menor número vence;
máximo 30 simultâneos). **LOD por distância com histerese** (±15%):
L0 (sempre) = vias, edifícios, áreas, água, pads; L1 (< 3,5 km) =
marcações viárias; L2 (< 1,2 km) = travessias, semáforos, árvores,
mobiliário. `updateLOD` só muda visibilidade quando a distância CRUZA
um threshold — zero custo por frame estável.

**Modos de iluminação (ETAPA 07)**: o motor alterna entre **noturno**
(identidade original: UnlitMaterial + sombreamento de fachadas por
vertex colors — luz direcional fake NW, custos mínimos) e **diurno**
(PhysicallyBasedMaterial com a MESMA paleta base + DirectionalLight
real com sombras — volumes, profundidade e materiais responsivos à
luz, sem alterar nenhuma cor da identidade). O botão "Modo diurno/
noturno" no painel de fontes alterna; a troca reconstrói a cena (sem
overhead por frame). `SceneLightingMode` em `Fogo3DStyle` centraliza
a configuração; a seleção de entidades funciona em ambos os modos
(troca de `baseColorFactor` em Unlit e PBR). Sem janelas emissivas ou
luzes públicas inventadas — os dados não as fornecem.

**Sinalização e ferrovias (ETAPA 05)**: ferrovias ATIVAS
(`railway=rail/tram/light_rail/subway`) viram eixo ferroviário único
(4 m, cor própria da paleta) com a mesma política vertical — todas as
ferrovias dos extratos atuais são `disused/abandoned` (não renderizam,
padrão cartográfico). Cruzamentos de nível (`railway=level_crossing` =
nó compartilhado) recebem pad conjunta normal. Travessias com política
EXPLÍCITA: zebra só com `crossing=marked/zebra` ou
`crossing:markings=yes/zebra` (Marília: ~110 marcadas de 253; o resto é
pavimento simples — nunca faixas por padrão). Linhas de parada
(`highway=stop`/`give_way`: 81 nós reais em Marília) viram barra
transversal branca na largura da via; lombadas (`traffic_calming`:
125 nós reais nas 3 cidades) viram plataforma elevada NA COR DA PRÓPRIA
via. Semáforos e travessias herdam o lift vertical da via conectada
(vias elevadas têm sinalização elevada). Nada é posicionado fora da
posição real do nó OSM.

**Áreas, vegetação, hidrografia e mobiliário (ETAPA 06)**: parques,
florestas e praças preservam contornos (inclusive côncavos e com
pátios); **rios e córregos** (`waterway=stream/river/canal`) viram
faixas de água na geometria real (largura `width` ou por tipo — river
8, stream 3, canal 5 m), levemente abaixo do plano viário;
**árvores individuais** do OSM (`natural=tree`: 154 em Marília)
renderizam na posição real com modelo genérico discreto (tronco +
copa achatada, variação determinística por id); **árvores
procedurais** (determinísticas por seed fixa, densidade ~1/1.500 m²,
restritas a parques/florestas, fora de edifícios e vias, máx. 80 por
área) são marcadas `estimated` na UI — nunca apresentadas como dado
real do OSM. Mobiliário com posição real: **bancos** (13 em Marília)
e **abrigos** (31) como volumes simples reutilizáveis na cor de
edifício da paleta. Sem dados de espécie/altura → modelo genérico;
sem área verde → zero árvores procedurais.

**Alturas (ETAPA 03)**: `height` explícito (conhecido) >
`building:levels` (estimado; `roof:levels`/`roof:height` somam) >
**padrão por categoria** de `building=*` — calibrada com as categorias
reais das três cidades (house 4,5 · genérico 6,5 · school 8 · retail 7 ·
commercial 10 · apartments 12 · church 15 · cathedral 22 · hangar 11 ·
shed/roof/garage ≈ 3 m) — nunca uma altura universal fixa. Resultado em
Garça: h∈[3, 15] m onde antes TODOS eram 9 m. Sem `roof:shape` nos
dados (0 ocorrências), cobertura plana é o comportamento seguro —
formas inclinadas não são inventadas. Larguras de via: `width`
declarado > estimativa por `lanes` (limitada a 0,5–1,5× o padrão do
tipo) > padrão por categoria, refinado por subtipos de `highway=service`
(becco, driveway, corredor de estacionamento).

Câmera orbital com inércia suave (metas + amortecimento exponencial):
arrastar orbita, botão direito move o chão, rolagem aproxima do ponto
sob o cursor, painel de seleção tem botão *Enquadrar* (limites reais da
entidade) e "Enquadrar região" retorna à visão padrão. Seleção por
raycast recupera o ID da entidade cartográfica.

O import roda em **isolate dedicado** com progresso e cancelamento — a
thread principal nunca trava. Importação de qualquer `.osm`/`.osm.gz`
externo pelo botão "Importar arquivo .osm…".

### Dados por cidade

```bash
python3 -m venv /tmp/fogo-venv
/tmp/fogo-venv/bin/pip install osmium==4.3.1
/tmp/fogo-venv/bin/python tool/map_data/extract_osm_xml.py
```

Extrai o arquivo único da região — as três cidades do catálogo regional +
corredor (bbox definido no próprio script, ver
`lib/engine/region/region_catalog.dart`) — direto do PBF local, sem download.
O motor 3D consome somente esse extrato `.osm.gz`.

## Executar

```bash
flutter pub get
flutter run -d linux                        # ou outro host nativo compatível
```

Ao abrir, a cena 3D auto-carrega a base regional única (as três cidades +
corredor). Os botões da navegação inferior centralizam a câmera em cada
cidade; "Região" reenquadra as três. A busca geográfica (Nominatim) continua
funcionando e mover a câmera para o resultado é um voo animado.

Pré-requisitos: nenhum nativo novo — WebView/WPE WebKit não é mais
necessário (a dependência `flutter_inappwebview` foi removida). Nenhuma
permissão/entitlement extra: HTTPS para Nominatim já cobre o uso de rede
do app.

Requisito: Flutter ≥ 3.47.1 / Dart ≥ 3.13.1 (validado neste ambiente).

## Validação

```bash
dart format lib test tool
flutter analyze   # 0 issues
flutter test
flutter build linux --debug   # sem WPE WebKit
```

Comparação visual (antes/depois, Garça auto-carregada via
`--dart-define=FOGO_AUTO_CITY=garca`): capturas sob Xvfb em
`/tmp/opencode/fogo_before.png` e `/tmp/opencode/fogo_after.png`.

`flutter build linux --debug` passou no Debian 13 **sem WPE WebKit instalado**
(o app não tem dependência WebView). A carga real do extrato regional na cena
3D é validada em execução local; métricas de ingestão em
`dart run tool/baseline_metrics.dart`.

## Limitações reais desta versão

- **17 mil objetos de malha** na base regional completa (as três cidades +
  corredor): draw calls por entidade ficam pesados em GPU de software;
  agrupamento por tile/LOD é o próximo passo.
- **Sobreposições coplanares do render (~2 mil avisos em Garça)**:
  investigação da ETAPA 02 provou que NÃO são vias duplicadas — são as
  duas pistas de avenidas divididas (dual carriageways legítimas, com
  superfícies que se tocam) e sobreposições de capas dentro de caixas de
  junção (cobertas por `depthLayer`). O motor tem deduplicação segura
  (`RoadDeduplicator`: mesmos nós OSM + mesmo perfil vertical + mesma
  semântica), que removeu **0** vias nas três regiões — não há
  duplicatas comprovadas nos dados atuais. Diagnósticos em
  `FogoEngineStats` (`duplicateRoadsRemoved`, `ambiguousDuplicates`,
  `crossingsWithoutConnection`, `degenerateSegments`,
  `isolatedNetworkNodes`) e `tool/duplicate_roads_audit.dart`.
- **Slivers residuais**: ~120 triângulos de área nula em Marília (0,2% de
  58 mil, de ~49 edifícios com nós OSM duplicados) — verticais, inertes
  para render e raycast; causa identificada (vértices copiados entre
  paredes adjacentes), correção completa pendente.
- **Camada vertical aproximada**: `layer` OSM vira deslocamento de 4 m/nível
  (dica de ordenação, não medida real).
- Altura de edifícios: `height` real quando existe (raro na região — 30
  edifícios em Marília); `building:levels × 3,2 m` marcado como **estimado**;
  sem nenhum → padrão 9 m (clamp 2,5–300 m), sempre distinguível na UI.
- **Draw calls por entidade** (necessário para seleção exata): cenas grandes
  (Garça: 2,6 mil objetos) ficam pesadas em GPU de software; agrupamento
  por tile/LOD é o próximo passo.
- Marcações de faixa de rolamento não são geradas (superfície separada por
  design; builder próprio é próximo passo). Travessias/semáforos são
  volumes simples.
- Módulos rota/propostas da era 2D estão dormentes (código preservado, sem
  host no workspace 3D).

## Encerramento no Linux

Bug upstream do embedder (flutter/flutter#193742): o teardown GTK dispara
`FlutterEngineRemoveView` → `kInvalidArguments` (e risco de use-after-free).
O app contorna com encerramento controlado (`WindowCloseHandler`): Linux
oculta a janela e encerra o processo de forma determinística; Alt+F4 e o
botão X usam o mesmo caminho. `FOGO_AUTOCLOSE_MS=<ms>` (dart-define) fecha
a janela automaticamente — usado em smoke tests de CI.

## Arquitetura

MVVM (Riverpod) + feature-based. Motor 3D puro-Dart em `lib/engine/`
(sem Flutter, sem flutter_scene — testável e executável em isolate);
a rota `/` é `Map3dPage`/`FogoSceneView` com adapter `FlutterSceneAdapter`
(fonte única: extrato OSM regional empacotado, renderizada pelo motor).

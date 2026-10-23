# F.O.G.O. — Plataforma de inteligência e controle urbano

Aplicação **Flutter desktop** (Linux/Windows/macOS) de central operacional
urbana orientada a mapas reais, agora com o **F.O.G.O. 3D Engine** — motor
cartográfico próprio que interpreta dados OpenStreetMap (`.osm` XML) e os
transforma em uma visualização tridimensional interativa via **Flutter
Scene** (Flutter GPU/Impeller).

**Cobertura inicial: Marília-SP, Vera Cruz-SP e Garça-SP** — extratos reais
do OpenStreetMap (© OpenStreetMap contributors) processados localmente a
partir do PBF já presente em `tool/map_data/raw/` e empacotados como
`.osm.gz`. Nenhum dado operacional fictício é carregado por padrão.

> Atribuição: dados cartográficos © OpenStreetMap contributors. Busca
> geográfica real via Nominatim/OSM.

## Módulos

| Rota          | Módulo               | Estado nesta etapa                                        |
| ------------- | -------------------- | --------------------------------------------------------- |
| `/`           | Central de Operações | Workspace cartográfico 3D (F.O.G.O. Engine + Flutter Scene) |
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

No viewport: ruas como superfícies coerentes com a polilinha OSM (largura
conhecida/estimada/padrão por tipo), edifícios extrudados (altura real
quando existe; regra de estimativa configurável quando não), áreas com
buracos (relations multipolygon), travessias zebradas e semáforos nas
posições reais, câmera orbital (arrastar), pan (botão direito), zoom
(rolagem) e **seleção por raycast** que recupera o ID da entidade
cartográfica e mostra suas propriedades no painel lateral.

O import roda em **isolate dedicado** com progresso e cancelamento — a
thread principal nunca trava. Importação de qualquer `.osm`/`.osm.gz`
externo pelo botão "Importar arquivo .osm…".

### Dados por cidade

```bash
python3 -m venv /tmp/fogo-venv
/tmp/fogo-venv/bin/pip install osmium==4.3.1
/tmp/fogo-venv/bin/python tool/map_data/extract_osm_xml.py
```

Extrai as três cidades (caixas urbanas do catálogo regional, ver
`lib/engine/region/region_catalog.dart`) direto do PBF local — nenhum
download. As células 2D legadas (`assets/map/cells/`, manifesto v2)
permanecem empacotadas para o histórico do projeto; o motor 3D consome
somente os extratos `.osm.gz`.

## Executar

```bash
flutter pub get
flutter run -d linux --enable-flutter-gpu   # ou -d windows / -d macos
```

O Flutter GPU fica **habilitado permanentemente nos runners empacotados**
(Linux: `fl_dart_project_set_enable_flutter_gpu`; Windows:
`project.set_enable_flutter_gpu(true)`; macOS: `FLTEnableFlutterGPU`) —
builds `flutter build` dispensam a flag. Em `flutter run` (dev), a flag
`--enable-flutter-gpu` é obrigatória por execução, conforme documentação
oficial do Flutter Scene.

Requisito: Flutter ≥ 3.47.1 / Dart ≥ 3.13.1 (validado neste ambiente).

## Validação

```bash
dart format lib test tool
flutter analyze   # 0 issues
flutter test      # 122 testes (42 do motor 3D + suite pré-existente)
flutter build linux --debug
```

Compilações Windows/macOS **não** foram executadas (este ambiente é Linux);
os runners foram preparados conforme a documentação oficial, mas sem
validação nativa.

## Limitações reais desta versão

- **Uma cidade por vez** no viewport (cada extrato é carregado isoladamente);
  corredor completo exige extrato único maior.
- **Z-fighting em vias duplicadas/sobrepostas do OSM** (o motor reporta via
  `Scene.findCoplanarOverlaps()`): sem merge de geometria coincidente nesta
  versão — o merger 2D antigo (`road_geometry_merger`) não é aplicado ao 3D.
- **Camada vertical aproximada**: `layer` OSM vira deslocamento de 4 m/nível
  (ponte +4, túnel −4) — dica de ordenação, não medida real.
- Altura de edifícios: `height` real quando existe (raro na região — 30
  edifícios em Marília); `building:levels × 3,2 m` marcado como **estimado**;
  sem nenhum → padrão 9 m, sempre distinguível na UI.
- **Draw calls por entidade** (necessário para seleção exata): cenas grandes
  (Marília: 3,5 mil objetos) ficam pesadas; agrupamento por tile/LOD é o
  próximo passo.
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
apresentação em `lib/features/map/` (ViewModel = `MapEngineNotifier`,
View = `Map3dPage`/`FogoSceneView`, adapter = `FlutterSceneAdapter`).

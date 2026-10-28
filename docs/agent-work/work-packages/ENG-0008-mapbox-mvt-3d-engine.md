# ENG-0008 — Mapbox MVT no Motor 3D + remoção WebView

Task: TASK-0008
Master Brief: `docs/agent-work/briefs/MASTER-BRIEF-TASK-0008.md`
Spec (fonte de verdade): `docs/superpowers/specs/2026-10-25-mapbox-mvt-3d-engine.md`
Prioridade: alta · Status: aberto

## Escopo

### A. Pipeline MVT → Motor 3D (novo, em features/map + engine aditivo)

1. `MapboxTileService` (features/map/data): fetch
   `https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/{z}/{x}/{y}.mvt?access_token=...`
   com `http` (já dependência), token via `String.fromEnvironment` com o
   `pk` padrão atual (mesmo valor de mapbox_map_page.dart antes da remoção).
2. Dependência nova: `vector_tile: ^4.0.0` (SDK >=3.8.1 compatível).
3. `MvtTileDecoder` + `MvtFeatureMapper` (features/map/vector/mvt/):
   source-layers → domínio do motor, conforme tabela da spec. `class` do
   Mapbox → `RoadType` (tabela explícita); largura via tabela
   class→metros; `structure` → bridge/tunnel (yLift existente).
4. Sessão de streaming (`MapboxSession`): mantém
   `Map<tileKey, List<MapSceneObject>>` + LRU 128/TTL 12 h, calcula tiles
   visíveis do frustum ∩ solo (z por heurística da spec, clamp 11..16),
   throttle ~200 ms pós-gesto, máx ~16 fetches/settle, pais até filhos
   chegarem. Produz `MapScene` nova por lote → `uploadScene` existente.
5. Engine aditivo: construtor assembled em `FogoEngine` (cena, model,
   projector, stats, geoBounds) para a UI atual consumir sem reescrita;
   `Poi` no domínio + kind na cena + marcador 3D mínimo + ramo em
   `buildEntityDetails`; origem do projetor fixa na sessão.
6. Rótulos: `LabelCandidate` existente para `road.name`, POIs
   (`filterrank` limita densidade) e `place_label`/`transit_stop_label`/
   `natural_label`.
7. Map3dPage: source panel ganha modo Mapbox (padrão, auto-carrega
   Marília), estado de tiles (carregando/erro), atribuição
   "© Mapbox © OpenStreetMap contributors" no canto.

### B. Remoção WebView

- Deletar: `lib/features/map/presentation/pages/mapbox_map_page.dart`,
  `mapbox_focus_bridge.dart`,
  `test/mapbox_map_page_failure_test.dart`,
  `test/features/map/presentation/pages/mapbox_focus_bridge_test.dart`.
- `pubspec.yaml`: remover `flutter_inappwebview`, `dependency_overrides`
  do plugin Linux; deletar `packages/flutter_inappwebview_linux/`.
- `analysis_options.yaml`: remover exclusion do pacote local.
- `app_router.dart`: rota `/` → `Map3dPage`.
- `README.md`: remover seções WPE/WebView; documentar pré-requisito novo
  (nenhum nativo; só token Mapbox) e a fonte MVT.
- `latlong2` permanece (GeocodingService usa `LatLng`).

### C. Testes

- Decoder/mapper: fixture MVT sintética (bytes) → Road/Building/
  LandArea/Poi corretos (class, height, estrutura).
- Matemática de tiles: heurística de z, retângulo visível, LRU/TTL.
- Sessão com HTTP falso: fetch, cache, troca de z (pais→filhos), falha
  de rede preserva tiles.
- Router: `/` é Map3dPage.
- Manter verdes: analyze, build linux (sem WPE), suíte existente.

## Fora de escopo

Cache em disco/offline; união de vias entre tiles; `admin`, `aeroway`,
`housenum_label`; terreno/elevação; incremental no adapter.

## Critérios de aceitação

Spec `## Aceitação` itens 1–8. Evidência: comandos + saídas no handoff.

## Protegidos

- `lib/engine/**` e `map_3d_page.dart`: apenas mudanças aditivas;
  alterações locais não commitadas preservadas (não reverter, não
  reformatar).
- Fluxo OSM (loadCity/importFile) sem regressão.

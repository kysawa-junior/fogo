# Mapbox MVT → Motor 3D F.O.G.O. — TASK-0008

Status: **aprovado pelo usuário (2026-10-25)**. Supersede
`2026-10-25-mapbox-standard-night-design.md` (WebView/Mapbox GL JS sai da
rota principal e é removido).

## Objetivo

Renderizar dados Mapbox no Motor 3D F.O.G.O.: tiles vetoriais MVT
(`mapbox.mapbox-streets-v8`) baixados sob demanda conforme pan/zoom da
câmera orbital, decodificados e convertidos em meshes pelo próprio motor.
WebView/Mapbox GL JS é removido por completo (página, bridge, testes,
dependência `flutter_inappwebview` e cópia local WPE).

## Pipeline

```
settle de pan/zoom → z + tiles visíveis (frustum ∩ solo)
  → GET api.mapbox.com/v4/mapbox.mapbox-streets-v8/{z}/{x}/{y}.mvt
  → decodificação PBF (pacote vector_tile 4.0.0)
  → MvtFeatureMapper: source-layers → entidades de domínio
  → mesh builders existentes (Road/Building/LandArea) → MapScene nova
  → FlutterSceneAdapter.uploadScene (reuso integral)
```

- **Zoom→z**: largura visível no solo / 3 ≈ largura do tile; clamp z∈[11..16].
- **Batch**: throttle ~200 ms após o gesto; máx. ~16 fetches/settle;
  tiles que já estão no cache não são re-baixados.
- **Cache**: LRU ~128 tiles em memória, TTL 12 h (padrão Mapbox), key
  `z/x/y`. Sem cache em disco (offline fora de escopo).
- **Troca de z**: tiles-pais permanecem até os filhos chegarem; após
  chegada, pais saem (nenhuma tela vazia).
- **Falha de rede**: tiles carregados permanecem; painel reporta erro;
  próximo settle tenta de novo.

## Camadas (primeira entrega)

| Streets v8 | Destino | Campos |
|---|---|---|
| `road` | `Road` | `class`→RoadType, `structure`→bridge/tunnel, `name` |
| `building` (`extrude=true`) | `Building` | `height`, `min_height`, `type` |
| `water` + `waterway` | `LandArea` água | geometria |
| `landuse` + `landuse_overlay` | `LandArea` | `class` (park, wood, grass…) |
| `poi_label` | `Poi` (novo) + rótulo | `name`, `maki`/`class`, `filterrank` |
| `place_label`, `transit_stop_label`, `natural_label` | só `LabelCandidate` | `name`, `symbolrank` |

Fora de escopo: `admin`, `aeroway`, `housenum_label`, `motorway_junction`.

MVT não traz largura de via: tabela `class` → metros (Mapbox). MVT não traz
estilo: aparência é a `FogoPalette`/mesh builders existentes, sem mudança.

## Reuso e mudanças aditivas no motor

Reuso integral: `RoadMeshBuilder`, `BuildingMeshBuilder`, builders de área,
`CoordinateProjector`, `OrbitCamera`, picking, `LabelCandidate`/`LabelOverlay`,
`FogoPalette`, `FlutterSceneAdapter.uploadScene`, `MapScene` imutável
(`tileId = z/x/y`), `MapModel.indexAll` para seleção/detalhes.

Aditivo (sem reescrever comportamento OSM existente):

1. `Poi` no domínio + ramo no painel de detalhes + marcador 3D mínimo
   (disco no chão) para picking; kind novo na cena.
2. `FogoEngine` ganha construtor assembled (cena/modelo/projetor montados
   pela sessão MVT) — UI atual (`engine.scene`, `engine.model`,
   `engine.projector`) continua funcionando sem reescrita.
3. Origem do projetor fixa na sessão (centro do primeiro lote de tiles).

Mudanças locais não commitadas no motor/testes/README são preservadas;
nenhum arquivo do motor é reescrito, apenas estendido.

## UI

- Rota `/` volta para `Map3dPage`.
- Painel de fontes: "Mapbox MVT" fonte padrão (auto-carrega Marília ao
  abrir); cidades OSM e import `.osm` continuam como alternativa offline.
- Atribuição obrigatória: "© Mapbox © OpenStreetMap contributors" no canto
  do mapa (ToS).
- Busca existente (GeocodingService + focusGeoPoint) intacta; mover a
  câmera já dispara fetch.
- Token: mesmo `pk` público padrão via `--dart-define=MAPBOX_ACCESS_TOKEN`.
- Estado de tiles no painel (carregando N/erro de rede).

## Aceitação

1. `flutter build linux --debug` passa sem WPE WebKit instalado
   (dependência WebView removida).
2. Ao abrir, a cena 3D carrega tiles MVT de Marília; pan/zoom buscam
   tiles novos sem travar a UI.
3. Vias, edifícios, água e áreas verdes visíveis com aparência da paleta
   do motor; POIs e nomes aparecem como rótulos.
4. Clique seleciona entidade MVT e abre painel de detalhes.
5. Sem rede: erro reportado, tiles já carregados permanecem.
6. Atribuição Mapbox/OSM visível na tela.
7. `flutter analyze` limpo; testes novos + suíte de rota/plataforma/mapa
   passam.
8. Nenhum comportamento do fluxo OSM atual regride (loadCity/importFile).

## Riscos declarados

- Vias são clipadas por tile: segmentos se tocam na borda, seleção
  destaca só o segmento pego. União entre tiles fica para depois.
- Densidade de POIs/rótulos em z alto controlada por `filterrank`.
- Throttle/limites de batch parametrizados; ajuste fino é empírico.
- Re-upload de cena por lote (não incremental): custo aceitável para
  cobertura urbana; otimização incremental só se medirmos engasgo.
- `vector_tile` 4.0.0 é pacote pequeno/mantido por um autor; se falhar,
  decodificação protobuf é substituível sem tocar no resto.

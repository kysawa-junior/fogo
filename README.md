# F.O.G.O. — Plataforma de inteligência e controle urbano

Aplicação **Flutter desktop** (Linux/Windows/macOS) de central operacional
urbana orientada a mapas reais.

**Cobertura cartográfica real: Marília-SP, Vera Cruz-SP, Garça-SP e o corredor
entre as cidades** (malha viária, edificações, água/verde, POIs, nomes de ruas
e bairros) — dados do OpenStreetMap processados localmente e empacotados na
aplicação. Nenhum dado operacional fictício é carregado por padrão.

> Atribuição: dados cartográficos © OpenStreetMap contributors. Roteamento
> real via OSRM (servidor público de demonstração por padrão — configure
> `OSRM_BASE_URL` para uma instância própria em produção).

## Módulos

| Rota          | Módulo               | Estado nesta etapa                                              |
| ------------- | -------------------- | --------------------------------------------------------------- |
| `/`           | Central de Operações | Workspace cartográfico real + rotas reais do usuário             |
| `/inventory`  | Inventário Inteligente | Vazio (fonte de equipamentos aguarda backend); consulta pronta |
| `/predictive` | Cidade Preditiva     | Em preparação — sem simulações                                   |

## Recursos reais do workspace

- **Mapa vetorial offline**: `fogo_map_sdk` lê células OSM locais e desenha
  água, áreas verdes/agricultura, limites, ferrovias, vias, edificações, POIs e
  rótulos com `CustomPainter`. Fora da cobertura, o fundo fica `#0D0F14`.
- **Sem rede para o mapa-base**: não há tiles remotos nem fallback de mapa.
  Rotas, marcadores, controles e atribuição OSM continuam acima do mapa; busca
  geográfica e roteamento usam serviços de rede independentes.
- A paleta noturna v3 é inspirada na hierarquia do Mapbox Standard night
  (vias claras sobre terreno escuro), mas é própria do F.O.G.O.; não há
  alegação de equivalência exata.
- Navegação contínua Marília ↔ Garça (uma só região, sem troca de mapa).
- Enquadramentos: Região, Marília e Garça; Vera Cruz fica na cobertura regional.
- Busca geográfica real (Nominatim/OSM).
- Paradas reais criadas pelo usuário (botão direito no mapa) → otimização
  própria (NN + 2-opt) sobre **matriz de distâncias da rede viária (OSRM)**
  e geometria real desenhada no mapa.
- Camadas reais: Edificações e Nomes/Rótulos (alternáveis) + filtro de vias
  por classe (rodovias, primárias… rurais). A câmera é 3D perspectiva
  própria: pitch contínuo 0°–60° (botão 3D alterna 0°/45°) e rotação via
  giro do trackpad; pitch/bearing são transitórios. Vias, ferrovias e rotas
  são suavizadas com spline que preserva cruzamentos. Larguras de via
  escalam por classe e zoom em rampas contínuas, e a visão regional aplica
  orçamento de rótulos por prioridade (ADR-0006). Extrusão usa `height`
  numérico real do OSM quando existe; sem altura real, o motor aplica alturas
  estimadas determinísticas (só no render, dado intacto) — ver ADR-0005.
  `building:levels` nunca vira altura.

## Regenerar dados cartográficos locais

```bash
python3 -m venv .venv-map
. .venv-map/bin/activate
python -m pip install -r tool/map_data/requirements.txt
stage="$(mktemp -d /tmp/fogo-map-stage.XXXXXX)"
python tool/map_data/build_map_data.py \
  --pbf tool/map_data/raw/sudeste-latest.osm.pbf \
  --stage "$stage" \
  --promote-to assets/map
```

O gerador lê somente o PBF local informado e **não baixa dados**. Não substitua
essa fonte nem use comandos de download para regenerar o mapa. Procedimento,
dependências e gate semântico: [`tool/map_data/README.md`](tool/map_data/README.md).

## Executar

```bash
flutter pub get
flutter run -d linux          # ou -d windows / -d macos
# opcional (roteamento em instância própria):
flutter run -d linux --dart-define=OSRM_BASE_URL=https://seu-osrm/v1
```

O mapa funciona offline com dados empacotados. Busca e roteamento usam rede
(Nominatim/OSRM) e mostram erros explícitos quando indisponíveis. A compilação
Web do pacote SDK não significa suporte Web para o aplicativo F.O.G.O.

## Validação

```bash
dart format lib test
flutter analyze   # 0 issues
flutter test
flutter build linux --debug
```

## Encerramento no Linux

Bug upstream do embedder (flutter/flutter#193742): o teardown GTK dispara
`FlutterEngineRemoveView` → `kInvalidArguments` (e risco de use-after-free).
O app contorna com encerramento controlado (`WindowCloseHandler`): Linux
oculta a janela e encerra o processo de forma determinística; Alt+F4 e o
botão X usam o mesmo caminho. `FOGO_AUTOCLOSE_MS=<ms>` (dart-define) fecha
a janela automaticamente — usado em smoke tests de CI.

## Arquitetura

MVVM + feature-based — detalhes em [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

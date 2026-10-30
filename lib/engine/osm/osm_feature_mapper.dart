import '../domain/building.dart';
import '../domain/land_area.dart';
import '../domain/map_feature.dart';
import '../load_progress.dart';
import '../domain/pedestrian_crossing.dart';
import '../domain/poi.dart';
import '../domain/road_marking.dart';
import '../domain/vegetation.dart';
import '../domain/road.dart';
import '../domain/road_properties.dart';
import '../domain/road_type.dart';
import '../domain/sourced_value.dart';
import '../geo/geo_coordinate.dart';
import 'osm_elements.dart';

/// Modelo cartográfico interpretado: entidades de domínio indexadas por id.
/// Informação não interpretada permanece no [OsmDataStore] original
/// (preservada para extensões futuras).
class MapModel {
  MapModel({
    required this.roads,
    required this.buildings,
    required this.landAreas,
    required this.crossings,
    required this.signals,
    this.markings = const [],
    this.trees = const [],
    this.waterways = const [],
    this.furniture = const [],
    this.pois = const [],
  });

  final List<Road> roads;
  final List<Building> buildings;
  final List<LandArea> landAreas;
  final List<PedestrianCrossing> crossings;
  final List<TrafficSignal> signals;

  /// ETAPA 05: linhas de parada e dispositivos redutores.
  final List<RoadMarking> markings;

  /// ETAPA 06: árvores individuais do OSM e procedurais (estimated).
  final List<Tree> trees;

  /// ETAPA 06: rios, córregos e canais (ways lineares).
  final List<Waterway> waterways;

  /// ETAPA 06: mobiliário urbano com posição real.
  final List<StreetFurniture> furniture;

  /// ETAPA 06: pontos de interesse (rótulos de pontos do OSM; o mapeador
  /// OSM ainda não os popula — classe mantida para rótulos futuros).
  final List<Poi> pois;

  final Map<String, MapFeature> _byId = {};

  /// Reindexa do zero — limpar antes evita "fantasmas" de entidades
  /// removidas (ex.: duplicata descartada ainda consultável por id).
  void indexAll() {
    _byId.clear();
    for (final f in [
      ...roads,
      ...buildings,
      ...landAreas,
      ...crossings,
      ...signals,
      ...markings,
      ...trees,
      ...waterways,
      ...furniture,
      ...pois,
    ]) {
      _byId[f.id] = f;
    }
  }

  MapFeature? byId(String id) => _byId[id];
}

/// Interpretação semântica: OSM bruto → entidades de domínio.
/// Regras de estimativa são configuráveis e distinguem valor conhecido
/// (tag explícita), estimado (regra a partir de outra tag) e padrão.
class OsmFeatureMapper {
  OsmFeatureMapper({
    BuildingHeightEstimator? heightEstimator,
    RoadWidthEstimator? widthEstimator,
  }) : heights = heightEstimator ?? BuildingHeightEstimator(),
       widths = widthEstimator ?? RoadWidthEstimator();

  final BuildingHeightEstimator heights;
  final RoadWidthEstimator widths;

  /// Mapeia todo o store. Elementos inválidos geram issues no store,
  /// nunca exceções.
  MapModel map(OsmDataStore store, {LoadProgress? progress}) {
    final roads = <Road>[];
    final buildings = <Building>[];
    final areas = <LandArea>[];
    final crossings = <PedestrianCrossing>[];
    final signals = <TrafficSignal>[];
    final markings = <RoadMarking>[];
    final trees = <Tree>[];
    final furniture = <StreetFurniture>[];
    final waterways = <Waterway>[];

    // Nodes: travessias, semáforos e marcações (ETAPA 05).
    final int total = store.nodeCount + store.wayCount;
    var done = 0;
    for (final node in store.nodes) {
      if (done % 5000 == 0) {
        progress?.step(done, total == 0 ? 1 : done / total);
      }
      done++;
      final highway = node.tags['highway'];
      final position = GeoCoordinate(
        node.lat,
        node.lon,
        elevation: node.elevation,
      );
      if (highway == 'crossing') {
        // Zebra EXPLÍCITA (§3): faixas só com marcação declarada —
        // sem valor, `unmarked` ou `markings=no` = pavimento simples.
        final crossingTag = node.tags['crossing'];
        final markingsTag = node.tags['crossing:markings'];
        final marked =
            (crossingTag == 'marked' || crossingTag == 'zebra') ||
            (markingsTag == 'yes' || markingsTag == 'zebra');
        crossings.add(
          PedestrianCrossing(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: position,
            marked: marked,
          ),
        );
      } else if (highway == 'traffic_signals') {
        signals.add(
          TrafficSignal(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: position,
          ),
        );
      } else if (node.tags['natural'] == 'tree') {
        trees.add(
          Tree(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: position,
          ),
        );
      } else if (node.tags['amenity'] == 'bench') {
        furniture.add(
          StreetFurniture(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: position,
            kind: StreetFurnitureKind.bench,
          ),
        );
      } else if (node.tags['amenity'] == 'shelter' ||
          node.tags['public_transport'] == 'platform') {
        furniture.add(
          StreetFurniture(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: position,
            kind: StreetFurnitureKind.shelter,
          ),
        );
      } else if (highway == 'stop' ||
          highway == 'give_way' ||
          node.tags.containsKey('traffic_calming')) {
        markings.add(
          RoadMarking(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: position,
            kind: highway == 'stop'
                ? RoadMarkingKind.stop
                : highway == 'give_way'
                ? RoadMarkingKind.giveWay
                : RoadMarkingKind.trafficCalming,
          ),
        );
      }
    }

    for (final way in store.ways) {
      if (done % 5000 == 0) {
        progress?.step(done, total == 0 ? 1 : done / total);
      }
      done++;
      final geometry = _wayGeometry(store, way);
      final points = geometry.points;
      final nodeRefs = geometry.nodeRefs;
      final tags = way.tags;
      final id = 'way/${way.id}';

      final highway = tags['highway'];
      final isArea = tags['area'] == 'yes';
      final isBuilding =
          tags.containsKey('building') && tags['building'] != 'no';
      // ETAPA 06: água LINEAR (waterway=stream/river/canal) — ways
      // com trajeto próprio, nunca preenchidos por inferência.
      final waterwayTag = tags['waterway'];
      if (waterwayTag != null &&
          const ['stream', 'river', 'canal', 'ditch'].contains(waterwayTag) &&
          !isArea) {
        final width =
            double.tryParse(tags['width'] ?? '') ??
            switch (waterwayTag) {
              'river' => 8.0,
              'canal' => 5.0,
              _ => 3.0,
            };
        waterways.add(
          Waterway(
            id: id,
            tags: Map<String, String>.unmodifiable(tags),
            points: List<GeoCoordinate>.unmodifiable(points),
            widthMeters: width,
            nodeRefs: List<int>.unmodifiable(nodeRefs),
          ),
        );
        continue;
      }
      // ETAPA 05: ferrovia ATIVA (railway=rail/tram/light_rail/subway)
      // sem highway → eixo ferroviário único (nunca duplicado em dois
      // trilhos físicos). disused/abandoned/preserved/construction são
      // padrão cartográfico de NÃO renderizar — todas as ferrovias dos
      // extratos atuais estão nesse estado (audit ETAPA 05).
      final activeRailway = _activeRailwayValue(tags);

      // Geometria insuficiente (refs ausentes truncaram tudo): issue, e
      // a via não vira entidade — dados inválidos não derrubam a carga.
      final enoughPoints = way.isClosed
          ? points.length >= 4
          : points.length >= 2;
      if (highway != null && !enoughPoints) {
        store.issues.add(
          OsmImportIssue(
            'Geometria insuficiente (${points.length} pontos) na via ${way.id}.',
            elementId: id,
          ),
        );
        continue;
      }

      // Semântica de via (highway) antes de área: um way pode ser rua E
      // fechado (praças `highway=pedestrian` são áreas — tratadas abaixo).
      // Ways fechados SEM area=yes são VIAS em anel (rotatórias
      // `junction=roundabout`, retornos, ruas circulares): a malha fecha
      // a emenda com junção cíclica (RoadMeshBuilder).
      final wayIsRoad =
          (highway != null &&
              highway != 'crossing' &&
              highway != 'traffic_signals' &&
              !isArea &&
              !isBuilding) ||
          (activeRailway != null && !isArea && !isBuilding);
      if (wayIsRoad) {
        roads.add(_mapRoad(id, tags, points, nodeRefs));
        continue;
      }
      if (isBuilding && way.isClosed) {
        buildings.add(_mapBuilding(id, tags, [points]));
        continue;
      }
      if (way.isClosed && _isLandAreaTag(tags)) {
        areas.add(
          LandArea(
            id: id,
            tags: Map<String, String>.unmodifiable(tags),
            polygons: [
              [points],
            ],
            kind: LandAreaKind.fromTags(tags),
          ),
        );
        continue;
      }
      if (highway == 'crossing') {
        crossings.add(
          PedestrianCrossing(
            id: id,
            tags: Map<String, String>.unmodifiable(tags),
            position: points.first,
          ),
        );
      } else if (highway == 'traffic_signals') {
        signals.add(
          TrafficSignal(
            id: id,
            tags: Map<String, String>.unmodifiable(tags),
            position: points.first,
          ),
        );
      }
    }

    // Relations multipolygon: áreas/edifícios com contornos e buracos.
    for (final rel in store.relations) {
      if (rel.tags['type'] != 'multipolygon') continue;
      final tags = rel.tags;
      final isBuilding =
          tags.containsKey('building') && tags['building'] != 'no';
      final id = 'relation/${rel.id}';
      final outers = <GeoPolyline>[];
      final inners = <GeoPolyline>[];
      for (final member in rel.members) {
        if (member.type != 'way') continue;
        final way = store.wayById(member.ref);
        if (way == null) {
          store.issues.add(
            OsmImportIssue(
              'Membro way/${member.ref} ausente na relation ${rel.id}.',
              elementId: id,
            ),
          );
          continue;
        }
        final points = _wayGeometry(store, way).points;
        if (points.length < 4 || !way.isClosed) {
          store.issues.add(
            OsmImportIssue(
              'Membro way/${member.ref} não é um anel fechado válido.',
              elementId: id,
            ),
          );
          continue;
        }
        (member.role == 'inner' ? inners : outers).add(points);
      }
      if (outers.isEmpty) continue;
      if (isBuilding) {
        // Multipartes (ETAPA 03): um Building POR anel externo — as
        // partes de um complexo com blocos separados são edifícios
        // distintos. Cada pátio (inner) pertence ao outer que o
        // contém; inners órfãos são registrados, nunca descartados em
        // silêncio. Id derivado estável: relation/<id>#<k>.
        for (var k = 0; k < outers.length; k++) {
          final ownInners = <GeoPolyline>[
            for (final hole in inners)
              if (_polygonContains(outers[k], hole)) hole,
          ];
          final orphanCount = inners.length - ownInners.length;
          if (orphanCount > 0) {
            store.issues.add(
              OsmImportIssue(
                '$orphanCount pátio(s) fora do anel externo '
                '${k + 1} da relation ${rel.id}.',
                elementId: id,
              ),
            );
          }
          buildings.add(
            _mapBuilding(outers.length == 1 ? id : '$id#$k', tags, [
              outers[k],
              ...ownInners,
            ]),
          );
        }
      } else if (_isLandAreaTag(tags)) {
        // Áreas: cada outer mantém TODOS os inners que contém (parques
        // multipartes são uma entidade só — multiouter como uma lista
        // de polígonos da MESMA entidade).
        final polygons = <List<GeoPolyline>>[
          for (final outer in outers) [outer],
        ];
        for (final hole in inners) {
          for (final polygon in polygons) {
            if (_polygonContains(polygon.first, hole)) {
              polygon.add(hole);
              break;
            }
          }
        }
        areas.add(
          LandArea(
            id: id,
            tags: Map<String, String>.unmodifiable(tags),
            polygons: polygons,
            kind: LandAreaKind.fromTags(tags),
          ),
        );
      }
    }

    final model = MapModel(
      roads: roads,
      buildings: buildings,
      landAreas: areas,
      crossings: crossings,
      signals: signals,
      markings: markings,
      trees: trees,
      waterways: waterways,
      furniture: furniture,
    );
    model.indexAll();
    progress?.step(total, 1);
    return model;
  }

  Road _mapRoad(
    String id,
    Map<String, String> tags,
    GeoPolyline points,
    List<int> nodeRefs,
  ) {
    final type = RoadType.fromHighwayTag(
      tags['highway'],
      railway: tags['railway'],
    );
    final width = widths.estimate(tags, type);
    final props = RoadProperties(
      widthMeters: width,
      lanes: int.tryParse(tags['lanes'] ?? ''),
      direction: _roadDirection(tags),
      surface: tags['surface'],
      layer: int.tryParse(tags['layer'] ?? '') ?? 0,
      bridge: tags['bridge'] != null && tags['bridge'] != 'no',
      tunnel: tags['tunnel'] != null && tags['tunnel'] != 'no',
    );
    return Road(
      id: id,
      tags: Map<String, String>.unmodifiable(tags),
      points: List<GeoCoordinate>.unmodifiable(points),
      type: type,
      properties: props,
      nodeRefs: List<int>.unmodifiable(nodeRefs),
    );
  }

  static RoadDirection _roadDirection(Map<String, String> tags) =>
      switch (tags['oneway']) {
        'yes' => RoadDirection.forward,
        '-1' => RoadDirection.reverse,
        'no' => RoadDirection.both,
        null =>
          tags['junction'] == 'roundabout'
              ? RoadDirection.forward
              : RoadDirection.both,
        _ => RoadDirection.both,
      };

  Building _mapBuilding(
    String id,
    Map<String, String> tags,
    List<GeoPolyline> rings,
  ) {
    return Building(
      id: id,
      tags: Map<String, String>.unmodifiable(tags),
      footprint: List<List<GeoCoordinate>>.unmodifiable(rings),
      height: heights.estimate(tags),
      minHeightMeters: double.tryParse(tags['min_height'] ?? ''),
    );
  }

  /// Geometria resolvida da via; refs ausentes cortam a polilinha (via
  /// parcial) e registram issue — a aplicação não cai. `nodeRefs` fica
  /// alinhado com `points` (mesmos índices).
  ({GeoPolyline points, List<int> nodeRefs}) _wayGeometry(
    OsmDataStore store,
    OsmWay way,
  ) {
    final points = <GeoCoordinate>[];
    final nodeRefs = <int>[];
    var broken = false;
    for (final ref in way.nodeRefs) {
      final node = store.nodeById(ref);
      if (node == null) {
        store.issues.add(
          OsmImportIssue(
            'Nó $ref ausente; geometria da way ${way.id} truncada.',
            elementId: 'way/${way.id}',
          ),
        );
        broken = true;
        continue;
      }
      if (broken) {
        points.clear();
        nodeRefs.clear();
      }
      broken = false;
      points.add(GeoCoordinate(node.lat, node.lon, elevation: node.elevation));
      nodeRefs.add(ref);
    }
    return (points: points, nodeRefs: nodeRefs);
  }

  /// Valor de `railway` quando a linha é ATIVA (renderizável);
  /// null para disused/abandoned/preserved/construction ou ausente.
  static String? _activeRailwayValue(Map<String, String> tags) {
    final railway = tags['railway'];
    if (railway == null) return null;
    const active = {'rail', 'tram', 'light_rail', 'subway'};
    return active.contains(railway) ? railway : null;
  }

  /// Contenção de anel (ray casting no plano lat/lon): um vértice do
  /// `hole` dentro de `outer` basta — aproximação adequada para pátios
  /// de edifícios/áreas (anéis OSM bem formados não se cruzam).
  static bool _polygonContains(GeoPolyline outer, GeoPolyline hole) {
    if (hole.isEmpty) return false;
    final test = hole.first;
    var inside = false;
    for (var i = 0, j = outer.length - 1; i < outer.length; i++) {
      final a = outer[i];
      final b = outer[j];
      if ((a.latitude > test.latitude) != (b.latitude > test.latitude) &&
          test.longitude <
              (b.longitude - a.longitude) *
                      (test.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  static bool _isLandAreaTag(Map<String, String> tags) =>
      tags.containsKey('landuse') ||
      tags.containsKey('leisure') ||
      tags.containsKey('natural') ||
      tags.containsKey('amenity') ||
      tags['highway'] == 'pedestrian' && tags['area'] == 'yes' ||
      // ETAPA 04: superfícies de infraestrutura EXPLÍCITAS do OSM —
      // áreas de circulação e ilhas de tráfego com polígono próprio
      // (nada é inferido da linha central da via).
      _isInfrastructureAreaTag(tags);

  /// `area:highway=*` em ways fechados: calçadas de praça, ilhas de
  /// tráfego e similares — geometria própria, nunca inventada.
  static bool _isInfrastructureAreaTag(Map<String, String> tags) {
    final areaHighway = tags['area:highway'];
    if (areaHighway == null) return false;
    const supported = {'footway', 'pedestrian', 'traffic_island', 'steps'};
    return supported.contains(areaHighway);
  }
}

/// Regra configurável de altura de edifícios.
/// Regra configurável de altura de edifícios (ETAPA 03).
///
/// Prioridade (§4): `height` explícito (conhecido) > `building:levels`
/// (estimado; `roof:levels`/`roof:height` somam quando presentes) >
/// padrão POR CATEGORIA de `building=*` (documentado; nunca uma altura
/// fixa universal). `min_height` é a elevação da base, tratada à parte
/// pelo builder. Cobertura plana no topo das paredes — sem dados de
/// `roof:shape` (0 ocorrências nas regiões atuais), formas inclinadas
/// não são inventadas.
class BuildingHeightEstimator {
  BuildingHeightEstimator({
    this.metersPerLevel = 3.2,
    this.categoryDefaults = defaultCategoryHeights,
  });

  /// Metros por pavimento (convenção do motor, documentada).
  final double metersPerLevel;

  /// Altura padrão por categoria OSM de `building=*` — calibrada com as
  /// categorias reais das regiões (yes/house/church/school/...).
  final Map<String, double> categoryDefaults;

  /// Categorias reais dos extratos (Garça/Marília/Vera Cruz):
  /// genérico dominante, religioso alto, galpões com pé-direito alto,
  /// construções baixas.
  static const defaultCategoryHeights = <String, double>{
    // Genérico (dominante: 637/653 em Garça): presença 3D clara —
    // extrusão majorada para ler como bloco sólido de cidade.
    'yes': 9,
    // Residencial.
    'house': 6,
    'residential': 11,
    'apartments': 16,
    'dormitory': 16,
    'hotel': 17,
    // Comércio/serviços.
    'commercial': 13,
    'retail': 9.5,
    'supermarket': 10.5,
    'office': 14.5,
    'public': 13,
    'kiosk': 3.5,
    // Institucional (pé-direito alto).
    'school': 10.5,
    'kindergarten': 7.5,
    'university': 11.5,
    'college': 11.5,
    'hospital': 15.5,
    'train_station': 11.5,
    'fire_station': 11.5,
    'stadium': 18,
    'grandstand': 10,
    // Religioso (naves).
    'church': 18,
    'chapel': 10,
    'cathedral': 26,
    'mosque': 15,
    'temple': 15,
    // Industrial (galpões).
    'industrial': 11,
    'warehouse': 11,
    'hangar': 13.5,
    'factory': 13.5,
    'barn': 6,
    'shed': 3.5,
    'greenhouse': 5,
    // Baixos/beirais (garagens e anexos continuam baixos de propósito).
    'garage': 3.5,
    'garages': 3.5,
    'carport': 3,
    'roof': 3.5,
    'ruins': 3.5,
    'hut': 3,
    'construction': 9,
  };

  SourcedValue<double> estimate(Map<String, String> tags) {
    // 1. Altura total explícita — conhecida (unidade: metros).
    final rawHeight = tags['height'];
    final parsed = rawHeight == null ? null : double.tryParse(rawHeight);
    if (parsed != null && parsed > 0) {
      return SourcedValue.known(parsed);
    }

    // 2. Pavimentos — estimado; telhado declarado soma quando explícito.
    final levels = tags['building:levels'];
    final parsedLevels = levels == null ? null : double.tryParse(levels);
    if (parsedLevels != null && parsedLevels > 0) {
      final roofLevels = tags['roof:levels'];
      final parsedRoofLevels = roofLevels == null
          ? null
          : double.tryParse(roofLevels);
      final roofHeight = tags['roof:height'];
      final parsedRoofHeight = roofHeight == null
          ? null
          : double.tryParse(roofHeight);
      if (parsedRoofLevels != null && parsedRoofLevels > 0) {
        return SourcedValue.estimated(
          (parsedLevels + parsedRoofLevels) * metersPerLevel,
          raw: 'building:levels=$levels + roof:levels=$roofLevels',
        );
      }
      if (parsedRoofHeight != null && parsedRoofHeight > 0) {
        return SourcedValue.estimated(
          parsedLevels * metersPerLevel + parsedRoofHeight,
          raw: 'building:levels=$levels + roof:height=$roofHeight',
        );
      }
      return SourcedValue.estimated(
        parsedLevels * metersPerLevel,
        raw: 'building:levels=$levels',
      );
    }

    // 3. Categoria — padrão documentado, NUNCA uma altura fixa universal.
    final category = tags['building'] ?? 'yes';
    final byCategory = categoryDefaults[category] ?? categoryDefaults['yes']!;
    return SourcedValue.defaulted(byCategory);
  }
}

/// Regra configurável de largura FÍSICA das vias (metros), por tipo/lanes.
///
/// Distinção explícita de fontes (o modelo `SourcedValue` preserva a
/// origem até a UI):
/// - conhecida: tag `width` numérica (m) — valor físico declarado;
/// - estimada: `lanes × metersPerLane`, limitada a [0.5×, 1.5×] o padrão
///   do tipo (evita, p.ex., lanes=2 → 6,4 m numa rodovia de 14 m);
/// - padrão: tabela por categoria, refinada por subtipos de `service`.
///
/// A largura RENDERIZADA é hoje igual à física (sem casing/padding
/// visual); um fator visual futuro deve entrar em `Fogo3DStyle`, nunca
/// aqui.
class RoadWidthEstimator {
  RoadWidthEstimator({this.metersPerLane = 3.2, this.minWidth = 2.0});

  final double metersPerLane;
  final double minWidth;

  static const _byType = <RoadType, double>{
    RoadType.motorway: 14,
    RoadType.trunk: 12,
    RoadType.primary: 10,
    RoadType.secondary: 9,
    RoadType.tertiary: 8,
    RoadType.unclassified: 6.5,
    RoadType.residential: 6.5,
    RoadType.livingStreet: 6,
    RoadType.service: 4,
    RoadType.pedestrian: 4,
    RoadType.footway: 2,
    RoadType.cycleway: 2,
    RoadType.path: 1.5,
    RoadType.track: 3,
    RoadType.rail: 4,
    RoadType.other: 5,
  };

  /// Padrões por subtipo de `highway=service` (becos, entradas de
  /// garagem, corredores de estacionamento são mais estreitos).
  static const _byServiceType = <String, double>{
    'alley': 3,
    'driveway': 2.5,
    'parking_aisle': 3.5,
    'drive-through': 3.5,
    'emergency_access': 5,
  };

  SourcedValue<double> estimate(Map<String, String> tags, RoadType type) {
    // 1. Largura física declarada — prevalece quando plausível.
    final widthTag = tags['width'];
    final width = widthTag == null ? null : double.tryParse(widthTag);
    if (width != null && width > 0 && width < 100) {
      return SourcedValue.known(width);
    }

    // 2. Padrão do tipo (refinado por subtipo de service).
    final typeDefault = type == RoadType.service
        ? (_byServiceType[tags['service'] ?? ''] ?? _byType[type]!)
        : _byType[type]!;

    // 3. Estimativa por faixas, SEMPRE dentro de limites sanos do tipo.
    final lanes = tags['lanes'];
    final parsedLanes = lanes == null ? null : int.tryParse(lanes);
    if (parsedLanes != null && parsedLanes > 0 && parsedLanes <= 12) {
      return SourcedValue.estimated(
        (parsedLanes * metersPerLane)
            .clamp(typeDefault * 0.5, typeDefault * 1.5)
            .clamp(minWidth, 60)
            .toDouble(),
        raw: 'lanes=$lanes',
      );
    }
    return SourcedValue.defaulted(typeDefault);
  }
}

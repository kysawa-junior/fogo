import '../domain/building.dart';
import '../domain/land_area.dart';
import '../domain/map_feature.dart';
import '../domain/pedestrian_crossing.dart';
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
  });

  final List<Road> roads;
  final List<Building> buildings;
  final List<LandArea> landAreas;
  final List<PedestrianCrossing> crossings;
  final List<TrafficSignal> signals;

  final Map<String, MapFeature> _byId = {};

  void indexAll() {
    for (final f in [
      ...roads,
      ...buildings,
      ...landAreas,
      ...crossings,
      ...signals,
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
  MapModel map(OsmDataStore store) {
    final roads = <Road>[];
    final buildings = <Building>[];
    final areas = <LandArea>[];
    final crossings = <PedestrianCrossing>[];
    final signals = <TrafficSignal>[];

    // Nodes: travessias e semáforos.
    for (final node in store.nodes) {
      final highway = node.tags['highway'];
      if (highway == 'crossing') {
        crossings.add(
          PedestrianCrossing(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: GeoCoordinate(
              node.lat,
              node.lon,
              elevation: node.elevation,
            ),
          ),
        );
      } else if (highway == 'traffic_signals') {
        signals.add(
          TrafficSignal(
            id: 'node/${node.id}',
            tags: Map<String, String>.unmodifiable(node.tags),
            position: GeoCoordinate(
              node.lat,
              node.lon,
              elevation: node.elevation,
            ),
          ),
        );
      }
    }

    for (final way in store.ways) {
      final geometry = _wayGeometry(store, way);
      final points = geometry.points;
      final nodeRefs = geometry.nodeRefs;
      final tags = way.tags;
      final id = 'way/${way.id}';

      final highway = tags['highway'];
      final isArea = tags['area'] == 'yes';
      final isBuilding =
          tags.containsKey('building') && tags['building'] != 'no';

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

      // Semântica de via (highway) antes de área: um way pode ser ruas E
      // fechado (praças `highway=pedestrian` são áreas — tratadas abaixo).
      if (highway != null &&
          highway != 'crossing' &&
          highway != 'traffic_signals' &&
          !isArea &&
          !isBuilding &&
          !way.isClosed) {
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
        buildings.add(_mapBuilding(id, tags, [outers.first, ...inners]));
      } else if (_isLandAreaTag(tags)) {
        areas.add(
          LandArea(
            id: id,
            tags: Map<String, String>.unmodifiable(tags),
            polygons: [
              [outers.first, ...inners],
            ],
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
    );
    model.indexAll();
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
      oneway: tags['oneway'] == 'yes' || tags['junction'] == 'roundabout',
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

  static bool _isLandAreaTag(Map<String, String> tags) =>
      tags.containsKey('landuse') ||
      tags.containsKey('leisure') ||
      tags.containsKey('natural') ||
      tags.containsKey('amenity') ||
      tags['highway'] == 'pedestrian' && tags['area'] == 'yes';
}

/// Regra configurável de altura de edifícios.
class BuildingHeightEstimator {
  BuildingHeightEstimator({
    this.defaultHeightMeters = 9,
    this.metersPerLevel = 3.2,
  });

  final double defaultHeightMeters;
  final double metersPerLevel;

  SourcedValue<double> estimate(Map<String, String> tags) {
    final rawHeight = tags['height'];
    final parsed = rawHeight == null ? null : double.tryParse(rawHeight);
    if (parsed != null && parsed > 0) {
      return SourcedValue.known(parsed);
    }
    final levels = tags['building:levels'];
    final parsedLevels = levels == null ? null : double.tryParse(levels);
    if (parsedLevels != null && parsedLevels > 0) {
      return SourcedValue.estimated(
        parsedLevels * metersPerLevel,
        raw: 'building:levels=$levels',
      );
    }
    return SourcedValue.defaulted(defaultHeightMeters);
  }
}

/// Regra configurável de largura de vias (metros), por tipo/lanes.
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

  SourcedValue<double> estimate(Map<String, String> tags, RoadType type) {
    final widthTag = tags['width'];
    final width = widthTag == null ? null : double.tryParse(widthTag);
    if (width != null && width > 0) {
      return SourcedValue.known(width);
    }
    final lanes = tags['lanes'];
    final parsedLanes = lanes == null ? null : int.tryParse(lanes);
    if (parsedLanes != null && parsedLanes > 0) {
      return SourcedValue.estimated(
        (parsedLanes * metersPerLane).clamp(minWidth, 40),
        raw: 'lanes=$lanes',
      );
    }
    return SourcedValue.defaulted(_byType[type] ?? 5);
  }
}

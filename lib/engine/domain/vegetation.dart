import '../geo/geo_coordinate.dart';
import 'map_feature.dart';
import '../osm/map_topology_builder.dart' show MapFeatureWithHeading;

/// Árvore individual mapeada no OSM (`natural=tree`, nó).
class Tree extends MapFeature {
  Tree({
    required super.id,
    required super.tags,
    required this.position,
    this.estimated = false,
  });

  final GeoCoordinate position;

  /// true quando a árvore é PROCEDURAL (gerada por distribuição
  /// determinística, não é dado real do OSM). Estimativas nunca são
  /// apresentadas como dados reais — a UI as diferencia.
  final bool estimated;
}

/// Água linear (rio, córrego, canal): ways `waterway=stream/river/…`.
class Waterway extends MapFeature {
  Waterway({
    required super.id,
    required super.tags,
    required this.points,
    this.widthMeters = 4,
    this.nodeRefs = const [],
  });

  final List<GeoCoordinate> points;

  /// Largura da superfície (m). Tag `width` quando presente, senão
  /// estimativa por tipo (river 8, stream 3, canal 5) — documento a
  /// origem na UI via tags.
  final double widthMeters;
  final List<int> nodeRefs;
}

/// Mobiliário urbano simples com posição real (`amenity=bench`,
/// `amenity=shelter` etc.) — apenas o que os dados sustentam.
class StreetFurniture extends MapFeature implements MapFeatureWithHeading {
  StreetFurniture({
    required super.id,
    required super.tags,
    required this.position,
    required this.kind,
    Set<String>? connectedWayIds,
  }) : connectedWayIds = connectedWayIds ?? <String>{};

  final GeoCoordinate position;
  final StreetFurnitureKind kind;

  /// Vias que contêm o nó (orientação).
  @override
  final Set<String> connectedWayIds;

  @override
  double? headingRadians;
}

/// Categorias com dados reais suficientes nos extratos.
enum StreetFurnitureKind { bench, shelter }

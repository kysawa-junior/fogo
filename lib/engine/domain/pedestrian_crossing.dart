import '../geo/geo_coordinate.dart';
import 'map_feature.dart';
import '../osm/map_topology_builder.dart' show MapFeatureWithHeading;

/// Travessia de pedestres (`highway=crossing`, nó ou via).
/// Não pertence exclusivamente a uma via: [connectedWayIds] lista TODAS as
/// vias cuja geometria contém o nó, preenchida pelo MapTopologyBuilder.
class PedestrianCrossing extends MapFeature implements MapFeatureWithHeading {
  PedestrianCrossing({
    required super.id,
    required super.tags,
    required this.position,
    Set<String>? connectedWayIds,
  }) : connectedWayIds = connectedWayIds ?? <String>{};

  /// Posição do nó de cruzamento (ou do primeiro nó da via fechada).
  final GeoCoordinate position;

  /// Vias associadas — múltiplas quando o cruzamento une várias vias.
  @override
  final Set<String> connectedWayIds;

  /// Orientação sugerida para o desenho: direção da via principal
  /// conectada (graus, 0 = leste). Preenchida pela topologia.
  @override
  double? headingRadians;
}

/// Semáforo (`highway=traffic_signals`, nó ou via de stop line).
/// Assim como a travessia, pode estar associado a múltiplas vias.
class TrafficSignal extends MapFeature implements MapFeatureWithHeading {
  TrafficSignal({
    required super.id,
    required super.tags,
    required this.position,
    Set<String>? connectedWayIds,
  }) : connectedWayIds = connectedWayIds ?? <String>{};

  final GeoCoordinate position;
  @override
  final Set<String> connectedWayIds;
  @override
  double? headingRadians;
}

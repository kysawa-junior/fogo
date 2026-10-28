import '../geo/geo_coordinate.dart';
import 'map_feature.dart';
import '../osm/map_topology_builder.dart' show MapFeatureWithHeading;

/// Marcação viária no pavimento (ETAPA 05): linha de parada
/// (`highway=stop`/`give_way`) ou dispositivo redutor
/// (`traffic_calming=bump/hump/table`). Entidade semântica — o mesh é
/// escolhido pelo builder conforme o [kind]; posição e orientação vêm
/// SEMPRE do nó OSM real, conectadas às vias que o contêm.
class RoadMarking extends MapFeature implements MapFeatureWithHeading {
  RoadMarking({
    required super.id,
    required super.tags,
    required this.position,
    required this.kind,
    Set<String>? connectedWayIds,
  }) : connectedWayIds = connectedWayIds ?? <String>{};

  final GeoCoordinate position;
  final RoadMarkingKind kind;

  /// Vias que contêm o nó — preenchido pelo MapTopologyBuilder.
  @override
  final Set<String> connectedWayIds;

  /// Orientação da via principal conectada (radianos, 0 = leste).
  @override
  double? headingRadians;
}

/// Forma da marcação — decide o mesh e apenas ela.
enum RoadMarkingKind {
  /// Barra transversal de retenção (`highway=stop`).
  stop,

  /// Barra transversal de preferência (`highway=give_way`) — mesma
  /// geometria de barra (triângulos exigiriam dado inexistente).
  giveWay,

  /// Lombada/quebra-molas (`traffic_calming`) — plataforma elevada na
  /// cor da via conectada.
  trafficCalming,
}

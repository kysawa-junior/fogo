import 'dart:math' as math;

import '../domain/road.dart';
import '../domain/road_network.dart';
import '../geo/geo_coordinate.dart';
import 'osm_elements.dart';
import 'osm_feature_mapper.dart' show MapModel;

/// Constrói a [RoadNetwork] a partir do modelo interpretado:
/// - nós compartilhados entre vias = junções reais;
/// - segmentos = trechos de via entre junções;
/// - travessias e semáforos conectados às vias que contêm o nó deles.
///
/// Vias que se cruzam geometricamente SEM nó compartilhado (viadutos,
/// níveis distintos) NÃO são conectadas — cruzamento visual não é
/// conexão topológica.
class MapTopologyBuilder {
  RoadNetwork build(MapModel model, OsmDataStore store) {
    final network = RoadNetwork();

    // Uso de cada nó OSM por vias distintas (road.id completo).
    final usage = <int, Set<String>>{};
    for (final road in model.roads) {
      for (final ref in road.nodeRefs) {
        usage.putIfAbsent(ref, () => {}).add(road.id);
      }
    }

    final roadsByRef = <int, List<Road>>{};
    for (final road in model.roads) {
      for (final ref in road.nodeRefs) {
        roadsByRef.putIfAbsent(ref, () => []).add(road);
      }
    }

    for (final road in model.roads) {
      if (road.nodeRefs.isEmpty) continue;
      var segStart = 0;
      for (var i = 0; i < road.nodeRefs.length; i++) {
        final ref = road.nodeRefs[i];
        final isJunction = (usage[ref]?.length ?? 0) > 1;
        final isLast = i == road.nodeRefs.length - 1;
        if (!isJunction && !isLast) continue;
        _ensureNode(network, ref, store, usage);
        if (segStart != i) {
          _ensureNode(network, road.nodeRefs[segStart], store, usage);
          network.addSegment(
            RoadSegment(
                id: '${road.id}#$segStart-$i',
                roadId: road.id,
                startNodeId: 'node/${road.nodeRefs[segStart]}',
                endNodeId: 'node/$ref',
              )
              ..pointStart = segStart
              ..pointEnd = i,
          );
        }
        segStart = i;
      }
    }

    final nodeRefToRoads = roadsByRef;
    for (final crossing in model.crossings) {
      final ref = _nodeRefOf(crossing.id);
      if (ref != null) _attach(crossing, ref, nodeRefToRoads);
    }
    for (final signal in model.signals) {
      final ref = _nodeRefOf(signal.id);
      if (ref != null) _attach(signal, ref, nodeRefToRoads);
    }
    return network;
  }

  /// Preenche connectedWayIds (todas as vias que contêm o nó) e o heading
  /// da primeira via conectada (direção do trecho no nó, radianos;
  /// convenção: ângulo a partir do leste, anti-horário, plano x/z).
  void _attach(
    MapFeatureWithHeading feature,
    int ref,
    Map<int, List<Road>> roads,
  ) {
    final roadsAt = roads[ref];
    if (roadsAt == null) return;
    double? heading;
    for (final road in roadsAt) {
      feature.connectedWayIds.add(road.id);
      heading ??= _headingAt(road, ref);
    }
    feature.headingRadians = heading;
  }

  void _ensureNode(
    RoadNetwork network,
    int ref,
    OsmDataStore store,
    Map<int, Set<String>> usage,
  ) {
    final id = 'node/$ref';
    if (network.nodes.containsKey(id)) return;
    final node = store.nodeById(ref);
    if (node == null) {
      store.issues.add(
        OsmImportIssue(
          'Nó $ref da rede viária ausente no store.',
          elementId: id,
        ),
      );
      return;
    }
    network.addNode(
      RoadNode(
        id: id,
        position: GeoCoordinate(node.lat, node.lon, elevation: node.elevation),
        wayIds: usage[ref] ?? const <String>{},
      ),
    );
  }

  /// Direção da via no nó `ref`, no plano horizontal:
  /// atan2(Δleste, Δnorte) — 0 = leste, π/2 = norte.
  double? _headingAt(Road road, int ref) {
    final idx = road.nodeRefs.indexOf(ref);
    if (idx < 0 || road.points.length < 2) return null;
    final b = road.points[idx];
    final a = idx + 1 < road.points.length
        ? road.points[idx + 1]
        : road.points[idx - 1];
    return math.atan2(a.longitude - b.longitude, a.latitude - b.latitude);
  }

  static int? _nodeRefOf(String featureId) {
    final parts = featureId.split('/');
    return parts.length == 2 && parts[0] == 'node'
        ? int.tryParse(parts[1])
        : null;
  }
}

/// Travessias e semáforos compartilham o contrato de associação com vias.
abstract class MapFeatureWithHeading {
  Set<String> get connectedWayIds;
  double? get headingRadians;
  set headingRadians(double? value);
}

import '../geo/geo_coordinate.dart';

/// Nó da rede viária: um nó OSM compartilhado entre vias (junção real).
/// Nós que apenas pertencem a uma única via também entram na rede como
/// pontos de articulação da geometria.
class RoadNode {
  RoadNode({required this.id, required this.position, required this.wayIds});

  /// Id estável: o próprio id do nó OSM.
  final String id;
  final GeoCoordinate position;

  /// Vias que contêm este nó.
  final Set<String> wayIds;

  bool get isJunction => wayIds.length > 1;
}

/// Segmento de via entre dois nós consecutivos da rede. A segmentação
/// acontece em nós compartilhados (junções reais), permitindo consultas de
/// conectividade e roteamento futuro sem reestruturar o domínio.
class RoadSegment {
  RoadSegment({
    required this.id,
    required this.roadId,
    required this.startNodeId,
    required this.endNodeId,
  });

  /// Id estável: `wayId/startNodeRef:endNodeRef`.
  final String id;

  /// Via (entidade Road) à qual o segmento pertence.
  final String roadId;
  final String startNodeId;
  final String endNodeId;

  /// Membros de [RoadNetwork] — não guardam geometria duplicada; a
  /// geometria vive na via (índices [pointRange] na polilinha da Road).
  int pointStart = 0;
  int pointEnd = 0;

  bool get connectsSameNode => startNodeId == endNodeId;
}

/// Rede viária: conectividade explícita por NÓS COMPARTILHADOS.
/// Duas vias que se cruzam geometricamente SEM compartilhar nó (viaduto ×
/// via underneath) NÃO ficam conectadas — cruzamento visual não é
/// conexão topológica.
class RoadNetwork {
  final Map<String, RoadNode> nodes = {};
  final Map<String, RoadSegment> segments = {};

  void addNode(RoadNode node) => nodes[node.id] = node;
  void addSegment(RoadSegment segment) => segments[segment.id] = segment;

  /// Segmentos que saem/chegam a um nó (conectividade).
  Iterable<RoadSegment> segmentsAtNode(String nodeId) => segments.values.where(
    (s) => s.startNodeId == nodeId || s.endNodeId == nodeId,
  );

  /// Nós vizinhos conectados por algum segmento.
  Iterable<String> neighborNodeIds(String nodeId) =>
      segmentsAtNode(nodeId)
          .map((s) => s.startNodeId == nodeId ? s.endNodeId : s.startNodeId);

  /// Nós de junção (compartilhados por 2+ vias).
  Iterable<RoadNode> get junctions => nodes.values.where((n) => n.isJunction);
}

import 'dart:math' as math;

import '../../../../engine/fogo_engine.dart';
import '../../../../engine/domain/road_type.dart';

/// Rótulo cartográfico candidato (ETAPA 08).
class LabelCandidate {
  const LabelCandidate({
    required this.text,
    required this.worldPoint,
    required this.priority,
    required this.maxDistanceMeters,
    this.tangentX = 0,
    this.tangentZ = 0,
  });

  final String text;
  final Vector3 worldPoint;

  /// Prioridade: menor = mais importante (vence colisão).
  final int priority;

  /// Distância máxima da câmera em que aparece (LOD de rótulo).
  final double maxDistanceMeters;

  /// Direção da via no ponto do rótulo (unidade, mundo XZ) — o texto é
  /// pintado AO LONGO da rua, como decal. (0,0) = horizontal no mundo
  /// (áreas/POIs, giram com o mapa).
  final double tangentX;
  final double tangentZ;
}

/// Extrai candidatos do modelo: prioridade cartográfica por categoria.
List<LabelCandidate> extractLabelCandidates(FogoEngine engine) {
  final labels = <LabelCandidate>[];
  final projector = engine.projector;

  // Vias: nome no ponto médio.
  for (final road in engine.model.roads) {
    final name = road.name;
    if (name == null || name.isEmpty) continue;
    if (road.points.isEmpty) continue;
    final points = [for (final point in road.points) projector.project(point)];
    var pathLength = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dz = points[i].z - points[i - 1].z;
      pathLength += math.sqrt(dx * dx + dz * dz);
    }
    final targetDistance = pathLength / 2;
    var distance = 0.0;
    var x = points.first.x;
    var z = points.first.z;
    // Tangente do segmento onde o rótulo cai (direção da via ali).
    var tx = 0.0, tz = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final dx = b.x - a.x;
      final dz = b.z - a.z;
      final segmentLength = math.sqrt(dx * dx + dz * dz);
      if (segmentLength > 0 && distance + segmentLength >= targetDistance) {
        final t = ((targetDistance - distance) / segmentLength)
            .clamp(0.0, 1.0)
            .toDouble();
        x = a.x + dx * t;
        z = a.z + dz * t;
        tx = dx / segmentLength;
        tz = dz / segmentLength;
        break;
      }
      distance += segmentLength;
    }
    final (priority, maxDist) = _roadLabelPolicy(road.type);
    labels.add(
      LabelCandidate(
        text: name,
        worldPoint: Vector3(x, 0, z),
        priority: priority,
        maxDistanceMeters: maxDist,
        tangentX: tx,
        tangentZ: tz,
      ),
    );
  }

  // Áreas (parques, água): nome no centro do primeiro polígono.
  for (final area in engine.model.landAreas) {
    final name = area.name;
    if (name == null || name.isEmpty) continue;
    if (area.polygons.isEmpty || area.polygons.first.isEmpty) continue;
    final outer = area.polygons.first.first;
    if (outer.isEmpty) continue;
    var lat = 0.0, lon = 0.0;
    for (final p in outer) {
      lat += p.latitude;
      lon += p.longitude;
    }
    final pos = projector.project(
      GeoCoordinate(lat / outer.length, lon / outer.length),
    );
    labels.add(
      LabelCandidate(
        text: name,
        worldPoint: Vector3(pos.x, 0, pos.z),
        priority: 2,
        maxDistanceMeters: 4000,
      ),
    );
  }

  // POIs com posição real (com disco) e rótulos puros entram como
  // candidatos de rótulo; prioridade decide colisão.
  for (final poi in engine.model.pois) {
    final name = poi.name;
    if (name == null || name.isEmpty) continue;
    final pos = projector.project(poi.position);
    final rank = poi.rank ?? 9;
    labels.add(
      LabelCandidate(
        text: name,
        worldPoint: Vector3(pos.x, 0, pos.z),
        // Rótulos puros (lugares/acidentes) vencem POIs em colisão.
        priority: poi.marker ? 4 + rank.clamp(0, 5) : 3,
        maxDistanceMeters: poi.marker ? 1200 : 8000,
      ),
    );
  }

  return labels;
}

(int, double) _roadLabelPolicy(RoadType type) {
  switch (type) {
    case RoadType.motorway:
    case RoadType.trunk:
    case RoadType.primary:
      return (1, double.infinity);
    case RoadType.secondary:
    case RoadType.tertiary:
      return (2, 6000);
    case RoadType.residential:
    case RoadType.unclassified:
    case RoadType.livingStreet:
      return (3, 2000);
    default:
      return (4, 800);
  }
}

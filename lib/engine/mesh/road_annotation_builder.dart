import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/road.dart';
import '../domain/road_properties.dart';
import '../geo/coordinate_projector.dart';
import '../geometry/mesh_data.dart';
import '../scene/road_annotations.dart';

class RoadAnnotationGeometry {
  RoadAnnotationGeometry({
    required this.roadName,
    required List<RoadArrowGeometry> arrows,
  }) : arrows = List.unmodifiable(arrows);

  final RoadNamePlacement? roadName;
  final List<RoadArrowGeometry> arrows;
}

class RoadArrowGeometry {
  RoadArrowGeometry({required this.center, required this.mesh})
    : bounds = mesh.computeBounds()!;

  /// Arrow's station/lane center; used for spatial tile ownership.
  final Vector3 center;
  final MeshData mesh;
  final WorldBounds bounds;
}

/// Engine-only road annotation placement and filled-arrow geometry.
abstract final class RoadAnnotationBuilder {
  static const double arrowSpacingMeters = 45;
  static const double surfaceLiftMeters = 0.04;

  static RoadAnnotationGeometry build({
    required Road road,
    required List<Vector3> centerline,
    required double roadSurfaceY,
  }) {
    final width = road.properties.widthMeters?.value ?? 5.0;
    final path = _RoadPath(centerline);
    if (width <= 0 ||
        !width.isFinite ||
        path.length <= 0 ||
        !path.length.isFinite) {
      return RoadAnnotationGeometry(roadName: null, arrows: const []);
    }

    final roadName = _roadNamePlacement(
      road,
      path,
      width,
      roadSurfaceY + surfaceLiftMeters,
    );
    final arrows = <RoadArrowGeometry>[];
    for (final distance in _arrowStations(path.length)) {
      final sample = path.sampleAt(distance);
      final directions = switch (road.properties.direction) {
        RoadDirection.both => const [true, false],
        RoadDirection.forward => const [true],
        RoadDirection.reverse => const [false],
      };
      for (final forward in directions) {
        final direction = forward ? sample.tangent : -sample.tangent;
        final laneOffset = road.properties.direction == RoadDirection.both
            ? width / 4 * (forward ? 1 : -1)
            : 0.0;
        final normal = Vector3(-sample.tangent.z, 0, sample.tangent.x);
        final arrowCenter = Vector3(
          sample.point.x + normal.x * laneOffset,
          roadSurfaceY + surfaceLiftMeters,
          sample.point.z + normal.z * laneOffset,
        );
        final availableLength = path.isClosed
            ? path.length
            : 2 * math.min(distance, path.length - distance);
        final arrowLength = math.min(width * 0.9, availableLength).toDouble();
        if (arrowLength <= 0) continue;
        final mesh = _arrowMesh(
          arrowCenter,
          direction,
          length: arrowLength,
          roadWidth: width,
        );
        arrows.add(RoadArrowGeometry(center: arrowCenter, mesh: mesh));
      }
    }
    return RoadAnnotationGeometry(roadName: roadName, arrows: arrows);
  }

  /// Combines per-arrow meshes for one tile without retaining source entities.
  static MeshData? mergeArrowMeshes(Iterable<MeshData> source) =>
      MeshData.merge(source);

  static RoadNamePlacement? _roadNamePlacement(
    Road road,
    _RoadPath path,
    double roadWidth,
    double y,
  ) {
    final text = road.name;
    if (text == null || text.trim().isEmpty || path.points.length < 2) {
      return null;
    }

    var bestScore = -double.infinity;
    var bestLength = 0.0;
    var bestMidpoint = 0.0;
    for (var start = 0; start < path.points.length - 1; start++) {
      for (var end = start + 1; end < path.points.length; end++) {
        final arcLength = path.cumulative[end] - path.cumulative[start];
        if (arcLength <= 0) {
          continue;
        }
        final a = path.points[start];
        final b = path.points[end];
        final dx = b.x - a.x;
        final dz = b.z - a.z;
        final chordLength = math.sqrt(dx * dx + dz * dz);
        if (chordLength <= 0) {
          continue;
        }
        // Maximize useful span while penalizing curvature, with no angle cutoff.
        final score = chordLength * chordLength / arcLength;
        if (score > bestScore ||
            score == bestScore && chordLength > bestLength) {
          bestScore = score;
          bestLength = chordLength;
          bestMidpoint = (path.cumulative[start] + path.cumulative[end]) / 2;
        }
      }
    }
    if (bestLength <= 0) return null;
    final sample = path.sampleAt(bestMidpoint);
    final center = Vector3(sample.point.x, y, sample.point.z);
    final maxHeight = roadWidth;
    return RoadNamePlacement(
      text: text,
      center: center,
      tangent: sample.tangent,
      maxLengthMeters: bestLength,
      maxHeightMeters: maxHeight,
      bounds: _orientedBounds(center, sample.tangent, bestLength, maxHeight),
    );
  }

  static Iterable<double> _arrowStations(double pathLength) sync* {
    if (pathLength < arrowSpacingMeters) {
      yield pathLength / 2;
      return;
    }
    for (
      var distance = arrowSpacingMeters / 2;
      distance < pathLength;
      distance += arrowSpacingMeters
    ) {
      yield distance;
    }
  }

  static MeshData _arrowMesh(
    Vector3 center,
    Vector3 tangent, {
    required double length,
    required double roadWidth,
  }) {
    final halfLength = length / 2;
    final headHalfWidth = math.min(roadWidth * 0.28, length * 0.32);
    final shaftHalfWidth = math.min(roadWidth * 0.08, headHalfWidth / 2);
    final headBase = length * 0.08;
    final normal = Vector3(-tangent.z, 0, tangent.x);
    final shape = <(double along, double across)>[
      (halfLength, 0),
      (headBase, headHalfWidth),
      (headBase, shaftHalfWidth),
      (-halfLength, shaftHalfWidth),
      (-halfLength, -shaftHalfWidth),
      (headBase, -shaftHalfWidth),
      (headBase, -headHalfWidth),
    ];
    final vertices = [
      for (final (along, across) in shape)
        Vector3(
          center.x + tangent.x * along + normal.x * across,
          center.y,
          center.z + tangent.z * along + normal.z * across,
        ),
    ];
    final positions = Float32List(vertices.length * 3);
    final normals = Float32List(vertices.length * 3);
    for (var i = 0; i < vertices.length; i++) {
      positions[i * 3] = vertices[i].x;
      positions[i * 3 + 1] = vertices[i].y;
      positions[i * 3 + 2] = vertices[i].z;
      normals[i * 3 + 1] = 1;
    }
    final indices = <int>[];
    for (var i = 1; i < vertices.length - 1; i++) {
      indices.addAll([0, i + 1, i]);
    }
    return MeshData(
      positions: positions,
      normals: normals,
      indices: Uint32List.fromList(indices),
    );
  }

  static WorldBounds _orientedBounds(
    Vector3 center,
    Vector3 tangent,
    double length,
    double height,
  ) {
    final normal = Vector3(-tangent.z, 0, tangent.x);
    final halfLength = length / 2;
    final halfHeight = height / 2;
    final corners = [
      for (final along in [-halfLength, halfLength])
        for (final across in [-halfHeight, halfHeight])
          Vector3(
            center.x + tangent.x * along + normal.x * across,
            center.y,
            center.z + tangent.z * along + normal.z * across,
          ),
    ];
    var minX = corners.first.x, maxX = corners.first.x;
    var minZ = corners.first.z, maxZ = corners.first.z;
    for (final corner in corners.skip(1)) {
      minX = math.min(minX, corner.x);
      maxX = math.max(maxX, corner.x);
      minZ = math.min(minZ, corner.z);
      maxZ = math.max(maxZ, corner.z);
    }
    return Aabb3.minMax(
      Vector3(minX, center.y, minZ),
      Vector3(maxX, center.y, maxZ),
    );
  }
}

class _RoadPath {
  _RoadPath(List<Vector3> source) {
    final points = <Vector3>[];
    for (final point in source) {
      if (!point.x.isFinite || !point.z.isFinite) continue;
      if (points.isNotEmpty &&
          point.x == points.last.x &&
          point.z == points.last.z) {
        continue;
      }
      points.add(point);
    }
    this.points = List.unmodifiable(points);
    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dz = points[i].z - points[i - 1].z;
      cumulative.add(cumulative.last + math.sqrt(dx * dx + dz * dz));
    }
    this.cumulative = List.unmodifiable(cumulative);
    length = cumulative.isEmpty ? 0 : cumulative.last;
    isClosed =
        points.length > 2 &&
        points.first.x == points.last.x &&
        points.first.z == points.last.z;
  }

  late final List<Vector3> points;
  late final List<double> cumulative;
  late final double length;
  late final bool isClosed;

  ({Vector3 point, Vector3 tangent}) sampleAt(double distance) {
    for (var i = 0; i < points.length - 1; i++) {
      final end = cumulative[i + 1];
      if (distance < end || i == points.length - 2) {
        final segmentLength = end - cumulative[i];
        final t = segmentLength == 0
            ? 0.0
            : ((distance - cumulative[i]) / segmentLength).clamp(0.0, 1.0);
        final a = points[i];
        final b = points[i + 1];
        final tangent = Vector3(b.x - a.x, 0, b.z - a.z).normalized();
        return (
          point: Vector3(a.x + (b.x - a.x) * t, 0, a.z + (b.z - a.z) * t),
          tangent: tangent,
        );
      }
    }
    return (point: points.last, tangent: Vector3(1, 0, 0));
  }
}

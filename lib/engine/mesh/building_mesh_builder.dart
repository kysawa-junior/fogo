import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import '../geometry/polygon_triangulator.dart';

/// Edifício extrudado: paredes por anel (externo + buracos, com
/// orientação invertida nos buracos — pátios visíveis de dentro) e laje
/// de cobertura triangulada com os buracos recortados.
///
/// Altura vem da entidade (conhecida/estimada/padrão — o builder apenas
/// extruda o valor recebido). Polígonos inválidos devolvem null e o
/// chamador registra issue.
abstract final class BuildingMeshBuilder {
  /// `rings[0]` = contorno externo; demais = buracos. Coordenadas já
  /// projetadas, solo em y≈0 (a elevação do footprint é respeitada via
  /// `minHeight` quando presente).
  static MeshData? build(
    List<List<Vector3>> rings, {
    required double heightMeters,
    double? minHeightMeters,
  }) {
    if (rings.isEmpty || heightMeters <= 0) return null;
    final outer = rings[0];
    if (outer.length < 3) return null;
    final holes = rings.length > 1 ? rings.sublist(1) : const <List<Vector3>>[];
    final base = minHeightMeters ?? 0;
    final top = base + heightMeters;

    final vertices = <Vector3>[];
    final normals = <Vector3>[];
    final triangles = <int>[];

    // Paredes: quads por aresta de cada anel. Anéis normalizados para
    // orientação canônica (externo: área > 0 no plano x/z; buracos:
    // oposta), garantindo normais externas consistentes.
    for (var ringIdx = 0; ringIdx < rings.length; ringIdx++) {
      final isHole = ringIdx > 0;
      final prepared = _dedupeClosed(rings[ringIdx]);
      if (prepared.length < 3) continue;
      final ring = _oriented(prepared, positive: !isHole);
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i];
        final b = ring[(i + 1) % ring.length];
        final wallNormal = _wallNormal(a, b, flip: isHole);
        final i0 = vertices.length;
        vertices
          ..add(Vector3(a.x, base + a.y, a.z))
          ..add(Vector3(b.x, base + b.y, b.z))
          ..add(Vector3(a.x, top + a.y, a.z))
          ..add(Vector3(b.x, top + b.y, b.z));
        for (var k = 0; k < 4; k++) {
          normals.add(wallNormal);
        }
        // Dois triângulos; winding flipado p/ buracos (normal p/ dentro).
        if (isHole) {
          triangles.addAll([i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2]);
        } else {
          triangles.addAll([i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3]);
        }
      }
    }

    // Cobertura: anel externo com buracos recortados, no plano y=top.
    final roof = PolygonTriangulator.triangulate(
      [for (final p in outer) Vector3(p.x, 0, p.z)],
      [
        for (final h in holes) [for (final p in h) Vector3(p.x, 0, p.z)],
      ],
    );
    if (roof == null) return null;
    for (final v in roof.vertices) {
      vertices.add(Vector3(v.x, top, v.z));
      normals.add(Vector3(0, 1, 0));
    }
    triangles.addAll(roof.triangles);

    return MeshData.fromVertices(vertices, triangles, normals: normals);
  }

  /// Normal da parede do segmento a→b, apontando para fora do polígono
  /// (right-hand rule no plano x/z com Y up; flip inverte p/ buracos).
  static Vector3 _wallNormal(Vector3 a, Vector3 b, {required bool flip}) {
    final d = b - a;
    var n = Vector3(d.z, 0, -d.x);
    if (n.length2 < 1e-12) return Vector3(0, 0, 1);
    n.normalize();
    if (flip) n = -n;
    return n;
  }

  static List<Vector3> _dedupeClosed(List<Vector3> pts) {
    final out = <Vector3>[];
    for (final p in pts) {
      if (out.isNotEmpty && (out.last - p).length2 < 1e-8) continue;
      out.add(p);
    }
    if (out.length > 2 && (out.first - out.last).length2 < 1e-8) {
      out.removeLast();
    }
    return out;
  }

  /// Orienta o anel conforme [positive] (área com sinal no plano x/z).
  static List<Vector3> _oriented(List<Vector3> ring, {required bool positive}) {
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      sum += a.x * b.z - b.x * a.z;
    }
    final areaPositive = sum > 0;
    return areaPositive == positive ? ring : ring.reversed.toList();
  }
}

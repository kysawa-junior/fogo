import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import '../geometry/polygon_triangulator.dart';

/// Placa 3D (slab) GENÉRICA: laje superior triangulada + saias
/// verticais (paredes) na borda, do topo até a base. A espessura real
/// elimina QUALQUER z-fighting com o plano por baixo — não depende de
/// depthLayer nem de separação sutil de Y. Usada pela ÁGUA (o
/// conflito Park×Water que motivou o builder) e pelas plataformas dos
/// edifícios de interesse (posto, delegacia, hospital, templo).
///
/// Sem face inferior (nunca visível por baixo; terreno cobre). Anéis
/// orientados como em [BuildingMeshBuilder] (externo positivo, buracos
/// invertidos) → saias sempre com normal PARA FORA da água (ilhas
/// recebem parede voltada para a ilha).
abstract final class SlabMeshBuilder {
  /// `rings[0]` = contorno externo; demais = buracos (ilhas).
  /// Coordenadas já projetadas (x/z planos, y ignorado — o slab usa
  /// [top]/[bottom] absolutos).
  static MeshData? build(
    List<List<Vector3>> rings, {
    required double top,
    required double bottom,
  }) {
    if (rings.isEmpty || bottom >= top) return null;
    final outerPrepared = _oriented(_dedupeClosed(rings[0]), positive: true);
    if (outerPrepared.length < 3) return null;
    final holeRings = <List<Vector3>>[
      for (final h in rings.skip(1))
        if (_dedupeClosed(h).length >= 3)
          _oriented(_dedupeClosed(h), positive: false),
    ];

    final vertices = <Vector3>[];
    final normals = <Vector3>[];
    final triangles = <int>[];

    // Laje superior (normais para cima, buracos recortados).
    final topTri = PolygonTriangulator.triangulate(
      [for (final p in outerPrepared) Vector3(p.x, top, p.z)],
      [
        for (final h in holeRings) [for (final p in h) Vector3(p.x, top, p.z)],
      ],
    );
    if (topTri == null) return null;

    // Saias: quad vertical por aresta de cada anel. Orientação do anel
    // garante normal externa (mesma regra das paredes de edifício).
    final allRings = [outerPrepared, ...holeRings];
    for (final ring in allRings) {
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i];
        final b = ring[(i + 1) % ring.length];
        final n = _wallNormal(a, b);
        final i0 = vertices.length;
        vertices
          ..add(Vector3(a.x, top, a.z))
          ..add(Vector3(b.x, top, b.z))
          ..add(Vector3(b.x, bottom, b.z))
          ..add(Vector3(a.x, bottom, a.z));
        for (var k = 0; k < 4; k++) {
          normals.add(n);
        }
        triangles.addAll([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3]);
      }
    }

    // Normais: tampa para cima + saias com normal externa.
    final topNormals = [
      for (var i = 0; i < topTri.vertices.length; i++) Vector3(0, 1, 0),
    ];
    return MeshData.fromVertices(
      [...topTri.vertices, ...vertices],
      [
        ...topTri.triangles,
        ...triangles.map((t) => t + topTri.vertices.length),
      ],
      normals: [...topNormals, ...normals],
    );
  }

  /// Normal do segmento a→b com anel orientado positivo (área > 0):
  /// aponta para fora do polígono (direita da marcha... esquerda —
  /// mesma regra validada em [BuildingMeshBuilder._wallNormal]).
  static Vector3 _wallNormal(Vector3 a, Vector3 b) {
    final d = b - a;
    var n = Vector3(d.z, 0, -d.x);
    if (n.length2 < 1e-12) return Vector3(0, 0, 1);
    return n.normalized();
  }

  static List<Vector3> _dedupeClosed(List<Vector3> pts) {
    final out = <Vector3>[];
    for (final p in pts) {
      if (out.isNotEmpty && _distXZ2(out.last, p) < 1e-4) continue;
      out.add(p);
    }
    if (out.length > 2 && _distXZ2(out.first, out.last) < 1e-4) {
      out.removeLast();
    }
    return out;
  }

  static double _distXZ2(Vector3 a, Vector3 b) {
    final dx = a.x - b.x, dz = a.z - b.z;
    return dx * dx + dz * dz;
  }

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

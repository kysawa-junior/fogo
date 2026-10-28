import 'package:vector_math/vector_math_64.dart';

import 'mesh_data.dart';

/// Triangulação de polígonos 2D (projeção no plano x/z do motor) com
/// suporte a buracos, via ear-clipping com "hole bridging": cada anel
/// interno é emendado ao anel externo por um corte de largura zero.
///
/// Robustez v1: polígonos com menos de 3 vértices, anéis degenerados ou
/// buracos fora do contorno retornam lista vazia (o chamador registra
/// issue e segue) — geometria inválida não derruba a importação.
abstract final class PolygonTriangulator {
  /// Triangula [outer] com [holes]; devolve os vértices efetivos (anel
  /// externo emendado com os buracos) e os índices dos triângulos, ou
  /// null quando o polígono é inválido.
  static ({List<Vector3> vertices, List<int> triangles})? triangulate(
    List<Vector3> outer,
    List<List<Vector3>> holes,
  ) {
    final preparedOuter = _prepare(outer);
    if (preparedOuter == null) return null;
    var ring = preparedOuter;
    for (final hole in holes) {
      final preparedHole = _prepare(hole);
      if (preparedHole == null) continue;
      final bridged = _bridge(ring, preparedHole);
      if (bridged == null) return null;
      ring = bridged;
    }
    final triangles = _earClip(ring);
    if (triangles == null) return null;
    // Descarta slivers (área < 1 cm²): orelhas quase colineares são
    // geometricamente inertes e poluem a malha — nenhum triângulo
    // degenerado no resultado.
    final kept = <int>[];
    for (var i = 0; i < triangles.length; i += 3) {
      final a = ring[triangles[i]];
      final b = ring[triangles[i + 1]];
      final c = ring[triangles[i + 2]];
      final area2 = ((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x))
          .abs();
      if (area2 >= 2e-4) {
        kept.addAll([triangles[i], triangles[i + 1], triangles[i + 2]]);
      }
    }
    if (kept.isEmpty) return null;
    return (vertices: ring, triangles: kept);
  }

  /// Remove vértice duplicado do fechamento (primeiro == último) e
  /// descarta duplicatas consecutivas; null se sobrar < 3 vértices.
  static List<Vector3>? _prepare(List<Vector3> pts) {
    final out = <Vector3>[];
    for (final p in pts) {
      if (out.isNotEmpty && _same(out.last, p)) continue;
      out.add(p);
    }
    if (out.length > 2 && _same(out.first, out.last)) out.removeLast();
    return out.length < 3 ? null : out;
  }

  /// Igualdade no plano XZ (a triangulação é de superfícies horizontais:
  /// nós duplicados em lat/lon com `ele` divergente são o mesmo vértice).
  static bool _same(Vector3 a, Vector3 b) {
    const eps = 1e-6;
    return (a.x - b.x).abs() < eps && (a.z - b.z).abs() < eps;
  }

  static double _area(List<Vector3> ring) {
    var sum = 0.0;
    for (var i = 0, n = ring.length; i < n; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % n];
      sum += a.x * b.z - b.x * a.z;
    }
    return sum / 2;
  }

  /// Emenda um buraco ao anel atual: encontra par mutuamente visível
  /// (vértice de maior x do buraco → vértice do anel mais externo na
  /// direção) e costura duplicando vértices. Retorna o novo anel.
  static List<Vector3>? _bridge(List<Vector3> ring, List<Vector3> hole) {
    // Buraco precisa estar em orientação oposta ao anel.
    final ringArea = _area(ring);
    final holeArea = _area(hole);
    if (ringArea > 0 && holeArea > 0) {
      hole = hole.reversed.toList();
    } else if (ringArea < 0 && holeArea < 0) {
      hole = hole.reversed.toList();
    }
    var hIdx = 0;
    for (var i = 1; i < hole.length; i++) {
      if (hole[i].x > hole[hIdx].x) hIdx = i;
    }
    var rIdx = -1;
    var best = -double.infinity;
    for (var i = 0; i < ring.length; i++) {
      if (ring[i].x < hole[hIdx].x) continue;
      final score = ring[i].x - (ring[i] - hole[hIdx]).length;
      if (score > best) {
        best = score;
        rIdx = i;
      }
    }
    if (rIdx < 0) {
      // Buraco totalmente à esquerda de todo o anel (fora do contorno na
      // prática): polígono inválido para renderização simples.
      return null;
    }
    return <Vector3>[
      ...ring.sublist(0, rIdx + 1),
      ..._rotated(hole, hIdx),
      hole[hIdx],
      ring[rIdx],
      ...ring.sublist(rIdx + 1),
    ];
  }

  static List<Vector3> _rotated(List<Vector3> list, int start) => [
    for (var i = 0; i < list.length; i++) list[(start + i) % list.length],
  ];

  /// Ear clipping clássico. Triângulo (a,b,c) tem normal +Y quando o
  /// cross abaixo é NEGATIVO no plano x/z (y = −cross); a reversão
  /// inicial deixa o anel nessa orientação canônica.
  static List<int>? _earClip(List<Vector3> ring) {
    final needsReverse = _area(ring) > 0;
    var list = [for (var i = 0; i < ring.length; i++) i];
    if (needsReverse) list = list.reversed.toList();
    final triangles = <int>[];
    var guard = 0;
    while (list.length > 3 && guard++ < 10000) {
      var clipped = false;
      for (var i = 0; i < list.length; i++) {
        final a = list[(i + list.length - 1) % list.length];
        final b = list[i];
        final c = list[(i + 1) % list.length];
        if (_isEar(ring, list, a, b, c)) {
          triangles.addAll([a, b, c]);
          list.removeAt(i);
          clipped = true;
          break;
        }
      }
      if (!clipped) return triangles.isEmpty ? null : triangles;
    }
    if (list.length == 3) triangles.addAll(list);
    return triangles;
  }

  static bool _isEar(
    List<Vector3> ring,
    List<int> remaining,
    int a,
    int b,
    int c,
  ) {
    final pa = ring[a];
    final pb = ring[b];
    final pc = ring[c];
    final cross = (pb.x - pa.x) * (pc.z - pa.z) - (pb.z - pa.z) * (pc.x - pa.x);
    if (cross >= 0) return false; // reflexo/colinear fora da orientação
    for (final other in remaining) {
      if (other == a || other == b || other == c) continue;
      if (_pointInTriangle(ring[other], pa, pb, pc)) return false;
    }
    return true;
  }

  static bool _pointInTriangle(Vector3 p, Vector3 a, Vector3 b, Vector3 c) {
    final d1 = _sign(p, a, b);
    final d2 = _sign(p, b, c);
    final d3 = _sign(p, c, a);
    // Ponto sobre borda não bloqueia o corte: os vértices duplicados da
    // emenda do buraco ficam exatamente nas arestas do triângulo.
    if (d1 == 0 || d2 == 0 || d3 == 0) return false;
    final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
    final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(hasNeg && hasPos);
  }

  static double _sign(Vector3 p, Vector3 a, Vector3 b) =>
      (p.x - b.x) * (a.z - b.z) - (a.x - b.x) * (p.z - b.z);

  /// Conveniência: triangula polígono no plano y=constante e devolve
  /// MeshData pronta (normais para cima).
  static MeshData? triangulateFlat(
    List<Vector3> outer,
    List<List<Vector3>> holes,
    double y,
  ) {
    final flat = [for (final p in outer) Vector3(p.x, y, p.z)];
    final flatHoles = [
      for (final h in holes) [for (final p in h) Vector3(p.x, y, p.z)],
    ];
    final result = triangulate(flat, flatHoles);
    if (result == null || result.triangles.isEmpty) return null;
    return MeshData.fromVertices(result.vertices, result.triangles);
  }

  static double signedArea(List<Vector3> ring) => _area(ring);
}

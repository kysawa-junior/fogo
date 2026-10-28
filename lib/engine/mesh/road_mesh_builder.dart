import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import '../geometry/polygon_triangulator.dart';

/// Superfície de via 3D — porta da estratégia comprovada do motor 2D
/// (`road_surface/surface_builder`): contorno por LADO com
/// **interseção das linhas de offset** nas junções internas, **arco
/// circular** no lado externo das curvas, **limite de miter 2h** com
/// fallback bevel, e **capas retas** nas extremidades (cobertas pelas
/// pads de junção; sem elas, capas circulares invadiriam o cruzamento).
///
/// O contorno fechado é triangulado por ear-clipping — sem triângulos
/// degenerados (pontos duplicados são compactados) e com winding +Y.
/// Curvas e rotatórias seguem a polilinha OSM real; nada é suavizado
/// além das junções de offset.
abstract final class RoadMeshBuilder {
  static const double _pointEpsilon = 0.01;
  static const double _miterLimit = 2;

  /// `yLift` sobe a superfície (política de camadas verticais: layer·4 m,
  /// aplicada pelo chamador; pontes/túneis preservam o valor do domínio).
  static MeshData? build(
    List<Vector3> centerline,
    double widthMeters, {
    double yLift = 0,
  }) {
    final half = widthMeters / 2;
    if (half <= 0) return null;

    // Anel fechado? (rotatória, retorno, rua circular) — detecta ANTES
    // do dedupe, que remove o vértice de fechamento.
    final isRing =
        centerline.length > 2 &&
        _distXZ2(centerline.first, centerline.last) <
            _pointEpsilon * _pointEpsilon;

    final pts = _dedupe(centerline);
    if (pts.length < (isRing ? 3 : 2)) return null;

    // Direções unitárias por segmento, no plano x/z (o dedupe acima
    // garante que todo segmento tem comprimento ≥ épsilon). Anel: o
    // último segmento fecha de volta ao primeiro ponto.
    final n = pts.length;
    final segCount = isRing ? n : n - 1;
    final dirs = <Vector3>[
      for (var i = 0; i < segCount; i++)
        Vector3(
          pts[(i + 1) % n].x - pts[i].x,
          0,
          pts[(i + 1) % n].z - pts[i].z,
        ).normalized(),
    ];

    if (isRing) {
      // Anel (rotatória): dois LOOPS fechados — externo (arcos nas
      // curvas) e ilha interna (miters cortando os cantos). É um
      // polígono COM BURACO, triangulado por hole-bridging; a emenda
      // é contínua por construção (junção cíclica em todos os
      // vértices, sem capas).
      final loopA = _compact(_buildRingSide(pts, dirs, half, 1));
      final loopB = _compact(_buildRingSide(pts, dirs, half, -1));
      if (loopA.length < 3 || loopB.length < 3) return null;
      // O loop de maior área é o externo, independente do winding.
      final outerLoop = _ringArea2(loopA).abs() >= _ringArea2(loopB).abs()
          ? loopA
          : loopB;
      final holeLoop = identical(outerLoop, loopA) ? loopB : loopA;
      final outerFlat = [for (final p in outerLoop) Vector3(p.x, 0, p.z)];
      final holeFlat = [for (final p in holeLoop) Vector3(p.x, 0, p.z)];

      var tri = _ringArea2(holeLoop).abs() / 2 >= 0.5
          ? PolygonTriangulator.triangulate(outerFlat, [holeFlat])
          : null;
      // Validação de cobertura: um ear-clip parcial (stuck) deixaria a
      // via com buracos — se os triângulos não cobrem ~95% da área
      // esperada do anel, descarta e cai no sólido.
      if (tri != null && tri.triangles.isNotEmpty) {
        final covered = _coveredArea2(tri);
        final expected =
            (_ringArea2(outerLoop).abs() - _ringArea2(holeLoop).abs());
        if (covered < 0.95 * expected) tri = null;
      }
      // Ilha colapsada/inválida (anel grosso demais): pinta sólido em
      // vez de perder a via.
      tri ??= PolygonTriangulator.triangulate(outerFlat, const []);
      if (tri == null || tri.triangles.isEmpty) return null;
      return _packMesh(tri, yLift);
    }

    // Via aberta: faixa com capas retas (escondidas sob as pads de
    // junção), lados esquerdo (+1) e direito (−1) com junções por
    // interseção/arco/bevel.
    final left = _buildSide(pts, dirs, half, 1);
    final right = _buildSide(pts, dirs, half, -1);
    if (left.isEmpty || right.isEmpty) return null;
    final outline = [...left, ...right.reversed];
    final compacted = _compact(outline);
    if (compacted.length < 3) return null;

    // Triangulação robusta (winding normalizado internamente).
    final tri = PolygonTriangulator.triangulate([
      for (final p in compacted) Vector3(p.x, 0, p.z),
    ], const []);
    if (tri == null || tri.triangles.isEmpty) return null;

    return _packMesh(tri, yLift);
  }

  /// Empacota o resultado da triangulação no plano y = yLift.
  static MeshData _packMesh(
    ({List<Vector3> vertices, List<int> triangles}) tri,
    double yLift,
  ) {
    final vertexCount = tri.vertices.length;
    final positions = Float32List(vertexCount * 3);
    final normals = Float32List(vertexCount * 3);
    for (var i = 0; i < vertexCount; i++) {
      positions[i * 3] = tri.vertices[i].x;
      positions[i * 3 + 1] = yLift;
      positions[i * 3 + 2] = tri.vertices[i].z;
      normals[i * 3 + 1] = 1.0;
    }
    return MeshData(
      positions: positions,
      normals: normals,
      indices: Uint32List.fromList(tri.triangles),
    );
  }

  /// Área total (×2) dos triângulos resultantes de uma triangulação.
  static double _coveredArea2(
    ({List<Vector3> vertices, List<int> triangles}) tri,
  ) {
    var sum = 0.0;
    for (var i = 0; i < tri.triangles.length; i += 3) {
      final a = tri.vertices[tri.triangles[i]];
      final b = tri.vertices[tri.triangles[i + 1]];
      final c = tri.vertices[tri.triangles[i + 2]];
      sum += ((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)).abs();
    }
    return sum;
  }

  /// Área com sinal (×2) de um loop fechado no plano x/z.
  static double _ringArea2(List<Vector3> loop) {
    var sum = 0.0;
    for (var i = 0; i < loop.length; i++) {
      final a = loop[i];
      final b = loop[(i + 1) % loop.length];
      sum += a.x * b.z - b.x * a.z;
    }
    return sum;
  }

  /// Cadeia de offset de um lado: capas retas nas pontas e junção por
  /// vértice interno conforme o lado (externo = arco, interno = miter).
  static List<Vector3> _buildSide(
    List<Vector3> pts,
    List<Vector3> dirs,
    double half,
    int side,
  ) {
    // Ponta inicial: seção reta perpendicular ao primeiro segmento.
    final chain = <Vector3>[_offset(pts.first, dirs.first, side, half)];
    for (var i = 1; i < pts.length - 1; i++) {
      chain.addAll(_join(pts[i], dirs[i - 1], dirs[i], side, half));
    }
    chain.add(_offset(pts.last, dirs.last, side, half));
    return chain;
  }

  /// Junção de offset num vértice interno — lógica do motor 2D:
  /// - sem curva: ponto único;
  /// - quase reversão: bevel (dois pontos);
  /// - lado externo da curva: arco circular (passos de 15°, máx. 24);
  /// - lado interno: interseção das retas de offset; instável ou além
  ///   de 2h → bevel. Nenhum pico de miter escapa do limite.
  static List<Vector3> _join(
    Vector3 vertex,
    Vector3 before,
    Vector3 after,
    int side,
    double half,
  ) {
    final cross = before.x * after.z - before.z * after.x;
    final dot = before.x * after.x + before.z * after.z;
    final delta = math.atan2(cross, dot);
    final start = _offset(vertex, before, side, half);
    final end = _offset(vertex, after, side, half);

    if (delta.abs() < 1e-6) return [end];
    // Reversão ~180°: sem interseção estável — bevel nos dois offsets.
    if ((math.pi - delta.abs()).abs() < 1e-5) return [start, end];

    if (delta * side < 0) {
      // Lado externo: arco de start até end ao redor do vértice.
      final startAngle = math.atan2(start.z - vertex.z, start.x - vertex.x);
      final steps = (delta.abs() / (math.pi / 12)).ceil().clamp(1, 24);
      return [
        start,
        for (var i = 1; i <= steps; i++)
          Vector3(
            vertex.x + math.cos(startAngle + delta * i / steps) * half,
            0,
            vertex.z + math.sin(startAngle + delta * i / steps) * half,
          ),
      ];
    }

    // Lado interno: interseção das retas de offset.
    final denominator = cross;
    if (denominator.abs() < 1e-8) return [start, end];
    final betweenX = end.x - start.x;
    final betweenZ = end.z - start.z;
    final t = (betweenX * after.z - betweenZ * after.x) / denominator;
    if (!t.isFinite) return [start, end];
    final intersection = Vector3(
      start.x + before.x * t,
      0,
      start.z + before.z * t,
    );
    final dist =
        (intersection.x - vertex.x) * (intersection.x - vertex.x) +
        (intersection.z - vertex.z) * (intersection.z - vertex.z);
    if (dist > half * half * _miterLimit * _miterLimit) {
      return [start, end];
    }
    return [intersection];
  }

  /// Ponto de offset: vertex + normal(dir, side)·half.
  static Vector3 _offset(Vector3 vertex, Vector3 dir, int side, double half) =>
      Vector3(
        vertex.x - dir.z * side * half,
        0,
        vertex.z + dir.x * side * half,
      );

  static List<Vector3> _dedupe(List<Vector3> pts) {
    final out = <Vector3>[];
    for (final p in pts) {
      if (p.x.isNaN || p.y.isNaN || p.z.isNaN) continue;
      if (out.isNotEmpty &&
          _dist2(out.last, p) < _pointEpsilon * _pointEpsilon) {
        continue;
      }
      out.add(p);
    }
    // Vértice de fechamento (first ≈ last): remove — sem isso um anel
    // degenerado geraria um SEGMENTO NULO (direção NaN) no fecho.
    if (out.length > 1 &&
        _dist2(out.first, out.last) < _pointEpsilon * _pointEpsilon) {
      out.removeLast();
    }
    return out;
  }

  // Distância no plano XZ: a superfície é horizontal (yLift uniforme);
  // nós duplicados em lat/lon com `ele` divergente são o mesmo vértice.
  static double _dist2(Vector3 a, Vector3 b) {
    final dx = a.x - b.x, dz = a.z - b.z;
    return dx * dx + dz * dz;
  }

  static double _distXZ2(Vector3 a, Vector3 b) => _dist2(a, b);

  /// Cadeia de offset de um ANEL: junção cíclica em TODOS os vértices
  // (porta do `_buildSide(closed: true)` do motor 2D) — sem capas.
  static List<Vector3> _buildRingSide(
    List<Vector3> pts,
    List<Vector3> dirs,
    double half,
    int side,
  ) {
    final n = pts.length;
    return <Vector3>[
      for (var i = 0; i < n; i++)
        ..._join(pts[i], dirs[(i - 1 + n) % n], dirs[i], side, half),
    ];
  }

  static List<Vector3> _compact(List<Vector3> pts) {
    final out = <Vector3>[];
    for (final p in pts) {
      if (out.isEmpty || _dist2(out.last, p) >= _pointEpsilon * _pointEpsilon) {
        out.add(p);
      }
    }
    if (out.length > 1 &&
        _dist2(out.first, out.last) < _pointEpsilon * _pointEpsilon) {
      out.removeLast();
    }
    return out;
  }
}

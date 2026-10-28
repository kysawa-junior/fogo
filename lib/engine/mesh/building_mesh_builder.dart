import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import '../geometry/polygon_triangulator.dart';
import '../scene/visual_style.dart';

/// Volume + pad plano de UM edifício: [flat] é o fallback 2D usado fora do
/// range de volume 3D (TASK-0011) — reusa a MESMA triangulação do piso.
class BuildingMeshes {
  const BuildingMeshes({required this.volume, required this.flat});

  /// Volume sólido (paredes + cobertura + piso).
  final MeshData volume;

  /// Pad plano ao nível do solo (+Y), com buracos recortados.
  final MeshData flat;
}

/// Edifício extrudado: paredes por anel (externo + buracos, com
/// orientação invertida nos buracos — pátios visíveis de dentro) e laje
/// de cobertura triangulada com os buracos recortados.
///
/// Volumetria: cores por vértice multiplicam a cor base do material —
/// fachadas recebem sombreamento direcional (luz fake da
/// [Fogo3DStyle]), cobertura mantém a cor base. Sem materiais extras,
/// sem lighting real — contraste barato e legível em visão oblíqua.
///
/// Altura vem da entidade (conhecida/estimada/padrão — o builder apenas
/// extruda o valor recebido) com clamp contra dados inválidos. Polígonos
/// inválidos devolvem null e o chamador registra issue.
abstract final class BuildingMeshBuilder {
  /// Elevação do pad plano sobre o solo (z-fight contra áreas/pistas).
  static const double flatPadLiftMeters = 0.06;

  /// `rings[0]` = contorno externo; demais = buracos. Coordenadas já
  /// projetadas, solo em y≈0 (a elevação do footprint é respeitada via
  /// `minHeight` quando presente).
  static BuildingMeshes? build(
    List<List<Vector3>> rings, {
    required double heightMeters,
    double? minHeightMeters,
    Fogo3DStyle style = Fogo3DStyle.standard,
  }) {
    if (rings.isEmpty) return null;
    // Anel externo preparado UMA vez: dedupe (1 cm) + orientação canônica
    // — usado por paredes E cobertura (evita slivers de nós duplicados).
    final outerPrepared = _oriented(_dedupeClosed(rings[0]), positive: true);
    if (outerPrepared.length < 3) return null;
    final holes = rings.length > 1 ? rings.sublist(1) : const <List<Vector3>>[];

    // Clamp: tags inválidas não geram edifício invisível nem
    // desproporcional (ex.: height=9999). NaN é descartado ANTES do
    // clamp (Dart: NaN.clamp retorna o limite superior).
    if (!heightMeters.isFinite) return null;
    final clampedHeight = heightMeters.clamp(
      style.minBuildingHeight,
      style.maxBuildingHeight,
    );
    final base = minHeightMeters ?? 0;
    final top = base + clampedHeight;

    final vertices = <Vector3>[];
    final normals = <Vector3>[];
    final shades = <double>[];
    final triangles = <int>[];

    // Paredes: quads por aresta de cada anel. Anéis normalizados para
    // orientação canônica (externo: área > 0 no plano x/z; buracos:
    // oposta), garantindo normais externas consistentes.
    final holeRings = <List<Vector3>>[
      for (final h in holes)
        if (_dedupeClosed(h).length >= 3)
          _oriented(_dedupeClosed(h), positive: false),
    ];
    for (var ringIdx = 0; ringIdx <= holeRings.length; ringIdx++) {
      final isHole = ringIdx > 0;
      final ring = isHole ? holeRings[ringIdx - 1] : outerPrepared;
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i];
        final b = ring[(i + 1) % ring.length];
        final wallNormal = _wallNormal(a, b, flip: isHole);
        final shade = isHole ? _holeShade(style) : _shadeFor(wallNormal, style);
        final i0 = vertices.length;
        vertices
          ..add(Vector3(a.x, base + a.y, a.z))
          ..add(Vector3(b.x, base + b.y, b.z))
          ..add(Vector3(a.x, top + a.y, a.z))
          ..add(Vector3(b.x, top + b.y, b.z));
        for (var k = 0; k < 4; k++) {
          normals.add(wallNormal);
          shades.add(shade);
        }
        // Dois triângulos; winding flipado p/ buracos (normal p/ dentro).
        if (isHole) {
          triangles.addAll([i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2]);
        } else {
          triangles.addAll([i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3]);
        }
      }
    }

    // Cobertura: MESMO anel externo preparado das paredes (dedupe +
    // orientação), com buracos recortados, no plano y=top. Triangular
    // o anel cru gerava slivers com nós OSM duplicados que colapsam
    // na precisão float32. Cor base (roofShade) — leitura limpa do
    // topo em qualquer ângulo.
    final roof = PolygonTriangulator.triangulate(
      [for (final p in outerPrepared) Vector3(p.x, 0, p.z)],
      [
        for (final h in holeRings) [for (final p in h) Vector3(p.x, 0, p.z)],
      ],
    );
    if (roof == null) return null;
    final roofVertexBase = vertices.length;
    for (final v in roof.vertices) {
      vertices.add(Vector3(v.x, top, v.z));
      normals.add(Vector3(0, 1, 0));
      shades.add(style.roofShade);
    }
    // Índices do teto são 0-based sobre roof.vertices — SEM o offset
    // eles aliasam vértices de parede (teto invisível: o bug dos
    // "edifícios ocos" no dado real; fixture só contava triângulos).
    for (final t in roof.triangles) {
      triangles.add(t + roofVertexBase);
    }

    // Base (piso): MESMO anel da cobertura, no plano y=base, com
    // buracos recortados — fecha o volume (manifold). Winding/normais
    // invertidos: a face visível é a INFERIOR (visto por baixo em
    // edifícios sobre pilotis/vãos); por cima a cobertura já cobre.
    final floor = PolygonTriangulator.triangulate(outerPrepared, holeRings);
    if (floor == null) return null;
    final floorVertexBase = vertices.length;
    for (final v in floor.vertices) {
      vertices.add(Vector3(v.x, base + v.y, v.z));
      normals.add(Vector3(0, -1, 0));
      shades.add(style.wallAmbient);
    }
    for (var i = 0; i < floor.triangles.length; i += 3) {
      triangles.addAll([
        floor.triangles[i] + floorVertexBase,
        floor.triangles[i + 2] + floorVertexBase,
        floor.triangles[i + 1] + floorVertexBase,
      ]);
    }

    // Pós-filtro de slivers (§3/§5): paredes/trechos de área 3D ~0
    // (vértices coincidentes pós-float32) são inertes — descarta.
    final kept = <int>[];
    for (var i = 0; i < triangles.length; i += 3) {
      final a = vertices[triangles[i]];
      final b = vertices[triangles[i + 1]];
      final c = vertices[triangles[i + 2]];
      if ((b - a).cross(c - a).length2 >= 4e-8) {
        kept.addAll([triangles[i], triangles[i + 1], triangles[i + 2]]);
      }
    }
    if (kept.isEmpty) return null;

    final colors = Float32List(vertices.length * 4);
    for (var i = 0; i < vertices.length; i++) {
      colors[i * 4] = shades[i];
      colors[i * 4 + 1] = shades[i];
      colors[i * 4 + 2] = shades[i];
      colors[i * 4 + 3] = 1.0;
    }

    // Pad plano (TASK-0011): MESMA triangulação do piso, winding normal
    // (visível de CIMA — o piso do volume é o inverso), normals +Y e
    // elevado `flatPadLiftMeters` sobre o solo. Sem custo de nova
    // triangulação; slivers recebem o mesmo filtro.
    final flatKept = <int>[];
    for (var i = 0; i < floor.triangles.length; i += 3) {
      final a = floor.vertices[floor.triangles[i]];
      final b = floor.vertices[floor.triangles[i + 1]];
      final c = floor.vertices[floor.triangles[i + 2]];
      if ((b - a).cross(c - a).length2 >= 4e-8) {
        flatKept.addAll([
          floor.triangles[i],
          floor.triangles[i + 1],
          floor.triangles[i + 2],
        ]);
      }
    }
    MeshData? flat;
    if (flatKept.isNotEmpty) {
      final flatPositions = Float32List(floor.vertices.length * 3);
      final flatNormals = Float32List(floor.vertices.length * 3);
      for (var i = 0; i < floor.vertices.length; i++) {
        flatPositions[i * 3] = floor.vertices[i].x;
        flatPositions[i * 3 + 1] = flatPadLiftMeters + floor.vertices[i].y;
        flatPositions[i * 3 + 2] = floor.vertices[i].z;
        flatNormals[i * 3 + 1] = 1;
      }
      flat = MeshData(
        positions: flatPositions,
        normals: flatNormals,
        indices: Uint32List.fromList(flatKept),
      );
    }
    if (flat == null) return null;

    return BuildingMeshes(
      volume: MeshData(
        positions: _packPositions(vertices),
        normals: _packNormals(normals),
        indices: Uint32List.fromList(kept),
        colors: colors,
      ),
      flat: flat,
    );
  }

  /// Sombreamento direcional fake: fachadas viradas para a luz ficam
  /// claras, as opostas escurecem SEMPRE acima do ambient mínimo —
  /// nenhum detalhe some em sombra.
  static double _shadeFor(Vector3 wallNormal, Fogo3DStyle style) {
    final d = wallNormal.dot(style.light).clamp(0.0, 1.0);
    return style.wallAmbient + style.wallDiffuse * d;
  }

  /// Paredes de buraco (pátios internos): sombra plana — o pátio lê como
  /// recesso sem competing com a luz externa.
  static double _holeShade(Fogo3DStyle style) => style.wallAmbient;

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
      // Compara no PLANO XZ (a extrusão é vertical: nós OSM duplicados
      // em lat/lon com tags `ele` divergentes são o MESMO vértice do
      // footprint). 1 cm de tolerância — igual ao builder de vias.
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

Float32List _packPositions(List<Vector3> v) {
  final out = Float32List(v.length * 3);
  for (var i = 0; i < v.length; i++) {
    out[i * 3] = v[i].x;
    out[i * 3 + 1] = v[i].y;
    out[i * 3 + 2] = v[i].z;
  }
  return out;
}

Float32List _packNormals(List<Vector3> v) => _packPositions(v);

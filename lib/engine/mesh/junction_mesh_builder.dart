import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import '../scene/visual_style.dart';

/// Braço de via conectado a uma junção.
class JunctionArm {
  JunctionArm({
    required this.direction,
    required this.halfWidthMeters,
    required this.color,
  });

  /// Direção unitária horizontal DA junção PARA a via.
  final Vector3 direction;

  /// Metade da largura da via (m).
  final double halfWidthMeters;

  /// Cor da via (a pad interpola da cor central para a cor de cada braço).
  final Vector3 color;
}

/// Caixa de interseção de junção viária (estratégia do motor 2D,
/// `road_surface/surface_builder`): o contorno segue as LINHAS DE BORDA
/// reais das vias — entre cada par de braços consecutivos (ordem
/// angular), o vértice é a INTERSEÇÃO das bordas enfrentadas, com
/// fallback bevel (corda entre as bocas) quando as retas são paralelas
/// ou o canto excede o limite de miter. As bordas da pad continuam
/// exatamente as bordas das vias: sem fendas, sem entalhes, sem
/// sobreposições — cada via de chega à junção com capa reta (escondida
/// sob a pad via `Material.depthLayer`).
///
/// Só deve receber braços NO MESMO NÍVEL (layer/lift igual): vias em
/// níveis distintos (pontes/túneis) nunca recebem pad conjunta —
/// interseção visual não é conexão física.
abstract final class JunctionMeshBuilder {
  static MeshData? build(
    Vector3 center,
    List<JunctionArm> arms, {
    Vector3? priorityColor,
    Fogo3DStyle style = Fogo3DStyle.standard,
  }) {
    if (arms.length < 2) return null;
    final y = center.y + style.padLiftMeters;

    // Braços válidos, ordenados por ângulo da direção em torno do nó.
    final valid = <({Vector3 dir, double half, Vector3 lat, Vector3 color})>[];
    for (final arm in arms) {
      final dir = Vector3(arm.direction.x, 0, arm.direction.z);
      if (dir.length2 < 1e-12) continue;
      dir.normalize();
      // lat = normal à esquerda da direção (lado de ângulo crescente).
      valid.add((
        dir: dir,
        half: arm.halfWidthMeters,
        lat: Vector3(-dir.z, 0, dir.x),
        color: arm.color,
      ));
    }
    if (valid.length < 2) return null;
    final cx = center.x;
    final cz = center.z;
    valid.sort(
      (a, b) =>
          math.atan2(a.dir.z, a.dir.x).compareTo(math.atan2(b.dir.z, b.dir.x)),
    );

    // Cor do centro = via prioritária (ou a de maior meia-largura).
    final centerColor =
        priorityColor ?? valid.reduce((a, b) => a.half >= b.half ? a : b).color;

    final outline = <({Vector3 p, Vector3 color})>[];
    if (valid.length == 2) {
      // Junção em L (dois braços): a região é a UNIÃO dos retângulos
      // dos braços, cada um limitado pelas bordas do outro — um
      // hexágono com o centro como vértice reflexo. Cantos: o interno
      // (bordas que se enfrentam) e os dois externos (bordas do mesmo
      // lado); bocas e centro fecham o contorno.
      final a = valid[0];
      final b = valid[1];
      Vector3? corner(Vector3 latA, double hA, Vector3 latB, double hB) {
        return _intersectLines(
          Vector3(cx + latA.x * hA, 0, cz + latA.z * hA),
          a.dir,
          Vector3(cx + latB.x * hB, 0, cz + latB.z * hB),
          b.dir,
        );
      }

      final inner = corner(a.lat, a.half, -b.lat, b.half);
      final outerA = corner(-a.lat, a.half, -b.lat, b.half);
      final outerB = corner(a.lat, a.half, b.lat, b.half);
      final limit2 = style.padCornerLimitFactor * math.max(a.half, b.half);
      bool within(Vector3? k) =>
          k != null &&
          (k.x - cx) * (k.x - cx) + (k.z - cz) * (k.z - cz) <= limit2 * limit2;
      if (!within(inner) || !within(outerA) || !within(outerB)) {
        // Ângulo muito agudo ou quase colinear: as capas retas das vias
        // se tocam de forma aceitável — sem pad.
        return null;
      }
      Vector3 mix(Vector3 c, Vector3 d) =>
          Vector3((c.x + d.x) / 2, (c.y + d.y) / 2, (c.z + d.z) / 2);
      final aMouthMinus = Vector3(
        cx - a.lat.x * a.half,
        0,
        cz - a.lat.z * a.half,
      );
      final bMouthPlus = Vector3(
        cx + b.lat.x * b.half,
        0,
        cz + b.lat.z * b.half,
      );
      outline
        ..add((p: inner!, color: mix(a.color, b.color)))
        ..add((p: outerA!, color: mix(a.color, b.color)))
        ..add((p: aMouthMinus, color: a.color))
        ..add((p: Vector3(cx, 0, cz), color: centerColor))
        ..add((p: bMouthPlus, color: b.color))
        ..add((p: outerB!, color: mix(a.color, b.color)));
    } else {
      // 3+ braços: contorno = cadeia de cantos entre braços
      // consecutivos (ordem angular); bevel (duas bocas) quando as
      // bordas são paralelas ou o canto excede o limite de miter.
      final cornerLimit =
          style.padCornerLimitFactor *
          valid.map((a) => a.half).reduce(math.max);
      for (var i = 0; i < valid.length; i++) {
        final a = valid[i];
        final b = valid[(i + 1) % valid.length];
        // Borda de `a` no lado de ângulo crescente (lat), borda de `b`
        // no lado de ângulo decrescente (−lat): as bordas que se
        // enfrentam no canto entre os dois braços.
        final aEdgeOrigin = Vector3(
          cx + a.lat.x * a.half,
          0,
          cz + a.lat.z * a.half,
        );
        final bEdgeOrigin = Vector3(
          cx - b.lat.x * b.half,
          0,
          cz - b.lat.z * b.half,
        );
        final corner = _intersectLines(aEdgeOrigin, a.dir, bEdgeOrigin, b.dir);
        final dist = corner == null
            ? double.infinity
            : (corner.x - cx) * (corner.x - cx) +
                  (corner.z - cz) * (corner.z - cz);
        if (corner != null && dist <= cornerLimit * cornerLimit) {
          outline.add((
            p: corner,
            color: Vector3(
              (a.color.x + b.color.x) / 2,
              (a.color.y + b.color.y) / 2,
              (a.color.z + b.color.z) / 2,
            ),
          ));
        } else {
          outline.add((p: aEdgeOrigin, color: a.color));
          outline.add((p: bEdgeOrigin, color: b.color));
        }
      }
    }
    if (outline.length < 3) return null;

    // Robustez (§ETAPA 01): contorno com arestas que se cruzam é
    // inválido (bevel parcial de canto excedido pode cruzar arestas
    // vizinhas em ângulos oblíquos). Fallback em cascata: contorno de
    // BOCAS dos braços ordenado por ângulo — sempre uma estrela em
    // torno do nó, derivada das bordas reais, sem fenda central.
    if (_hasSelfIntersection(outline)) {
      outline
        ..clear()
        ..addAll(_mouthOutline(valid, cx, cz));
      if (outline.length < 3 || _hasSelfIntersection(outline)) {
        return null;
      }
    }

    // Área degenerada (vias colineares): descarta.
    var area2 = 0.0;
    for (var i = 0; i < outline.length; i++) {
      final p = outline[i].p;
      final q = outline[(i + 1) % outline.length].p;
      area2 += p.x * q.z - q.x * p.z;
    }
    if (area2.abs() / 2 < style.padMinAreaMeters) return null;

    // Triangulação em leque a partir do nó — o contorno é estrela em
    // relação ao centro por construção (cantos/bevels ao redor dele).
    // Triângulos degenerados (boca colinear com o centro) são pulados;
    // winding corrigido por triângulo (normal sempre +Y).
    final vertexCount = outline.length + 1;
    final positions = Float32List(vertexCount * 3);
    final normals = Float32List(vertexCount * 3);
    final colors = Float32List(vertexCount * 4);

    positions[0] = cx;
    positions[1] = y;
    positions[2] = cz;
    normals[1] = 1.0;
    colors[0] = centerColor.x;
    colors[1] = centerColor.y;
    colors[2] = centerColor.z;
    colors[3] = 1.0;
    for (var i = 0; i < outline.length; i++) {
      final p = outline[i].p;
      positions[(i + 1) * 3] = p.x;
      positions[(i + 1) * 3 + 1] = y;
      positions[(i + 1) * 3 + 2] = p.z;
      normals[(i + 1) * 3 + 1] = 1.0;
      colors[(i + 1) * 4] = outline[i].color.x;
      colors[(i + 1) * 4 + 1] = outline[i].color.y;
      colors[(i + 1) * 4 + 2] = outline[i].color.z;
      colors[(i + 1) * 4 + 3] = 1.0;
    }

    final triangles = <int>[];
    for (var i = 0; i < outline.length; i++) {
      final a = i + 1;
      final b = (i + 1) % outline.length + 1;
      if (a == b) continue;
      final pa = outline[a - 1].p;
      final pb = outline[b - 1].p;
      final crossXZ = (pa.x - cx) * (pb.z - cz) - (pa.z - cz) * (pb.x - cx);
      // Slivers (< 0,01 m² de área) não agregam superfície — pula.
      if (crossXZ.abs() < 0.02) continue;
      // Winding +Y: normal.y = uz·vx − ux·vz = −crossXZ.
      if (crossXZ > 0) {
        triangles.addAll([0, b, a]);
      } else {
        triangles.addAll([0, a, b]);
      }
    }
    if (triangles.isEmpty) return null;

    return MeshData(
      positions: positions,
      normals: normals,
      indices: Uint32List.fromList(triangles),
      colors: colors,
    );
  }

  /// Contorno de fallback: as bocas (seções no nó) de todos os
  /// braços, ordenadas por ângulo — polígono estrela que cobre o
  /// disco central da junção com as bordas reais das vias.
  static List<({Vector3 p, Vector3 color})> _mouthOutline(
    List<({Vector3 dir, double half, Vector3 lat, Vector3 color})> valid,
    double cx,
    double cz,
  ) {
    final mouths = <({Vector3 p, Vector3 color})>[];
    for (final a in valid) {
      mouths
        ..add((
          p: Vector3(cx + a.lat.x * a.half, 0, cz + a.lat.z * a.half),
          color: a.color,
        ))
        ..add((
          p: Vector3(cx - a.lat.x * a.half, 0, cz - a.lat.z * a.half),
          color: a.color,
        ));
    }
    mouths.sort(
      (m, n) => math
          .atan2(m.p.z - cz, m.p.x - cx)
          .compareTo(math.atan2(n.p.z - cz, n.p.x - cx)),
    );
    return mouths;
  }

  /// Interseção da reta (p1 + t·d1) com (p2 + u·d2); null quando
  /// paralelas ou degenerada.
  static Vector3? _intersectLines(
    Vector3 p1,
    Vector3 d1,
    Vector3 p2,
    Vector3 d2,
  ) {
    final cross = d1.x * d2.z - d1.z * d2.x;
    if (cross.abs() < 1e-9) return null;
    final t = ((p2.x - p1.x) * d2.z - (p2.z - p1.z) * d2.x) / cross;
    if (!t.isFinite) return null;
    return Vector3(p1.x + d1.x * t, 0, p1.z + d1.z * t);
  }

  /// Cruzamento de arestas não adjacentes do contorno (plano x/z),
  /// tolerância de 1 mm — polígono auto-intersectado é inválido.
  /// Diagnóstico/teste: contorno de polígono (plano x/z) com arestas
  /// que se cruzam — usado pelos testes de robustez da junção.
  static bool hasSelfIntersection(List<Vector3> polygon) {
    final outline = <({Vector3 p, Vector3 color})>[
      for (final p in polygon) (p: p, color: Vector3.zero()),
    ];
    return _hasSelfIntersection(outline);
  }

  static bool _hasSelfIntersection(List<({Vector3 p, Vector3 color})> outline) {
    bool segsCross(Vector3 a1, Vector3 a2, Vector3 b1, Vector3 b2) {
      double orient(Vector3 p, Vector3 q, Vector3 r) =>
          (q.x - p.x) * (r.z - p.z) - (q.z - p.z) * (r.x - p.x);
      final d1 = orient(b1, b2, a1);
      final d2 = orient(b1, b2, a2);
      final d3 = orient(a1, a2, b1);
      final d4 = orient(a1, a2, b2);
      const eps = 1e-3; // 1 mm² (orientação = área dobrada)
      if (((d1 > eps && d2 < -eps) || (d1 < -eps && d2 > eps)) &&
          ((d3 > eps && d4 < -eps) || (d3 < -eps && d4 > eps))) {
        return true;
      }
      return false;
    }

    for (var i = 0; i < outline.length; i++) {
      final a1 = outline[i].p;
      final a2 = outline[(i + 1) % outline.length].p;
      for (var j = i + 2; j < outline.length; j++) {
        if (i == 0 && j == outline.length - 1) continue; // aresta adjacente
        final b1 = outline[j].p;
        final b2 = outline[(j + 1) % outline.length].p;
        if (segsCross(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import 'box_builder.dart';

/// Travessia de pedestres ("zebra"): barras PARALELAS ao fluxo da via,
/// empilhadas ao longo do caminho do pedestre (largura da via).
/// Sempre na posição real do nó `highway=crossing` — nada em posições
/// arbitrárias. Sem heading conhecido, assume eixo leste.
abstract final class CrossingMeshBuilder {
  static MeshData? build(
    Vector3 position,
    double? headingRadians, {
    double roadWidthMeters = 6,
    double stripeLength = 2.6,
    double y = 0.08,
  }) {
    final heading = headingRadians ?? 0;
    final cosH = math.cos(heading);
    final sinH = math.sin(heading);
    // Direção da via (heading) e perpendicular (caminho do pedestre).
    final dirU = Vector3(cosH, 0, sinH); // leste quando heading=0
    // perp = heading + 90° no plano x/z (sul quando heading=0).
    final dirV = Vector3(-sinH, 0, cosH);

    const stripes = 4;
    const stripeW = 0.45;
    const gap = 0.35;
    final total = stripes * stripeW + (stripes - 1) * gap;

    final vertices = <Vector3>[];
    final triangles = <int>[];
    var v = -total / 2;

    for (var s = 0; s < stripes; s++) {
      Vector3 corner(double along, double across) => Vector3(
        position.x + dirU.x * along + dirV.x * across,
        y,
        position.z + dirU.z * along + dirV.z * across,
      );
      // Barra: comprimento `stripeLength` ao longo da via, largura
      // `stripeW` no caminho do pedestre.
      final c0 = corner(stripeLength / 2, v);
      final c1 = corner(-stripeLength / 2, v);
      final c2 = corner(-stripeLength / 2, v + stripeW);
      final c3 = corner(stripeLength / 2, v + stripeW);
      final i0 = vertices.length;
      vertices
        ..add(c0)
        ..add(c1)
        ..add(c2)
        ..add(c3);
      if ((c1 - c0).cross(c2 - c0).y < 0) {
        triangles.addAll([i0, i0 + 2, i0 + 1, i0, i0 + 3, i0 + 2]);
      } else {
        triangles.addAll([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3]);
      }
      v += stripeW + gap;
    }
    if (vertices.isEmpty) return null;
    // shortcut: barras simples, sem LOD; upgrade quando houver textura.
    return MeshData.fromVertices(vertices, triangles);
  }
}

/// Semáforo na posição real: poste + caixa de focos no topo, orientado
/// ao longo da via conectada (heading). Volume simples e legível.
abstract final class TrafficSignalMeshBuilder {
  static MeshData? build(
    Vector3 position,
    double? headingRadians, {
    double y = 0,
  }) {
    final heading = headingRadians ?? 0;
    return merge([
      buildBox(
        Vector3(position.x, y + 2.2, position.z),
        Vector3(0.35, 2.2, 0.09),
        headingRadians: heading,
      ),
      buildBox(
        Vector3(position.x, y + 4.7, position.z),
        Vector3(0.28, 0.5, 0.18),
        headingRadians: heading,
      ),
    ]);
  }
}

/// Concatena malhas (blocos de vértices + ajuste de índices).
MeshData? merge(Iterable<MeshData?> parts) {
  final list = parts
      .whereType<MeshData>()
      .where((m) => m.vertexCount > 0)
      .toList();
  if (list.isEmpty) return null;
  var vCount = 0;
  var iCount = 0;
  for (final m in list) {
    vCount += m.vertexCount;
    iCount += m.indices.length;
  }
  final positions = Float32List(vCount * 3);
  final normals = Float32List(vCount * 3);
  final indices = Uint32List(iCount);
  var vOff = 0;
  var iOff = 0;
  for (final m in list) {
    positions.setAll(vOff * 3, m.positions);
    normals.setAll(vOff * 3, m.normals);
    for (var i = 0; i < m.indices.length; i++) {
      indices[iOff + i] = m.indices[i] + vOff;
    }
    vOff += m.vertexCount;
    iOff += m.indices.length;
  }
  return MeshData(positions: positions, normals: normals, indices: indices);
}

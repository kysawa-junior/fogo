import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import 'box_builder.dart';

/// Travessia de pedestres ("zebra"): barras TRANSVERSAIS ao fluxo da
/// via — cada barra cruza a largura da via (padrão real de faixa) e as
/// barras se repetem ao longo do eixo da via. Sem heading conhecido,
/// assume eixo leste.
abstract final class CrossingMeshBuilder {
  static MeshData? build(
    Vector3 position,
    double? headingRadians, {
    double roadWidthMeters = 6,
    double y = 0.04,
    int stripes = 4,
    double stripeW = 0.45,
    double gap = 0.6,
  }) {
    final heading = headingRadians ?? 0;
    final cosH = math.cos(heading);
    final sinH = math.sin(heading);
    // Direção da via (heading) e perpendicular (através da via).
    final dirU = Vector3(cosH, 0, sinH); // leste quando heading=0
    final dirV = Vector3(-sinH, 0, cosH); // sul quando heading=0

    // Barras transversais: comprimento = largura da via (ao longo de
    // dirV), espessura `stripeW` ao longo da via (dirU), repetidas ao
    // longo de dirU.
    final total = stripes * stripeW + (stripes - 1) * gap;
    final span = roadWidthMeters;

    final vertices = <Vector3>[];
    final triangles = <int>[];
    var u = -total / 2;

    for (var s = 0; s < stripes; s++) {
      Vector3 corner(double along, double across) => Vector3(
        position.x + dirU.x * along + dirV.x * across,
        y,
        position.z + dirU.z * along + dirV.z * across,
      );
      // Barra: `stripeW` ao longo da via, `span` através dela.
      final c0 = corner(u + stripeW, -span / 2);
      final c1 = corner(u, -span / 2);
      final c2 = corner(u, span / 2);
      final c3 = corner(u + stripeW, span / 2);
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
      u += stripeW + gap;
    }
    if (vertices.isEmpty) return null;
    // shortcut: barras simples, sem LOD; upgrade quando houver textura.
    return MeshData.fromVertices(vertices, triangles);
  }
}

/// Semáforo na posição real: poste + caixa de focos no topo, orientado
/// ao longo da via conectada. Uma malha com vertex colors mantém o
/// semáforo como um único objeto clicável/draw call.
abstract final class TrafficSignalMeshBuilder {
  static MeshData? build(
    Vector3 position, {
    required Vector3 roadDirection,
    required double roadWidthMeters,
    double y = 0,
  }) {
    final direction = Vector3(roadDirection.x, 0, roadDirection.z);
    if (direction.length2 < 1e-9) direction.setValues(1, 0, 0);
    direction.normalize();

    // x=east, z=south: left side of an eastbound road is north (-z).
    final left = Vector3(direction.z, 0, -direction.x);
    final halfWidth = roadWidthMeters.isFinite && roadWidthMeters > 0
        ? roadWidthMeters / 2
        : 2.5;
    final offset = halfWidth + 0.9;
    final poleX = position.x + left.x * offset;
    final poleZ = position.z + left.z * offset;
    final armDirection = -left;
    final armHeading = math.atan2(-armDirection.z, armDirection.x);
    final roadHeading = math.atan2(-direction.z, direction.x);

    final metal = Vector3(0.18, 0.20, 0.23);
    final housing = Vector3(0.025, 0.03, 0.04);
    final parts = <({MeshData mesh, Vector3 color})>[];
    void add(MeshData mesh, Vector3 color) =>
        parts.add((mesh: mesh, color: color));

    add(
      _cylinder(
        Vector3(poleX, y + 0.08, poleZ),
        Vector3(0, 1, 0),
        radius: 0.15,
        height: 0.16,
      ),
      metal,
    );
    add(
      _cylinder(
        Vector3(poleX, y + 2.5, poleZ),
        Vector3(0, 1, 0),
        radius: 0.065,
        height: 5.0,
      ),
      metal,
    );

    // Braço sai da lateral e termina sobre o eixo da via.
    add(
      buildBox(
        Vector3((poleX + position.x) / 2, y + 4.65, (poleZ + position.z) / 2),
        Vector3(offset / 2, 0.055, 0.055),
        headingRadians: armHeading,
      ),
      metal,
    );

    const headY = 4.15;
    add(
      buildBox(
        Vector3(position.x, y + headY, position.z),
        Vector3(0.14, 0.55, 0.22),
        headingRadians: roadHeading,
      ),
      housing,
    );

    // Lentes cilíndricas na face voltada ao fluxo que chega pelo trecho.
    final facing = -direction;
    final lensX = position.x + facing.x * 0.16;
    final lensZ = position.z + facing.z * 0.16;
    final lensColors = [
      (offsetY: 0.27, color: Vector3(0.95, 0.035, 0.025)),
      (offsetY: 0.0, color: Vector3(1.0, 0.48, 0.025)),
      (offsetY: -0.27, color: Vector3(0.04, 0.78, 0.12)),
    ];
    for (final lens in lensColors) {
      add(
        _cylinder(
          Vector3(lensX, y + headY + lens.offsetY, lensZ),
          facing,
          radius: 0.09,
          height: 0.035,
        ),
        lens.color,
      );
    }

    return _mergeColored(parts);
  }

  static MeshData _cylinder(
    Vector3 center,
    Vector3 axis, {
    required double radius,
    required double height,
    int segments = 12,
  }) {
    final n = Vector3(axis.x, axis.y, axis.z)..normalize();
    final reference = n.y.abs() > 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
    final u = n.cross(reference)..normalize();
    final v = n.cross(u)..normalize();
    final bottom = center - n * (height / 2);
    final top = center + n * (height / 2);
    final vertices = <Vector3>[];
    final normals = <Vector3>[];
    final triangles = <int>[];

    for (var i = 0; i < segments; i++) {
      final angle = math.pi * 2 * i / segments;
      final radial = u * math.cos(angle) + v * math.sin(angle);
      vertices
        ..add(bottom + radial * radius)
        ..add(top + radial * radius);
      normals
        ..add(radial)
        ..add(radial);
    }
    for (var i = 0; i < segments; i++) {
      final j = (i + 1) % segments;
      final bi = i * 2, ti = bi + 1, bj = j * 2, tj = bj + 1;
      triangles.addAll([bi, bj, tj, bi, tj, ti]);
    }

    void addCap(Vector3 capCenter, Vector3 normal, {required bool topCap}) {
      final centerIndex = vertices.length;
      vertices.add(capCenter);
      normals.add(normal);
      final ringStart = vertices.length;
      for (var i = 0; i < segments; i++) {
        final angle = math.pi * 2 * i / segments;
        final radial = u * math.cos(angle) + v * math.sin(angle);
        vertices.add(capCenter + radial * radius);
        normals.add(normal);
      }
      for (var i = 0; i < segments; i++) {
        final j = (i + 1) % segments;
        if (topCap) {
          triangles.addAll([centerIndex, ringStart + i, ringStart + j]);
        } else {
          triangles.addAll([centerIndex, ringStart + j, ringStart + i]);
        }
      }
    }

    addCap(top, n, topCap: true);
    addCap(bottom, -n, topCap: false);
    return MeshData.fromVertices(vertices, triangles, normals: normals);
  }

  static MeshData _mergeColored(List<({MeshData mesh, Vector3 color})> parts) {
    final vertexCount = parts.fold<int>(
      0,
      (sum, part) => sum + part.mesh.vertexCount,
    );
    final indexCount = parts.fold<int>(
      0,
      (sum, part) => sum + part.mesh.indices.length,
    );
    final positions = Float32List(vertexCount * 3);
    final normals = Float32List(vertexCount * 3);
    final colors = Float32List(vertexCount * 4);
    final indices = Uint32List(indexCount);
    var vertexOffset = 0;
    var indexOffset = 0;

    for (final part in parts) {
      final mesh = part.mesh;
      positions.setAll(vertexOffset * 3, mesh.positions);
      normals.setAll(vertexOffset * 3, mesh.normals);
      for (var i = 0; i < mesh.vertexCount; i++) {
        final colorOffset = (vertexOffset + i) * 4;
        colors[colorOffset] = part.color.x;
        colors[colorOffset + 1] = part.color.y;
        colors[colorOffset + 2] = part.color.z;
        colors[colorOffset + 3] = 1;
      }
      for (var i = 0; i < mesh.indices.length; i++) {
        indices[indexOffset + i] = mesh.indices[i] + vertexOffset;
      }
      vertexOffset += mesh.vertexCount;
      indexOffset += mesh.indices.length;
    }
    return MeshData(
      positions: positions,
      normals: normals,
      indices: indices,
      colors: colors,
    );
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

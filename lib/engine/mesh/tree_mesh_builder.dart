import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import '../scene/visual_style.dart';
import 'box_builder.dart';

/// Árvore genérica e DISCRETA: tronco (prisma fino) + copa (icosaedro
/// achatado). Sem espécie/altura/copa nos dados → UM modelo genérico,
/// cor derivada da paleta de vegetação (verde-escuro da paleta de área
/// `forest`), nunca apresentado como dado real.
abstract final class TreeMeshBuilder {
  /// Alturas/copas variam DETERMINISTICAMENTE pelo hash do id da
  /// entidade — os mesmos dados produzem sempre a mesma árvore.
  static MeshData? build(
    Vector3 position,
    String entityId, {
    Fogo3DStyle style = Fogo3DStyle.standard,
  }) {
    // Hash determinístico do id (FNV-1a 32-bit).
    var hash = 0x811c9dc5;
    for (final c in entityId.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final rnd = hash / 0xFFFFFFFF; // 0..1 determinístico

    final trunkH = 2.2 + rnd * 1.8; // 2,2..4 m
    final crownR = 1.6 + rnd * 1.4; // 1,6..3 m
    final crownY = trunkH + crownR * 0.7;

    final trunk = buildBox(
      Vector3(position.x, trunkH / 2, position.z),
      Vector3(0.12, trunkH / 2, 0.12),
    );
    final crown = _icosphere(Vector3(position.x, crownY, position.z), crownR);
    return _mergeColored(trunk, crown);
  }

  /// Icosfera achatada (4 subdivisões via octaedro) — barata, 8 tri+.
  static MeshData _icosphere(Vector3 center, double radius) {
    final vertices = <Vector3>[];
    final triangles = <int>[];
    final normals = <Vector3>[];

    // Octaedro: 6 vértices, 8 faces — esfera suficiente p/ copa.
    final v0 = center + Vector3(0, radius * 0.8, 0); // achatada
    final v1 = center + Vector3(radius, 0, 0);
    final v2 = center + Vector3(0, radius * 0.55, radius * 0.7);
    final v3 = center + Vector3(-radius, 0, 0);
    final v4 = center + Vector3(0, radius * 0.55, -radius * 0.7);
    final v5 = center + Vector3(0, -radius * 0.55, 0);
    for (final v in [v0, v1, v2, v3, v4, v5]) {
      vertices.add(v);
      final n = (v - center).normalized();
      normals.add(n);
    }
    // 8 faces do octaedro.
    final faces = [
      [0, 1, 2],
      [0, 2, 3],
      [0, 3, 4],
      [0, 4, 1],
      [5, 2, 1],
      [5, 3, 2],
      [5, 4, 3],
      [5, 1, 4],
    ];
    for (final f in faces) {
      final a = vertices[f[0]], b = vertices[f[1]], c = vertices[f[2]];
      final cross = (b - a).cross(c - a);
      if (cross.dot(a - center) < 0) {
        triangles.addAll([f[0], f[2], f[1]]);
      } else {
        triangles.addAll(f);
      }
    }
    return MeshData(
      positions: _pack(vertices),
      normals: _pack(normals),
      indices: _packIndices(triangles),
    );
  }

  static MeshData _mergeColored(MeshData a, MeshData b) {
    final vCount = a.vertexCount + b.vertexCount;
    final positions = Float32List(vCount * 3);
    final normals = Float32List(vCount * 3);
    final indices = Uint32List(a.indices.length + b.indices.length);
    positions.setAll(0, a.positions);
    positions.setAll(a.vertexCount * 3, b.positions);
    normals.setAll(0, a.normals);
    normals.setAll(a.vertexCount * 3, b.normals);
    indices.setAll(0, a.indices);
    for (var i = 0; i < b.indices.length; i++) {
      indices[a.indices.length + i] = b.indices[i] + a.vertexCount;
    }
    return MeshData(positions: positions, normals: normals, indices: indices);
  }

  static Float32List _pack(List<Vector3> v) {
    final out = Float32List(v.length * 3);
    for (var i = 0; i < v.length; i++) {
      out[i * 3] = v[i].x;
      out[i * 3 + 1] = v[i].y;
      out[i * 3 + 2] = v[i].z;
    }
    return out;
  }

  static Uint32List _packIndices(List<int> idx) => Uint32List.fromList(idx);
}

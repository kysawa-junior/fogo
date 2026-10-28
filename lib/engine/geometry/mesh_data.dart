import 'dart:typed_data';

import '../geo/coordinate_projector.dart';

/// Malha produzida pelos builders, independente da biblioteca gráfica:
/// positions/normals em floats intercalados xyz, índices em triângulos.
/// `colors` (opcional, RGBA por vértice) multiplica a cor base do
/// material no backend — usado p/ sombreamento volumétrico e transições
/// de junção sem trocar de material.
class MeshData {
  MeshData({
    required this.positions,
    required this.normals,
    required this.indices,
    this.texCoords,
    this.colors,
  });

  /// Cria a partir de listas de vértices (conveniente nos builders).
  factory MeshData.fromVertices(
    List<Vector3> vertices,
    List<int> triangles, {
    List<Vector3>? normals,
  }) {
    final positions = Float32List(vertices.length * 3);
    final normalOut = Float32List(vertices.length * 3);
    for (var i = 0; i < vertices.length; i++) {
      positions[i * 3] = vertices[i].x;
      positions[i * 3 + 1] = vertices[i].y;
      positions[i * 3 + 2] = vertices[i].z;
      final n = normals == null || normals.length != vertices.length
          ? Vector3(0, 1, 0)
          : normals[i];
      normalOut[i * 3] = n.x;
      normalOut[i * 3 + 1] = n.y;
      normalOut[i * 3 + 2] = n.z;
    }
    return MeshData(
      positions: positions,
      normals: normalOut,
      indices: Uint32List.fromList(triangles),
    );
  }

  final Float32List positions;
  final Float32List normals;
  final Uint32List indices;

  /// Coordenadas de textura opcionais (uv intercalado).
  final Float32List? texCoords;

  /// Cores por vértice opcionais (RGBA, 4 floats por vértice).
  final Float32List? colors;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;

  /// Validação: índices dentro do range e valores finitos — usada pelos
  /// testes e pelo pipeline de render antes de subir para a GPU.
  bool get isValid {
    if (positions.length % 3 != 0 || normals.length != positions.length) {
      return false;
    }
    final c = colors;
    if (c != null && c.length != vertexCount * 4) return false;
    for (var i = 0; i < positions.length; i++) {
      if (!positions[i].isFinite || !normals[i].isFinite) return false;
    }
    if (c != null) {
      for (var i = 0; i < c.length; i++) {
        if (!c[i].isFinite) return false;
      }
    }
    for (final i in indices) {
      if (i < 0 || i >= vertexCount) return false;
    }
    return indices.length % 3 == 0;
  }

  /// Concatena malhas (posições/normais/índices) em UMA, com offsets de
  /// vértice corrigidos. Malhas com cores/UVs ficam fora do contrato —
  /// use apenas para geometria fundida por tile (setas, pads planos).
  static MeshData? merge(Iterable<MeshData> source) {
    final meshes = source.toList(growable: false);
    if (meshes.isEmpty) return null;
    final vertexCount = meshes.fold<int>(0, (n, mesh) => n + mesh.vertexCount);
    final indexCount = meshes.fold<int>(
      0,
      (n, mesh) => n + mesh.indices.length,
    );
    final positions = Float32List(vertexCount * 3);
    final normals = Float32List(vertexCount * 3);
    final indices = Uint32List(indexCount);
    var vertexOffset = 0;
    var indexOffset = 0;
    for (final mesh in meshes) {
      positions.setRange(
        vertexOffset * 3,
        (vertexOffset + mesh.vertexCount) * 3,
        mesh.positions,
      );
      normals.setRange(
        vertexOffset * 3,
        (vertexOffset + mesh.vertexCount) * 3,
        mesh.normals,
      );
      for (var i = 0; i < mesh.indices.length; i++) {
        indices[indexOffset + i] = mesh.indices[i] + vertexOffset;
      }
      vertexOffset += mesh.vertexCount;
      indexOffset += mesh.indices.length;
    }
    return MeshData(positions: positions, normals: normals, indices: indices);
  }

  /// Bounds local (AABB) da malha, para particionamento espacial.
  WorldBounds? computeBounds() {
    if (vertexCount == 0) return null;
    var minX = positions[0], minY = positions[1], minZ = positions[2];
    var maxX = minX, maxY = minY, maxZ = minZ;
    for (var i = 3; i < positions.length; i += 3) {
      final x = positions[i], y = positions[i + 1], z = positions[i + 2];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    return Aabb3.minMax(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
  }
}

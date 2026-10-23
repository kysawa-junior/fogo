import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';

/// Caixa rotacionada (eixo Y) centrada em `center`: 6 faces, 24 vértices,
/// 12 triângulos, normais por face. O winding é auto-corrigido contra a
/// normal da face — nunca sai inside-out.
///
/// Convenção: `headingRadians` 0 = leste (+X); eixo local u ao longo do
/// heading (metade = `halfExtents.x`), v perpendicular (+Z quando heading
/// 0, i.e. sul), y para cima (`halfExtents.y`).
MeshData buildBox(
  Vector3 center,
  Vector3 halfExtents, {
  double headingRadians = 0,
}) {
  final cos = math.cos(headingRadians);
  final sin = math.sin(headingRadians);

  Vector3 corner(double u, double v, double y) => Vector3(
    center.x + u * cos + v * sin,
    center.y + y,
    center.z - u * sin + v * cos,
  );

  final hx = halfExtents.x, hy = halfExtents.y, hz = halfExtents.z;

  final faces = <List<Vector3>>[
    // +u face
    [
      corner(hx, hz, hy),
      corner(hx, -hz, hy),
      corner(hx, -hz, -hy),
      corner(hx, hz, -hy),
    ],
    // -u face
    [
      corner(-hx, -hz, hy),
      corner(-hx, hz, hy),
      corner(-hx, hz, -hy),
      corner(-hx, -hz, -hy),
    ],
    // +v face
    [
      corner(-hx, hz, hy),
      corner(hx, hz, hy),
      corner(hx, hz, -hy),
      corner(-hx, hz, -hy),
    ],
    // -v face
    [
      corner(hx, -hz, hy),
      corner(-hx, -hz, hy),
      corner(-hx, -hz, -hy),
      corner(hx, -hz, -hy),
    ],
    // topo
    [
      corner(-hx, hz, hy),
      corner(hx, hz, hy),
      corner(hx, -hz, hy),
      corner(-hx, -hz, hy),
    ],
    // base
    [
      corner(hx, hz, -hy),
      corner(-hx, hz, -hy),
      corner(-hx, -hz, -hy),
      corner(hx, -hz, -hy),
    ],
  ];
  final faceNormals = <Vector3>[
    Vector3(cos, 0, -sin),
    Vector3(-cos, 0, sin),
    Vector3(sin, 0, cos),
    Vector3(-sin, 0, -cos),
    Vector3(0, 1, 0),
    Vector3(0, -1, 0),
  ];

  final vertices = <Vector3>[];
  final normals = <Vector3>[];
  final triangles = <int>[];

  for (var f = 0; f < faces.length; f++) {
    final quad = faces[f];
    final n = faceNormals[f];
    // Auto-correção de winding: (b-a)×(c-a) precisa apontar junto a n.
    if ((quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(n) < 0) {
      final tmp = quad[1];
      quad[1] = quad[3];
      quad[3] = tmp;
    }
    final i0 = vertices.length;
    for (final p in quad) {
      vertices.add(p);
      normals.add(n);
    }
    triangles.addAll([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3]);
  }

  return MeshData.fromVertices(vertices, triangles, normals: normals);
}

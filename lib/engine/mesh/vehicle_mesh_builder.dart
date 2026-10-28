import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

import '../geometry/mesh_data.dart';

/// Malha de viatura: carroceria de caixas com cores POR VÉRTICE. Frente
/// do carro = +X local; a rotação Y do nó alinha ao movimento. Cores em
/// display-referred (mesma paleta autoral do 2D). A identidade de cada
/// força (polícia/bombeiro) entra pelas CORES — geometria única.
MeshData buildVehicleMesh({
  required vm.Vector3 body,
  required vm.Vector3 cabin,
  required vm.Vector3 bar,
}) {
  final vertices = <vm.Vector3>[];
  final normals = <vm.Vector3>[];
  final triangles = <int>[];
  final colors = <double>[];

  void box(vm.Vector3 center, vm.Vector3 half, vm.Vector3 color) {
    // 6 faces axis-aligned (espaço local — rotação fica no nó).
    // (Vector3 é factory não-const no vector_math.)
    final faces = [
      (
        [
          vm.Vector3(1, 1, 1),
          vm.Vector3(1, 1, -1),
          vm.Vector3(1, -1, -1),
          vm.Vector3(1, -1, 1),
        ],
        vm.Vector3(1, 0, 0),
      ),
      (
        [
          vm.Vector3(-1, 1, 1),
          vm.Vector3(-1, -1, 1),
          vm.Vector3(-1, -1, -1),
          vm.Vector3(-1, 1, -1),
        ],
        vm.Vector3(-1, 0, 0),
      ),
      (
        [
          vm.Vector3(-1, 1, 1),
          vm.Vector3(1, 1, 1),
          vm.Vector3(1, 1, -1),
          vm.Vector3(-1, 1, -1),
        ],
        vm.Vector3(0, 1, 0),
      ),
      (
        [
          vm.Vector3(-1, -1, 1),
          vm.Vector3(-1, -1, -1),
          vm.Vector3(1, -1, -1),
          vm.Vector3(1, -1, 1),
        ],
        vm.Vector3(0, -1, 0),
      ),
      (
        [
          vm.Vector3(-1, 1, 1),
          vm.Vector3(-1, 1, -1),
          vm.Vector3(1, 1, -1),
          vm.Vector3(1, 1, 1),
        ],
        vm.Vector3(0, 0, 1),
      ),
      (
        [
          vm.Vector3(-1, -1, 1),
          vm.Vector3(1, -1, 1),
          vm.Vector3(1, -1, -1),
          vm.Vector3(-1, -1, -1),
        ],
        vm.Vector3(0, 0, -1),
      ),
    ];
    for (final (quad, n) in faces) {
      final f0 = vertices.length;
      for (final sign in quad) {
        vertices.add(
          vm.Vector3(
            center.x + sign.x * half.x,
            center.y + sign.y * half.y,
            center.z + sign.z * half.z,
          ),
        );
        normals.add(n);
        colors.addAll([color.x, color.y, color.z, 1.0]);
      }
      triangles.addAll([f0, f0 + 1, f0 + 2, f0, f0 + 2, f0 + 3]);
    }
  }

  // Proporções de van urbana (~4.8 × 1.9 × 2.5 m com giroflex).
  box(vm.Vector3(0, 1.05, 0), vm.Vector3(2.4, 0.75, 0.95), body); // carroceria
  box(vm.Vector3(-0.2, 1.95, 0), vm.Vector3(1.1, 0.35, 0.85), cabin); // cabine
  box(vm.Vector3(-0.2, 2.4, 0), vm.Vector3(0.35, 0.12, 0.6), bar); // giroflex

  return MeshData(
    positions: _pack3(vertices),
    normals: _pack3(normals),
    indices: Uint32List.fromList(triangles),
    colors: Float32List.fromList(colors),
  );
}

Float32List _pack3(List<vm.Vector3> v) {
  final out = Float32List(v.length * 3);
  for (var i = 0; i < v.length; i++) {
    out[i * 3] = v[i].x;
    out[i * 3 + 1] = v[i].y;
    out[i * 3 + 2] = v[i].z;
  }
  return out;
}

/// Offset de posicionamento que CENTRA o modelo no nó e apoia o chão em
/// y = 0, após girá-lo por [yawRadians] ao redor de Y (alinhamento de
/// frente). [bounds] é o AABB do modelo NO espaço original (pré-rotação).
/// Rotação em torno da origem: o centro gira, y é intocado — o chão fica
/// em cy − hy (antes) e offset.y = −(cy − hy) o apoia em 0.
vm.Vector3 vehicleGroundOffset(vm.Aabb3 bounds, double yawRadians) {
  final cx = (bounds.min.x + bounds.max.x) * 0.5;
  final cy = (bounds.min.y + bounds.max.y) * 0.5;
  final cz = (bounds.min.z + bounds.max.z) * 0.5;
  final hy = (bounds.max.y - bounds.min.y) * 0.5;
  final cos = math.cos(yawRadians), sin = math.sin(yawRadians);
  // Right-hand em +Y: (x,z) → (x·cos + z·sin, −x·sin + z·cos).
  final rcx = cx * cos + cz * sin;
  final rcz = -cx * sin + cz * cos;
  return vm.Vector3(-rcx, hy - cy, -rcz);
}

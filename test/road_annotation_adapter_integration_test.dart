// GPU-gated like flutter_scene's own test suite: mesh upload and texture
// creation need an Impeller device, so these integration checks skip with
// an explicit reason when `flutter test` has no GPU context. The CPU-only
// seams (packing, UVs, fit/omit) live in road_annotation_adapter_test.dart.

import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:flutter_scene/scene.dart' as fscene;
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/engine/geometry/mesh_data.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

import 'package:fogo/features/map/presentation/render/flutter_scene_adapter.dart';

bool _gpuAvailable() {
  try {
    fscene.Scene();
    return true;
  } catch (_) {
    return false;
  }
}

/// Flat quad `2*half` wide centered at (cx, y, cz), normal +Y.
MeshData _quad(double cx, double y, double cz, {double half = 10}) {
  final positions = Float32List.fromList([
    cx - half, y, cz - half, //
    cx + half, y, cz - half, //
    cx + half, y, cz + half, //
    cx - half, y, cz + half, //
  ]);
  final normals = Float32List(12);
  for (var i = 0; i < 4; i++) {
    normals[i * 3 + 1] = 1;
  }
  return MeshData(
    positions: positions,
    normals: normals,
    indices: Uint32List.fromList([0, 1, 2, 0, 2, 3]),
  );
}

RoadNamePlacement _name(
  String text,
  double cx,
  double cz, {
  double maxLength = 200,
}) => RoadNamePlacement(
  text: text,
  center: vm64.Vector3(cx, 0.04, cz),
  tangent: vm64.Vector3(1, 0, 0),
  maxLengthMeters: maxLength,
  maxHeightMeters: 8,
  bounds: vm64.Aabb3.minMax(
    vm64.Vector3(cx - 10, 0, cz - 4),
    vm64.Vector3(cx + 10, 0, cz + 4),
  ),
);

MapScene _scene() {
  final objects = [
    MapSceneObject(
      entityId: 'way/1',
      tileId: 'T',
      mesh: _quad(0, 0, 0),
      color: vm64.Vector3(0.40, 0.42, 0.46),
      kind: SceneObjectKind.road,
    ),
    MapSceneObject(
      entityId: 'mark/1',
      tileId: 'T',
      mesh: _quad(0.02, 0, 0, half: 2),
      color: vm64.Vector3(0.92, 0.92, 0.95),
      kind: SceneObjectKind.roadMarking,
    ),
  ];
  final annotations = [
    RoadAnnotationBatch(
      tileId: 'T',
      roadNames: [_name('Rua A', 0, 0)],
      arrowMesh: _quad(0.04, 0, 0, half: 1),
      bounds: vm64.Aabb3.minMax(
        vm64.Vector3(-10, 0, -10),
        vm64.Vector3(10, 0, 10),
      ),
    ),
    RoadAnnotationBatch(
      tileId: 'T2',
      roadNames: [_name('Rua B', 120, 0)],
      arrowMesh: _quad(0.04, 120, 0, half: 1),
      bounds: vm64.Aabb3.minMax(
        vm64.Vector3(110, 0, -10),
        vm64.Vector3(130, 0, 10),
      ),
    ),
    RoadAnnotationBatch(
      tileId: 'T3',
      // Cannot fit: the real upload must omit this decal entirely.
      roadNames: [
        _name('Avenida Com Nome Comprido Demais', 300, 0, maxLength: 1),
      ],
      arrowMesh: null,
      bounds: vm64.Aabb3.minMax(
        vm64.Vector3(290, 0, -10),
        vm64.Vector3(310, 0, 10),
      ),
    ),
  ];
  return MapScene(
    objects: objects,
    worldBounds: vm64.Aabb3.minMax(
      vm64.Vector3(-20, 0, -20),
      vm64.Vector3(320, 10, 20),
    ),
    tileIds: {'T', 'T2', 'T3'},
    tileBounds: {
      'T': (minX: -20.0, minZ: -20.0, maxX: 20.0, maxZ: 20.0),
      'T2': (minX: 100.0, minZ: -20.0, maxX: 140.0, maxZ: 20.0),
      'T3': (minX: 280.0, minZ: -20.0, maxX: 320.0, maxZ: 20.0),
    },
    annotations: annotations,
  );
}

bool _isDecalNode(fscene.Node node) {
  final material = node.mesh?.primitives.first.material;
  return material is fscene.UnlitMaterial && material.baseColorTexture != null;
}

void main() {
  if (!_gpuAvailable()) {
    test('adapter annotation integration requires a GPU context', () {
      markTestSkipped('No Impeller GPU context');
    });
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  test('annotations are non-pickable, textured, and tile-batched', () async {
    final adapter = FlutterSceneAdapter();
    await adapter.uploadScene(_scene());

    final nodes = adapter.annotationNodes.toList();
    // T and T2 each contribute a decal and an arrow; T3's unfitting name is
    // omitted and contributes nothing.
    expect(nodes, hasLength(4));

    final decals = nodes.where(_isDecalNode).toList();
    final arrows = nodes.where((n) => !_isDecalNode(n)).toList();
    expect(decals, hasLength(2));
    expect(arrows, hasLength(2));
    for (final decal in decals) {
      final material =
          decal.mesh!.primitives.first.material as fscene.UnlitMaterial;
      expect(material.alphaMode, fscene.AlphaMode.blend);
      expect(decal.raycastable, isFalse);
    }
    final crossing = FogoPalette.crossing;
    for (final arrow in arrows) {
      final material =
          arrow.mesh!.primitives.first.material as fscene.UnlitMaterial;
      expect(material.baseColorTexture, isNull);
      expect(material.baseColorFactor.x, closeTo(crossing.x, 1e-6));
      expect(material.baseColorFactor.y, closeTo(crossing.y, 1e-6));
      expect(material.baseColorFactor.z, closeTo(crossing.z, 1e-6));
      expect(arrow.raycastable, isFalse);
    }

    // Raycast through the decal/arrow stack still selects the base road.
    final camera = fscene.PerspectiveCamera(
      position: vm.Vector3(0, 100, 50),
      target: vm.Vector3(0, 0, 0),
      fovNear: 0.5,
      fovFar: 60000,
    );
    expect(
      adapter.pickEntity(const Offset(400, 300), const Size(800, 600), camera),
      'way/1',
    );
  });

  test(
    'annotation LOD cuts directly at 1200m; road markings stay at 3500m',
    () async {
      final adapter = FlutterSceneAdapter();
      await adapter.uploadScene(_scene());

      bool annotationsVisible() =>
          adapter.annotationNodes.every((node) => node.visible);

      adapter.updateLOD(1100);
      expect(annotationsVisible(), isTrue);
      expect(adapter.isEntityVisible('way/1'), isTrue);
      expect(adapter.isEntityVisible('mark/1'), isTrue);

      adapter.updateLOD(1300);
      expect(annotationsVisible(), isFalse);
      expect(adapter.isEntityVisible('way/1'), isTrue);
      expect(
        adapter.isEntityVisible('mark/1'),
        isTrue,
        reason:
            'roadMarking keeps its 3500m policy; only annotations cut at 1200m',
      );

      // Direct cutoff: no hysteresis on annotations.
      adapter.updateLOD(1199.9);
      expect(annotationsVisible(), isTrue);
    },
  );

  test('atlas failure is tile-local and keeps base roads selectable', () async {
    final adapter = FlutterSceneAdapter();
    final scene = _scene();
    adapter.failNextRoadNameAtlas = true;
    await adapter.uploadScene(scene);

    final nodes = adapter.annotationNodes.toList();
    final decals = nodes.where(_isDecalNode).toList();
    // Tile T's atlas was injected to fail; T2's decal still uploads and
    // every arrow batch survives.
    expect(decals, hasLength(1));
    expect(nodes.where((n) => !_isDecalNode(n)), hasLength(2));

    final camera = fscene.PerspectiveCamera(
      position: vm.Vector3(0, 100, 50),
      target: vm.Vector3(0, 0, 0),
      fovNear: 0.5,
      fovFar: 60000,
    );
    expect(
      adapter.pickEntity(const Offset(400, 300), const Size(800, 600), camera),
      'way/1',
    );
  });
}

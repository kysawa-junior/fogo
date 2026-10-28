// TASK-0011: gate de range de volumes. A função pura roda sem GPU; a
// integração (flip de visibilidade volume/pad) é GPU-gated como a suíte
// do próprio flutter_scene — geometria/textura precisam de Impeller.

import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:flutter_scene/scene.dart' as fscene;
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/engine/geometry/mesh_data.dart';
import 'package:fogo/features/map/presentation/render/flutter_scene_adapter.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

bool _gpuAvailable() {
  try {
    fscene.Scene();
    return true;
  } catch (_) {
    return false;
  }
}

MeshData _quad(double y, {double half = 10}) {
  final positions = Float32List.fromList([
    -half, y, -half, //
    half, y, -half, //
    half, y, half, //
    -half, y, half, //
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

void main() {
  group('extrusionFactor (curva pura da extrusão)', () {
    const radiusIn = 600.0, radiusOut = 700.0;
    double k(double d) => FlutterSceneAdapter.extrusionFactor(
      distanceMeters: d,
      radiusIn: radiusIn,
      radiusOut: radiusOut,
    );

    test('satura nas pontas: 0 além de 700 m, 1 dentro de 600 m', () {
      expect(k(800), 0.0);
      expect(k(700), 0.0);
      expect(k(600), 1.0);
      expect(k(100), 1.0);
    });

    test('monotônica e suave na banda (sem pop em 700/600)', () {
      double previous = -1;
      for (var d = 700.0; d >= 600.0; d -= 5) {
        final v = k(d);
        expect(v, greaterThanOrEqualTo(previous));
        expect(v, lessThanOrEqualTo(1.0));
        previous = v;
      }
      expect(k(695), lessThan(0.1), reason: 'chegada suave em 700');
      expect(k(605), greaterThan(0.9), reason: 'assentamento suave em 600');
    });
  });

  if (!_gpuAvailable()) {
    test('building range gate integration requires a GPU context', () {
      markTestSkipped('No Impeller GPU context');
    });
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'volume/pad flipam no raio da câmera e LOD 3500m esconde ambos',
    () async {
      final adapter = FlutterSceneAdapter();
      final scene = MapScene(
        objects: [
          MapSceneObject(
            entityId: 'way/1',
            tileId: 'T',
            mesh: _quad(9),
            color: vm64.Vector3(0.16, 0.18, 0.22),
            kind: SceneObjectKind.building,
            rangeGated: true,
          ),
        ],
        worldBounds: vm64.Aabb3.minMax(
          vm64.Vector3(-20, 0, -20),
          vm64.Vector3(20, 10, 20),
        ),
        tileIds: {'T'},
        tileBounds: {'T': (minX: -20.0, minZ: -20.0, maxX: 20.0, maxZ: 20.0)},
        buildingFootprints: [
          BuildingFootprintBatch(tileId: 'T', mesh: _quad(0.06, half: 8)),
        ],
      );
      await adapter.uploadScene(scene);

      final volume = adapter.gatedVolumeNodes.single;
      final pad = adapter.footprintNodes.single;
      expect(volume.visible, isFalse, reason: 'nasce oculto pós-upload');
      expect(pad.visible, isFalse);

      // Câmera a 800 m do alvo, POSIÇÃO em cima do tile: volume on, pad off.
      adapter.updateLOD(800, cameraPosition: vm.Vector3(0, 100, 0));
      expect(volume.visible, isTrue);
      expect(volume.scale.y, 1.0);
      expect(pad.visible, isFalse);

      // Câmera deslocada 2 km: só o pad (footprint 2D), volume fora.
      adapter.updateLOD(800, cameraPosition: vm.Vector3(2000, 100, 0));
      expect(volume.visible, isFalse);
      expect(pad.visible, isTrue);

      // Banda de extrusão (box distance 650 m do tile: câmera em 670):
      // volume parcial (~meia altura) sobre o pad ainda visível — o
      // prédio CRESCE do footprint.
      adapter.updateLOD(800, cameraPosition: vm.Vector3(670, 100, 0));
      expect(volume.visible, isTrue);
      expect(volume.scale.y, closeTo(0.5, 0.02));
      expect(pad.visible, isTrue);
      adapter.updateLOD(800, cameraPosition: vm.Vector3(500, 100, 0));
      expect(volume.scale.y, 1.0);
      expect(pad.visible, isFalse);

      // LOD 3.500 m: ambos escondidos, como as vias de nível 1 hoje.
      adapter.updateLOD(4000, cameraPosition: vm.Vector3(0, 100, 0));
      expect(volume.visible, isFalse);
      expect(pad.visible, isFalse);

      // Volta ao range: prédio selecionável (raycast acerta o volume visível).
      adapter.updateLOD(800, cameraPosition: vm.Vector3(0, 100, 0));
      final camera = fscene.PerspectiveCamera(
        position: vm.Vector3(0, 100, 50),
        target: vm.Vector3(0, 0, 0),
        fovNear: 0.5,
        fovFar: 60000,
      );
      expect(
        adapter.pickEntity(
          const Offset(400, 300),
          const Size(800, 600),
          camera,
        ),
        'way/1',
        reason: 'volume próximo permanece selecionável',
      );
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/features/map/presentation/render/flutter_scene_adapter.dart';

void main() {
  group('FlutterSceneAdapter.distanceSqToBox', () {
    test('returns zero when camera target is inside tile bounds', () {
      expect(
        FlutterSceneAdapter.distanceSqToBox(
          minX: 0,
          minZ: 0,
          maxX: 10,
          maxZ: 10,
          x: 4,
          z: 6,
        ),
        0,
      );
    });

    test('uses nearest edge and includes both axes outside tile', () {
      expect(
        FlutterSceneAdapter.distanceSqToBox(
          minX: 0,
          minZ: 0,
          maxX: 2,
          maxZ: 2,
          x: 5,
          z: 6,
        ),
        25,
      );
    });
  });
}

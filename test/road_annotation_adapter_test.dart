import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/engine/scene/lod_policy.dart';
import 'package:fogo/features/map/presentation/render/flutter_scene_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('annotation cutoff is 1200m and road-marking LOD stays 3500m', () {
    expect(RoadAnnotationBatch.maxCameraDistanceMeters, 1200);
    expect(
      LodPolicy.maxDistanceFor(LodPolicy.levelOf(SceneObjectKind.roadMarking)),
      3500,
    );
  });

  group('packRoadNameAtlas (CPU seam, no GPU required)', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    RoadNamePlacement placement(
      String text, {
      double maxLength = 200,
      Vector3? center,
    }) => RoadNamePlacement(
      text: text,
      center: center ?? Vector3(50, 0.04, 0),
      tangent: Vector3(1, 0, 0),
      maxLengthMeters: maxLength,
      maxHeightMeters: 8,
      bounds: Aabb3.minMax(Vector3(0, 0, -4), Vector3(100, 0, 4)),
    );

    test('omits a name that cannot fit its straight span legibly', () {
      final shortSpan = placement('Avenida Muito Longa', maxLength: 1);
      expect(FlutterSceneAdapter.packRoadNameAtlas([shortSpan]), isNull);

      final mixed = FlutterSceneAdapter.packRoadNameAtlas([
        placement('Rua A'),
        placement('Avenida Muito Longa', maxLength: 1),
      ]);
      expect(mixed, isNotNull);
      expect(
        mixed!.mesh.vertexCount,
        4,
        reason: 'only the fitting name becomes a decal quad',
      );
    });

    test('maps quad corners to atlas UVs along the road tangent', () {
      final packed = FlutterSceneAdapter.packRoadNameAtlas([
        placement('Rua A', center: Vector3(50, 0.04, 0)),
      ])!;
      final mesh = packed.mesh;

      expect(mesh.vertexCount, 4);
      expect(mesh.indices.length, 6);
      expect(mesh.texCoords, isNotNull);
      expect(packed.width, greaterThan(0));
      expect(packed.height, greaterThan(0));

      final uv = mesh.texCoords!;
      // Quad vertex order: v0 (-t,-n), v1 (+t,-n), v2 (+t,+n), v3 (-t,+n).
      final corners = List.generate(
        4,
        (i) => Vector3(
          mesh.positions[i * 3],
          mesh.positions[i * 3 + 1],
          mesh.positions[i * 3 + 2],
        ),
      );
      // World quad spans ±tangent (length) and ±normal (road height).
      expect(corners[0].x, lessThan(corners[1].x));
      expect(corners[0].z, lessThan(corners[2].z));
      // UVs: [uMin,vMax, uMax,vMax, uMax,vMin, uMin,vMin] per vertex order.
      expect(uv[0], lessThan(uv[2]));
      expect(uv[0], uv[6]);
      expect(uv[2], uv[4]);
      expect(uv[1], uv[3]);
      expect(uv[1], greaterThan(uv[5]));
      expect(uv[5], uv[7]);
      for (final value in uv) {
        expect(value, inInclusiveRange(0, 1));
      }

      // Decal quad stays inside the supplied fit bounds and above asphalt.
      for (final corner in corners) {
        expect(corner.y, closeTo(0.04, 1e-6));
        expect(corner.x, inInclusiveRange(0, 100));
        expect(corner.z, inInclusiveRange(-4, 4));
      }
    });
  });
}

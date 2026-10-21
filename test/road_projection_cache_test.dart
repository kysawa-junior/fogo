import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/vector/road_projection_cache.dart';

void main() {
  test('reuses shared node projection and snaps both axes to half pixels', () {
    final RoadProjectionCache cache = RoadProjectionCache();
    int projections = 0;

    Offset project(double lat, double lng) {
      projections++;
      return const Offset(12.26, 8.74);
    }

    final Offset roadA = cache.project(-22.12345, -49.54321, project);
    final Offset roadB = cache.project(-22.12345, -49.54321, project);

    expect(roadA, const Offset(12.5, 8.5));
    expect(roadB, roadA);
    expect(projections, 1);
  });

  test('clear invalidates cached coordinates for the next paint frame', () {
    final RoadProjectionCache cache = RoadProjectionCache();
    int projections = 0;

    Offset project(double lat, double lng) =>
        Offset((projections++).toDouble(), 0);

    cache.project(0, 0, project);
    cache.project(0, 0, project);
    cache.clear();
    final Offset nextFrame = cache.project(0, 0, project);

    expect(projections, 2);
    expect(nextFrame.dx, 1);
  });
}

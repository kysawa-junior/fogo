import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/vector/road_geometry_merger/road_geometry_merger.dart';
import 'package:fogo/features/map/vector/road_surface/road_surface.dart';
import 'package:fogo/features/map/vector/vector_data/vector_data.dart';

MapRoad _road(
  String name,
  List<double> coords, {
  bool oneway = true,
  RoadClass cls = RoadClass.secondary,
}) => MapRoad(
  cls: cls,
  name: name,
  ref: null,
  oneway: oneway,
  bridge: false,
  tunnel: false,
  flatCoords: coords,
  bbox: [0, 0, 1, 1],
);

void main() {
  test('merges roundabout arcs into closed loop despite access branch', () {
    // Two one-way arcs meet at both ends; the differently named access remains
    // a separate feature at the shared roundabout node.
    final MapRoad westArc = _road('Rotatória', [
      0, 0, // P0
      0, 0.001, // P1
      0.001, 0.001, // P2
    ]);
    final MapRoad eastArc = _road('Rotatória', [
      0.001, 0.001, // P2
      0.001, 0, // P3
      0, 0, // P0
    ]);
    final MapRoad access = _road('Acesso', [0.001, 0.001, 0.002, 0.001]);

    final List<MapRoad> merged = RoadGeometryMerger.merge([
      westArc,
      eastArc,
      access,
    ]);

    expect(merged, hasLength(2));
    final MapRoad roundabout = merged.singleWhere(
      (MapRoad road) => road.name == 'Rotatória',
    );
    expect(
      roundabout.flatCoords.first,
      roundabout.flatCoords[roundabout.flatCoords.length - 2],
    );
    expect(roundabout.flatCoords[1], roundabout.flatCoords.last);
    expect(roundabout.pointCount, 5, reason: 'shared nodes emitted once');
    expect(roundabout.flatCoords, [
      ...eastArc.flatCoords,
      ...westArc.flatCoords.skip(2),
    ], reason: 'merged one-way loop retains original travel direction');
    expect(
      RoadSurfaceBuilder.build(roundabout.flatCoords, 4)?.contours,
      hasLength(2),
      reason: 'merged arcs become a hollow polygon annulus',
    );
  });

  test('deduplicates same way loaded from adjacent cells', () {
    final MapRoad road = _road('Rua A', [0, 0, 0, 0.001], oneway: false);

    expect(
      RoadGeometryMerger.merge([
        road,
        _road('Rua A', [0, 0, 0, 0.001], oneway: false),
      ]),
      hasLength(1),
    );
  });

  test('deduplicates reversed copies of bidirectional ways', () {
    final MapRoad road = _road('Rua A', [0, 0, 0, 0.001], oneway: false);
    final MapRoad reversed = _road('Rua A', [0, 0.001, 0, 0], oneway: false);

    expect(RoadGeometryMerger.merge([road, reversed]), hasLength(1));
  });

  test('does not merge through an ambiguous same-style branch', () {
    final List<MapRoad> roads = [
      _road('Rua A', [0, -0.001, 0, 0], oneway: false),
      _road('Rua A', [0, 0, 0, 0.001], oneway: false),
      _road('Rua A', [0, 0, 0.001, 0], oneway: false),
    ];

    expect(RoadGeometryMerger.merge(roads), hasLength(3));
  });

  test('does not reverse one-way segments to force a merge', () {
    final MapRoad first = _road('Rua A', [0, 0, 0, 0.001]);
    final MapRoad reversedNext = _road('Rua A', [0.001, 0, 0, 0.001]);

    expect(RoadGeometryMerger.merge([first, reversedNext]), hasLength(2));
  });

  test('merged one-way segments preserve end-to-start order', () {
    final MapRoad first = _road('Rua A', [0, 0, 0, 0.001]);
    final MapRoad next = _road('Rua A', [0, 0.001, 0, 0.002]);

    final MapRoad merged = RoadGeometryMerger.merge([first, next]).single;

    expect(merged.flatCoords, [0, 0, 0, 0.001, 0, 0.002]);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:fogo/engine/domain/road.dart';
import 'package:fogo/engine/domain/road_properties.dart';
import 'package:fogo/engine/domain/road_type.dart';
import 'package:fogo/engine/domain/sourced_value.dart';
import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/engine/geometry/mesh_data.dart';
import 'package:fogo/engine/mesh/road_annotation_builder.dart';
import 'package:fogo/engine/spatial/spatial_partitioner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoadAnnotationBuilder arrows', () {
    test('forward and reverse arrows follow the ordered-way direction', () {
      final path = [Vector3(0, 0, 0), Vector3(100, 0, 0)];
      final forward = RoadAnnotationBuilder.build(
        road: _road(direction: RoadDirection.forward),
        centerline: path,
        roadSurfaceY: 3,
      );
      final reverse = RoadAnnotationBuilder.build(
        road: _road(direction: RoadDirection.reverse),
        centerline: path,
        roadSurfaceY: 3,
      );

      expect(forward.arrows, hasLength(2));
      expect(reverse.arrows, hasLength(2));
      for (final arrow in forward.arrows) {
        expect(_vertex(arrow.mesh, 0).x, greaterThan(arrow.center.x));
        expect(arrow.center.z, 0, reason: 'one-way arrows stay on centerline');
      }
      for (final arrow in reverse.arrows) {
        expect(_vertex(arrow.mesh, 0).x, lessThan(arrow.center.x));
        expect(arrow.center.z, 0, reason: 'one-way arrows stay on centerline');
      }
    });

    test(
      'both directions use opposing quarter-width lanes and 45m stations',
      () {
        final result = RoadAnnotationBuilder.build(
          road: _road(direction: RoadDirection.both, width: 8),
          centerline: [Vector3(0, 0, 0), Vector3(100, 0, 0)],
          roadSurfaceY: 0,
        );

        expect(result.arrows, hasLength(4));
        final firstStation = result.arrows.take(2).toList();
        final secondStation = result.arrows.skip(2).toList();
        expect(firstStation[0].center.x, closeTo(22.5, 1e-6));
        expect(firstStation[1].center.x, closeTo(22.5, 1e-6));
        expect(secondStation[0].center.x, closeTo(67.5, 1e-6));
        expect(secondStation[1].center.x, closeTo(67.5, 1e-6));
        expect(
          secondStation[0].center.x - firstStation[0].center.x,
          closeTo(45, 1e-6),
        );
        expect(firstStation[0].center.z, closeTo(2, 1e-6));
        expect(firstStation[1].center.z, closeTo(-2, 1e-6));
        expect(_vertex(firstStation[0].mesh, 0).x, greaterThan(22.5));
        expect(_vertex(firstStation[1].mesh, 0).x, lessThan(22.5));
      },
    );

    test('short route gets an arrow per allowed direction at its midpoint', () {
      final result = RoadAnnotationBuilder.build(
        road: _road(direction: RoadDirection.both, width: 8),
        centerline: [Vector3(0, 0, 0), Vector3(30, 0, 0)],
        roadSurfaceY: 1,
      );

      expect(result.arrows, hasLength(2));
      expect(result.arrows[0].center.x, closeTo(15, 1e-6));
      expect(result.arrows[1].center.x, closeTo(15, 1e-6));
      expect(result.arrows[0].center.z, closeTo(2, 1e-6));
      expect(result.arrows[1].center.z, closeTo(-2, 1e-6));
    });

    test('arrows follow local tangent on curves and lift by 0.04m', () {
      final result = RoadAnnotationBuilder.build(
        road: _road(direction: RoadDirection.forward),
        centerline: [Vector3(0, 0, 0), Vector3(30, 0, 0), Vector3(30, 0, 40)],
        roadSurfaceY: 7.5,
      );

      expect(result.arrows, hasLength(2));
      final curvedStation = result.arrows.last;
      final tip = _vertex(curvedStation.mesh, 0);
      expect(tip.z, greaterThan(curvedStation.center.z));
      expect(tip.x, closeTo(curvedStation.center.x, 1e-6));
      expect(curvedStation.center.y, closeTo(7.54, 1e-6));
      for (final arrow in result.arrows) {
        for (var i = 0; i < arrow.mesh.vertexCount; i++) {
          expect(arrow.mesh.positions[i * 3 + 1], closeTo(7.54, 1e-6));
        }
      }
    });
  });

  group('RoadAnnotationBuilder road-name placements', () {
    test('uses a non-empty ref when name is blank and supplies fit bounds', () {
      final result = RoadAnnotationBuilder.build(
        road: _road(
          tags: {'name': '  ', 'ref': 'SP-333'},
          direction: RoadDirection.both,
          width: 8,
        ),
        centerline: [Vector3(0, 0, 0), Vector3(100, 0, 0)],
        roadSurfaceY: 2,
      );
      final placement = result.roadName!;

      expect(placement.text, 'SP-333');
      expect(placement.maxLengthMeters, closeTo(100, 1e-6));
      expect(placement.maxHeightMeters, 8);
      expect(placement.center.x, closeTo(50, 1e-6));
      expect(placement.center.y, closeTo(2.04, 1e-6));
      expect(placement.tangent.x, closeTo(1, 1e-6));
      expect(placement.bounds.min.x, closeTo(0, 1e-6));
      expect(placement.bounds.max.x, closeTo(100, 1e-6));
      expect(placement.bounds.min.z, closeTo(-4, 1e-6));
      expect(placement.bounds.max.z, closeTo(4, 1e-6));

      final namedResult = RoadAnnotationBuilder.build(
        road: _road(tags: {'name': 'Main Avenue', 'ref': 'SP-333'}),
        centerline: [Vector3(0, 0, 0), Vector3(100, 0, 0)],
        roadSurfaceY: 0,
      );
      expect(namedResult.roadName!.text, 'Main Avenue');
    });

    test('omits name placement when neither name nor ref is usable', () {
      final result = RoadAnnotationBuilder.build(
        road: _road(tags: {'name': ' ', 'ref': ''}),
        centerline: [Vector3(0, 0, 0), Vector3(100, 0, 0)],
        roadSurfaceY: 0,
      );

      expect(result.roadName, isNull);
    });
  });

  test('FogoEngine assigns explicit tile batches and complete bounds', () {
    final engine = FogoEngine.build(
      Uint8List.fromList(utf8.encode(_namedRoadOsm)),
    )!;
    final batches = engine.scene.annotations;

    expect(batches, isNotEmpty);
    expect(
      batches.map((batch) => batch.tileId).toSet(),
      hasLength(batches.length),
    );
    for (final batch in batches) {
      expect(batch.tileId, isNotEmpty);
      expect(engine.scene.tileIds, contains(batch.tileId));
      final tileBounds = engine.scene.tileBounds[batch.tileId]!;
      expect(tileBounds.minX, lessThanOrEqualTo(batch.bounds.min.x));
      expect(tileBounds.minZ, lessThanOrEqualTo(batch.bounds.min.z));
      expect(tileBounds.maxX, greaterThanOrEqualTo(batch.bounds.max.x));
      expect(tileBounds.maxZ, greaterThanOrEqualTo(batch.bounds.max.z));

      for (final name in batch.roadNames) {
        expect(batch.bounds.min.x, lessThanOrEqualTo(name.bounds.min.x));
        expect(batch.bounds.min.z, lessThanOrEqualTo(name.bounds.min.z));
        expect(batch.bounds.max.x, greaterThanOrEqualTo(name.bounds.max.x));
        expect(batch.bounds.max.z, greaterThanOrEqualTo(name.bounds.max.z));
      }
      final arrowBounds = batch.arrowMesh?.computeBounds();
      if (arrowBounds != null) {
        expect(batch.bounds.min.x, lessThanOrEqualTo(arrowBounds.min.x));
        expect(batch.bounds.min.z, lessThanOrEqualTo(arrowBounds.min.z));
        expect(batch.bounds.max.x, greaterThanOrEqualTo(arrowBounds.max.x));
        expect(batch.bounds.max.z, greaterThanOrEqualTo(arrowBounds.max.z));
      }
    }

    expect(batches.expand((batch) => batch.roadNames), hasLength(1));
    expect(batches.any((batch) => batch.arrowMesh != null), isTrue);
    expect(
      batches.fold<int>(
        0,
        (count, batch) => count + (batch.arrowMesh?.vertexCount ?? 0),
      ),
      28,
      reason: 'two stations × two allowed directions are tile-batched',
    );
    expect(
      engine.map2d.strokes,
      hasLength(1),
      reason:
          'annotations stay out of Map2DScene: the single road produces one '
          'stroke, with no extra strokes from its 4 arrows or name decal',
    );
    expect(engine.map2d.fills, isEmpty);

    // Center-tile ownership: each decal belongs to the tile containing its
    // geometry center, mirroring the engine's own partitioner setup.
    final grid = SpatialPartitioner.partition(engine.scene.worldBounds);
    final tiles = TileManager(grid);
    for (final batch in batches) {
      for (final name in batch.roadNames) {
        expect(tiles.tileOfPoint(name.center)?.id, batch.tileId);
      }
    }
  });
}

Road _road({
  Map<String, String> tags = const {'name': 'Main'},
  RoadDirection direction = RoadDirection.forward,
  double width = 8,
}) => Road(
  id: 'way/1',
  tags: tags,
  points: const [],
  type: RoadType.residential,
  properties: RoadProperties(
    widthMeters: SourcedValue<double>.known(width),
    direction: direction,
  ),
);

Vector3 _vertex(MeshData mesh, int index) => Vector3(
  mesh.positions[index * 3],
  mesh.positions[index * 3 + 1],
  mesh.positions[index * 3 + 2],
);

const _namedRoadOsm = '''
<osm version="0.6">
  <node id="1" lat="0" lon="0"/>
  <node id="2" lat="0" lon="0.0001"/>
  <node id="3" lat="0" lon="0.001"/>
  <way id="10">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Main Street"/>
    <tag k="width" v="8"/>
  </way>
</osm>
''';

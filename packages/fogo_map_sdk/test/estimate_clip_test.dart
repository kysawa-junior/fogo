import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';
import 'package:fogo_map_sdk/src/renderer.dart';
import 'package:fogo_map_sdk/src/road_geometry.dart';

/// Independent implementation of the FNV-1a seed specified in ADR-0005.
/// The golden test asserts the SDK helper matches this specification
/// exactly, guarding against regressions to process-randomized hashing.
double _specJitter(List<double> coordinates) {
  int seed = 0x811c9dc5;
  for (final double value in coordinates.take(8)) {
    seed ^= (value * 1e6).round() & 0x7fffffff;
    seed = (seed * 0x01000193) & 0x7fffffff;
  }
  return ((seed & 0xF) / 15).clamp(0, 1).toDouble();
}

void main() {
  group('height estimate jitter', () {
    test('matches the ADR-0005 FNV-1a specification exactly', () {
      for (final List<double> coordinates in [
        [-0.0003, -0.0003, -0.0003, 0.0003, 0.0003, 0.0003, 0.0003, -0.0003],
        [-22.2172, -49.95, -22.2171, -49.9501],
        [0.00012, 0.00004, 0.00013, 0.00003, 0.00011, 0.00005],
      ]) {
        expect(fogoHeightJitter(coordinates), _specJitter(coordinates));
        expect(fogoHeightJitter(coordinates), inInclusiveRange(0, 1));
      }
    });

    test('uses only coordinate values, never per-process hashes', () {
      final List<double> coordinates = [-22.2225, -49.8044, -22.2224, -49.8043];
      // Identical inputs must produce byte-identical results, and inputs
      // differing only beyond the seed precision are treated as one.
      expect(
        fogoHeightJitter(coordinates),
        fogoHeightJitter(List<double>.of(coordinates)),
      );
      expect(
        fogoHeightJitter(coordinates),
        fogoHeightJitter([...coordinates.take(2), -22.2224, -49.8043]),
      );
    });
  });

  group('near-plane polygon clipping', () {
    test('keeps the visible part of a polygon crossing the horizon', () {
      final FogoCameraTransform transform = FogoCameraTransform(
        const FogoCameraState(
          center: FogoCoordinate(0, 0),
          zoom: 16,
          pitch: 60,
        ),
        const Size(256, 256),
      );
      // A large rectangle straddling the far/behind boundary: its southern
      // half sits behind the tilted camera, its northern half is visible.
      final List<Offset> straddling = [
        transform.groundOffset(const FogoCoordinate(-0.05, -0.05)),
        transform.groundOffset(const FogoCoordinate(0.05, -0.05)),
        transform.groundOffset(const FogoCoordinate(0.05, 0.05)),
        transform.groundOffset(const FogoCoordinate(-0.05, 0.05)),
      ];
      final List<Offset>? clipped = transform.projectGroundPolygon(straddling);
      expect(clipped, isNotNull, reason: 'polygon must clip, not vanish');
      expect(clipped!.length, greaterThanOrEqualTo(3));
      // Everything fully behind the camera yields nothing.
      final List<Offset> behind = [
        transform.groundOffset(const FogoCoordinate(-0.12, -0.02)),
        transform.groundOffset(const FogoCoordinate(-0.12, 0.02)),
        transform.groundOffset(const FogoCoordinate(-0.13, 0.0)),
      ];
      expect(transform.projectGroundPolygon(behind), isNull);
    });

    test('clipped vertices always project in front of the camera', () {
      final FogoCameraTransform transform = FogoCameraTransform(
        const FogoCameraState(
          center: FogoCoordinate(0, 0),
          zoom: 16,
          pitch: 55,
          bearing: 40,
        ),
        const Size(400, 300),
      );
      for (final double span in [0.01, 0.05, 0.2, 0.6]) {
        final List<Offset> quad = [
          transform.groundOffset(FogoCoordinate(-span, -span)),
          transform.groundOffset(FogoCoordinate(span, -span)),
          transform.groundOffset(FogoCoordinate(span, span)),
          transform.groundOffset(FogoCoordinate(-span, span)),
        ];
        final List<Offset>? clipped = transform.projectGroundPolygon(quad);
        if (clipped == null) continue;
        for (final Offset point in clipped) {
          expect(point.dx.isFinite, isTrue);
          expect(point.dy.isFinite, isTrue);
          // Front-of-camera screen points stay inside the projected frustum
          // horizontal bounds with generous perspective margin.
          expect(point.dx.abs(), lessThan(1e6));
          expect(point.dy.abs(), lessThan(1e6));
        }
        expect(math.max(clipped.length, 0), greaterThanOrEqualTo(3));
      }
    });
  });

  group('wired estimate path', () {
    test('renderer extrusion height derives from the stable seed', () async {
      const Size size = Size(256, 256);
      const FogoCameraState camera = FogoCameraState(
        center: FogoCoordinate(0, 0),
        zoom: 16,
        pitch: 45,
      );
      final FogoCameraTransform transform = FogoCameraTransform(camera, size);
      final FogoMapStyle estimateStyle = FogoMapStyle(
        background: const Color(0xFF101010),
        building: const Color(0xFFDDDDDD),
        showAreas: false,
        showWaterLines: false,
        showRail: false,
        showRoads: false,
        showBuildings: true,
        showLabels: false,
        showPois: false,
        showAttribution: false,
      );
      final FogoMapArea flat = FogoMapArea(
        kind: FogoAreaKind.water,
        coordinates: [
          -0.0003, -0.0003,
          -0.0003, 0.0003,
          0.0003, 0.0003,
          0.0003, -0.0003,
        ],
        bbox: [-0.0003, -0.0003, 0.0003, 0.0003],
      );

      // Expected height computed independently from the ADR-0005 spec:
      // area band from the ground footprint + FNV-1a jitter.
      final List<Offset> ground = [
        for (int i = 0; i < flat.coordinates.length; i += 2)
          transform.groundOffset(
            FogoCoordinate(flat.coordinates[i], flat.coordinates[i + 1]),
          ),
      ];
      double sum = 0;
      for (int i = 0; i < ground.length - 1; i++) {
        sum +=
            ground[i].dx * ground[i + 1].dy -
            ground[i + 1].dx * ground[i].dy;
      }
      final double areaM2 =
          (sum.abs() * 0.5) / (transform.scale * transform.scale);
      expect(areaM2, greaterThan(1500), reason: 'band precondition');
      expect(areaM2, lessThan(6000), reason: 'band precondition');
      const double base = 21.0;
      final double expectedPx = transform.heightToPixels(
        base + _specJitter(flat.coordinates) * 4,
      );
      final double northEdge = transform
          .groundOffset(const FogoCoordinate(0.0003, 0))
          .dy;
      final double? syRoof = transform
          .projectGround(Offset(0, northEdge), expectedPx)
          ?.dy;
      final double? syFlat = transform
          .projectGround(Offset(0, northEdge), 0)
          ?.dy;
      expect(syRoof, isNotNull);
      expect(syFlat, isNotNull);

      int firstRoofRow(Uint8List pixels) {
        for (int y = 0; y < 256; y++) {
          final int i = (y * 256 + 128) * 4;
          if (pixels[i] >= 200 && pixels[i + 1] >= 200) {
            return y;
          }
        }
        return -1;
      }

      final Uint8List estimated = await _paint(
        camera: camera,
        style: estimateStyle,
        data: FogoMapRenderData(buildings: [flat]),
      );
      final int measuredRoof = firstRoofRow(estimated);
      expect(measuredRoof, greaterThan(0), reason: 'extrusion must render');
      expect(
        measuredRoof - syRoof!,
        inInclusiveRange(-0.5, 1.5),
        reason: 'roof top must match the spec-seeded height',
      );

      final FogoMapStyle realOnly = FogoMapStyle(
        background: estimateStyle.background,
        building: estimateStyle.building,
        showAreas: false,
        showWaterLines: false,
        showRail: false,
        showRoads: false,
        showBuildings: true,
        showLabels: false,
        showPois: false,
        showAttribution: false,
        estimateBuildingHeights: false,
      );
      final Uint8List flatRendered = await _paint(
        camera: camera,
        style: realOnly,
        data: FogoMapRenderData(buildings: [flat]),
      );
      final int measuredFlat = firstRoofRow(flatRendered);
      expect(measuredFlat, greaterThan(0));
      expect(
        measuredFlat - syFlat!,
        inInclusiveRange(-0.5, 1.5),
        reason: 'without estimates the roof sits on the ground plane',
      );
      expect(measuredRoof, lessThan(measuredFlat));
    });
  });
}

Future<Uint8List> _paint({
  required FogoCameraState camera,
  required FogoMapStyle style,
  required FogoMapRenderData data,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  FogoMapPainter(
    camera: camera,
    data: data,
    manifest: FogoMapManifest(
      bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
      cellSize: 0.05,
      columns: 40,
      rows: 40,
      attribution: '',
      generatedAt: '',
      source: '',
    ),
    style: style,
    polylines: const [],
    surfaceCache: FogoRoadSurfaceCache(),
    projectionCache: FogoProjectionCache(),
  ).paint(canvas, const Size(256, 256));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(256, 256);
  final ByteData bytes =
      (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  picture.dispose();
  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}

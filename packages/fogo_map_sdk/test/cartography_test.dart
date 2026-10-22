import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';
import 'package:fogo_map_sdk/src/renderer.dart';
import 'package:fogo_map_sdk/src/road_geometry.dart';

import 'test_support.dart';

void main() {
  group('cartographic width model', () {
    test('ramps are continuous, monotonic and hierarchical', () {
      for (final FogoRoadClass roadClass in FogoRoadClass.values) {
        double previous = FogoCartography.widthPx(roadClass, 3);
        for (double z = 3.05; z <= 20.0; z += 0.05) {
          final double width = FogoCartography.widthPx(roadClass, z);
          expect(
            width,
            greaterThanOrEqualTo(previous - 1e-9),
            reason: '$roadClass shrank at z$z',
          );
          expect(
            (width - previous).abs(),
            lessThan(0.25),
            reason: '$roadClass jumped at z$z',
          );
          previous = width;
        }
      }
      for (final double z in [13, 16, 19]) {
        expect(
          FogoCartography.widthPx(FogoRoadClass.motorway, z),
          greaterThan(FogoCartography.widthPx(FogoRoadClass.trunk, z)),
          reason: 'hierarchy at z$z',
        );
        expect(
          FogoCartography.widthPx(FogoRoadClass.trunk, z),
          greaterThan(FogoCartography.widthPx(FogoRoadClass.primary, z)),
        );
        expect(
          FogoCartography.widthPx(FogoRoadClass.primary, z),
          greaterThan(FogoCartography.widthPx(FogoRoadClass.secondary, z)),
        );
        expect(
          FogoCartography.widthPx(FogoRoadClass.secondary, z),
          greaterThan(FogoCartography.widthPx(FogoRoadClass.tertiary, z)),
        );
        expect(
          FogoCartography.widthPx(FogoRoadClass.tertiary, z),
          greaterThan(FogoCartography.widthPx(FogoRoadClass.residential, z)),
        );
      }
    });

    test('zoom buckets quantize to quarter-zoom steps', () {
      expect(FogoCartography.zoomBucket(11.0), 11.0);
      expect(FogoCartography.zoomBucket(15.9), 16.0);
      expect(FogoCartography.zoomBucket(15.98), 16.0);
      expect(FogoCartography.zoomBucket(16.3), 16.25);
    });

    test('casing pads grow with the street width', () {
      expect(
        FogoCartography.casingPad(12),
        greaterThan(FogoCartography.casingPad(3)),
      );
      expect(FogoCartography.casingPad(2), greaterThanOrEqualTo(0.8));
      expect(FogoCartography.casingPad(40), lessThanOrEqualTo(2.4));
    });
  });

  group('pan-stable road buffers', () {
    test('surface cache reuses buffers across pan within a zoom bucket', () {
      final FogoRoadSurfaceCache cache = FogoRoadSurfaceCache();
      final FogoProjectionCache projections = FogoProjectionCache();
      final FogoMapRoad road = FogoMapRoad(
        roadClass: FogoRoadClass.primary,
        name: 'test',
        ref: null,
        oneway: false,
        bridge: false,
        tunnel: false,
        coordinates: [0, -0.001, 0, 0.001],
        bbox: [0, -0.001, 0, 0.001],
      );
      final FogoCameraTransform near = FogoCameraTransform(
        const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 15.9),
        const Size(400, 300),
      );
      final FogoRoadSurface first = cache.fillSurface(
        road,
        4,
        near,
        projections,
      );
      final FogoCameraTransform panned = FogoCameraTransform(
        const FogoCameraState(
          center: FogoCoordinate(0.0005, 0.0005),
          zoom: 15.98,
        ),
        const Size(400, 300),
      );
      final FogoRoadSurface second = cache.fillSurface(
        road,
        4,
        panned,
        projections,
      );
      expect(
        identical(first, second),
        isTrue,
        reason: 'pan within the bucket must reuse the buffer',
      );
      final FogoCameraTransform zoomed = FogoCameraTransform(
        const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 16.3),
        const Size(400, 300),
      );
      final FogoRoadSurface third = cache.fillSurface(
        road,
        4,
        zoomed,
        projections,
      );
      expect(
        identical(first, third),
        isFalse,
        reason: 'crossing the bucket rebuilds the buffer',
      );
    });
  });

  group('place label generalization', () {
    FogoMapLabel label(FogoLabelKind kind, String text) => FogoMapLabel(
      kind: kind,
      coordinate: const FogoCoordinate(0, 0),
      text: text,
    );

    test('kind ranges and the priority budget hold', () {
      final List<FogoMapLabel> labels = [
        label(FogoLabelKind.city, 'CityA'),
        label(FogoLabelKind.city, 'CityB'),
        for (int i = 0; i < 20; i++) label(FogoLabelKind.town, 'T$i'),
        for (int i = 0; i < 20; i++) label(FogoLabelKind.village, 'V$i'),
        for (int i = 0; i < 20; i++) label(FogoLabelKind.suburb, 'S$i'),
      ];

      final List<FogoMapLabel> at9 = FogoMapPainter.selectPlaceLabels(
        labels,
        9,
      );
      expect(at9.length, lessThanOrEqualTo(8), reason: 'regional budget');
      expect(
        at9.every(
          (l) => l.kind == FogoLabelKind.city || l.kind == FogoLabelKind.town,
        ),
        isTrue,
        reason: 'villages/suburbs start later',
      );
      expect(at9.first.kind, FogoLabelKind.city, reason: 'cities first');

      final List<FogoMapLabel> at13 = FogoMapPainter.selectPlaceLabels(
        labels,
        13,
      );
      expect(at13.length, 12, reason: 'mid-zoom budget');
      expect(
        at13.take(2).every((l) => l.kind == FogoLabelKind.city),
        isTrue,
        reason: 'priority order city > town > village > suburb',
      );

      final List<FogoMapLabel> at152 = FogoMapPainter.selectPlaceLabels(
        labels,
        15.2,
      );
      expect(
        at152.every((l) => l.kind == FogoLabelKind.suburb),
        isTrue,
        reason: 'only suburbs remain past z15',
      );

      expect(FogoMapPainter.selectPlaceLabels(labels, 17), isEmpty);
      expect(
        FogoMapPainter.selectPlaceLabels(labels, 12, budget: 3).length,
        3,
        reason: 'explicit budget overrides the zoom default',
      );
    });
  });

  group('rendered generalization', () {
    test('one-way arrows keep clear of shared junction nodes', () async {
      const FogoCameraState camera = FogoCameraState(
        center: FogoCoordinate(0, 0),
        zoom: 16,
      );
      // Two one-way ways meeting at (0,0): the junction node is a shared
      // endpoint, so the exclusion band must stay arrow-free while the
      // arms still carry arrows.
      final FogoMapRoad westArm = FogoMapRoad(
        roadClass: FogoRoadClass.residential,
        name: '',
        ref: null,
        oneway: true,
        bridge: false,
        tunnel: false,
        coordinates: [0, -0.0026, 0, 0],
        bbox: [0, -0.0026, 0, 0],
      );
      final FogoMapRoad northArm = FogoMapRoad(
        roadClass: FogoRoadClass.residential,
        name: '',
        ref: null,
        oneway: true,
        bridge: false,
        tunnel: false,
        coordinates: [0, 0, 0.0026, 0],
        bbox: [0, 0, 0.0026, 0],
      );
      final Uint8List pixels = await _paint(
        camera: camera,
        style: FogoMapStyle(
          background: const Color(0xFF101010),
          roadResidential: const Color(0xFF00FF00),
          onewayArrow: const Color(0xFFFF0000),
          showAreas: false,
          showWaterLines: false,
          showRail: false,
          showBuildings: false,
          showLabels: false,
          showPois: false,
          showAttribution: false,
        ),
        data: FogoMapRenderData(roads: [westArm, northArm]),
      );
      bool isArrow(int x, int y) {
        final int i = (y * 256 + x) * 4;
        return pixels[i] > 200 && pixels[i + 1] < 80 && pixels[i + 2] < 80;
      }

      int arrowsNearJunction = 0;
      int arrowsElsewhere = 0;
      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          if (!isArrow(x, y)) continue;
          if ((Offset(x.toDouble(), y.toDouble()) - const Offset(128, 128))
                  .distance <=
              8) {
            arrowsNearJunction++;
          } else {
            arrowsElsewhere++;
          }
        }
      }
      expect(
        arrowsNearJunction,
        0,
        reason: 'junction node must stay arrow-free',
      );
      expect(arrowsElsewhere, greaterThan(0), reason: 'arms keep arrows');
    });

    test('pitched extrusions paint over the streets behind them', () async {
      const FogoCameraState camera = FogoCameraState(
        center: FogoCoordinate(0, 0),
        zoom: 16,
        pitch: 45,
      );
      final FogoCameraTransform transform = FogoCameraTransform(
        camera,
        const Size(256, 256),
      );
      final FogoMapArea building = FogoMapArea(
        kind: FogoAreaKind.water,
        coordinates: [
          -0.0002,
          -0.0002,
          -0.0002,
          0.0002,
          0.0002,
          0.0002,
          0.0002,
          -0.0002,
        ],
        bbox: [-0.0002, -0.0002, 0.0002, 0.0002],
      );
      // Street running behind the building (north of it at pitch).
      final FogoMapRoad street = FogoMapRoad(
        roadClass: FogoRoadClass.residential,
        name: '',
        ref: null,
        oneway: false,
        bridge: false,
        tunnel: false,
        coordinates: [0.0003, -0.002, 0.0003, 0.002],
        bbox: [0.0003, -0.002, 0.0003, 0.002],
      );
      final Uint8List pixels = await _paint(
        camera: camera,
        style: FogoMapStyle(
          background: const Color(0xFF101010),
          building: const Color(0xFFDDDDDD),
          roadResidential: const Color(0xFF00FF00),
          showAreas: false,
          showWaterLines: false,
          showRail: false,
          showBuildings: true,
          showLabels: false,
          showPois: false,
          showAttribution: false,
        ),
        data: FogoMapRenderData(roads: [street], buildings: [building]),
      );
      final Offset? behind = transform.project(const FogoCoordinate(0.0003, 0));
      expect(behind, isNotNull);
      final int i =
          (behind!.dy.round() * 256 + behind.dx.round().clamp(0, 255)) * 4;
      final bool greenStreet =
          pixels[i + 1] > 180 && pixels[i] < 100 && pixels[i + 2] < 100;
      expect(
        greenStreet,
        isFalse,
        reason: 'the extrusion wall must occlude the street behind it at pitch',
      );
      // Sanity: the street is visible where the building does not cover
      // it (west of the footprint).
      final Offset? visible = transform.project(
        const FogoCoordinate(0.0003, -0.0016),
      );
      expect(visible, isNotNull);
      final int j =
          (visible!.dy.round().clamp(0, 255) * 256 +
              visible.dx.round().clamp(0, 255)) *
          4;
      expect(
        pixels[j + 1] > 180 && pixels[j] < 100,
        isTrue,
        reason: 'street must render outside the occluded band',
      );
    });

    test('adjacent same-colour fills close their seams', () async {
      const FogoCameraState camera = FogoCameraState(
        center: FogoCoordinate(0, 0),
        zoom: 15,
      );
      final FogoMapArea left = FogoMapArea(
        kind: FogoAreaKind.farmland,
        coordinates: [-0.001, -0.001, 0.001, -0.001, 0.001, 0, -0.001, 0],
        bbox: [-0.001, -0.001, 0.001, 0.001],
      );
      final FogoMapArea right = FogoMapArea(
        kind: FogoAreaKind.farmland,
        coordinates: [-0.001, 0, 0.001, 0, 0.001, 0.001, -0.001, 0.001],
        bbox: [-0.001, 0, 0.001, 0.001],
      );
      final FogoMapStyle style = FogoMapStyle(
        background: const Color(0xFF101010),
        farmland: const Color(0xFF2255AA),
        showAreas: true,
        showWaterLines: false,
        showRail: false,
        showRoads: false,
        showBuildings: false,
        showLabels: false,
        showPois: false,
        showAttribution: false,
      );
      final Uint8List pixels = await _paint(
        camera: camera,
        style: style,
        data: FogoMapRenderData(areas: [left, right]),
      );
      // The shared edge projects to the centre column; with the hairline
      // seam stroke every pixel there must be fill, not background.
      for (int y = 112; y < 144; y++) {
        for (final int x in [127, 128, 129]) {
          final int i = (y * 256 + x) * 4;
          expect(
            pixels[i + 2],
            greaterThan(pixels[i] + 30),
            reason: 'seam pixel at ($x,$y) must stay fill-coloured',
          );
        }
      }
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
    manifest: testManifest(
      bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
    ),
    style: style,
    polylines: const [],
    surfaceCache: FogoRoadSurfaceCache(),
    projectionCache: FogoProjectionCache(),
  ).paint(canvas, const Size(256, 256));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(256, 256);
  final ByteData bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  image.dispose();
  picture.dispose();
  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}

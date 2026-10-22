import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';
import 'package:fogo_map_sdk/src/renderer.dart';
import 'package:fogo_map_sdk/src/road_geometry.dart';

import 'test_support.dart';

/// Measured benchmark, not a golden: pans must repaint without rebuilding
/// road buffers, while crossing a zoom bucket rebuilds (ADR-0006). Reports
/// the actual wall-clock numbers for the delivery evidence.
void main() {
  test('pan repaint reuses buffers; zoom bucket crossing rebuilds', () async {
    final List<FogoMapRoad> roads = [
      for (int i = 0; i < 40; i++)
        FogoMapRoad(
          roadClass: FogoRoadClass.residential,
          name: 'r$i',
          ref: null,
          oneway: i.isEven,
          bridge: false,
          tunnel: false,
          coordinates: [
            for (int j = 0; j < 20; j++) ...[
              -0.002 + 0.004 * i / 40,
              -0.002 + 0.004 * j / 19,
            ],
          ],
          bbox: [
            -0.002 + 0.004 * i / 40,
            -0.002,
            -0.002 + 0.004 * i / 40,
            0.002,
          ],
        ),
    ];
    final FogoMapStyle style = FogoMapStyle(
      showAreas: false,
      showWaterLines: false,
      showRail: false,
      showBuildings: false,
      showLabels: false,
      showPois: false,
      showAttribution: false,
    );
    final FogoMapManifest manifest = testManifest(
      bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
    );
    final FogoRoadSurfaceCache surfaces = FogoRoadSurfaceCache();

    Future<int> paintAt(FogoCameraState camera) async {
      final Stopwatch watch = Stopwatch()..start();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      FogoMapPainter(
        camera: camera,
        data: FogoMapRenderData(roads: roads),
        manifest: manifest,
        style: style,
        polylines: const [],
        surfaceCache: surfaces,
        projectionCache: FogoProjectionCache(),
      ).paint(canvas, const Size(512, 512));
      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
      return watch.elapsedMicroseconds;
    }

    // Warm both cache paths once.
    await paintAt(
      const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 16),
    );
    await paintAt(
      const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 16.5),
    );

    final List<int> panTimes = [];
    for (int i = 0; i < 12; i++) {
      panTimes.add(
        await paintAt(
          FogoCameraState(
            center: FogoCoordinate(0.00002 * i, 0.00002 * i),
            zoom: 16.02,
          ),
        ),
      );
    }
    final List<int> rebuildTimes = [];
    for (int i = 0; i < 12; i++) {
      rebuildTimes.add(
        await paintAt(
          FogoCameraState(
            center: const FogoCoordinate(0, 0),
            zoom: 16.02 + (i.isEven ? 0.3 : -0.29),
          ),
        ),
      );
    }

    int median(List<int> values) {
      final List<int> sorted = values..sort();
      return sorted[sorted.length ~/ 2];
    }

    final int pan = median(panTimes);
    final int rebuild = median(rebuildTimes);
    // ignore: avoid_print
    print(
      'benchmark: pan-repaint median ${pan}us; bucket-rebuild median '
      '${rebuild}us over 40 roads (12 paints each, 512x512)',
    );
    // Loose, meaningful ordering: a pan must never cost a rebuild. The
    // structural no-rebuild proof lives in cartography_test's identity test.
    expect(pan, lessThan(rebuild));
  });
}

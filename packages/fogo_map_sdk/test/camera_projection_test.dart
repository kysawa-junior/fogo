import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';

void main() {
  group('Web Mercator projection', () {
    test('round-trips equatorial, 45-degree, and regional coordinates', () {
      for (final FogoCoordinate coordinate in const [
        FogoCoordinate(0, 0),
        FogoCoordinate(45, 45),
        FogoCoordinate(-22.2172, -49.95),
      ]) {
        final FogoCoordinate actual = FogoProjection.unproject(
          FogoProjection.project(coordinate),
        );
        expect(actual.latitude, closeTo(coordinate.latitude, 1e-9));
        expect(actual.longitude, closeTo(coordinate.longitude, 1e-9));
      }
    });

    test('camera screen inverse matches at pitch and bearing combinations', () {
      const FogoCoordinate center = FogoCoordinate(0, 0);
      const FogoCoordinate point = FogoCoordinate(45, 45);
      for (final (double pitch, double bearing) in [
        (0, 0),
        (45, 0),
        (30, 90),
        (60, 315),
      ]) {
        final FogoCameraTransform transform = FogoCameraTransform(
          FogoCameraState(
            center: center,
            zoom: 4,
            pitch: pitch,
            bearing: bearing,
          ),
          const Size(800, 600),
        );
        final Offset? screen = transform.project(point);
        expect(screen, isNotNull, reason: 'pitch $pitch bearing $bearing');
        final FogoCoordinate? actual = transform.unproject(screen!);
        expect(actual, isNotNull);
        expect(actual!.latitude, closeTo(point.latitude, 1e-7));
        expect(actual.longitude, closeTo(point.longitude, 1e-7));
        // The camera center stays pinned to the viewport center at any
        // pitch and bearing.
        expect(transform.project(center), const Offset(400, 300));
      }
    });

    test('points behind the camera project to null at high pitch', () {
      final FogoCameraTransform transform = FogoCameraTransform(
        const FogoCameraState(
          center: FogoCoordinate(0, 0),
          zoom: 16,
          pitch: 60,
        ),
        const Size(800, 600),
      );
      // Due south of the camera: far behind the tilted view plane.
      expect(transform.project(const FogoCoordinate(-0.3, 0)), isNull);
      // Straight up the view axis still lands.
      expect(transform.project(const FogoCoordinate(0.05, 0)), isNotNull);
    });

    test('ground polylines clip at the near plane instead of tearing', () {
      final FogoCameraTransform transform = FogoCameraTransform(
        const FogoCameraState(
          center: FogoCoordinate(0, 0),
          zoom: 16,
          pitch: 60,
        ),
        const Size(800, 600),
      );
      final List<List<Offset>> runs = transform.projectGroundPolyline([
        transform.groundOffset(const FogoCoordinate(-0.2, 0)),
        transform.groundOffset(const FogoCoordinate(0, 0)),
        transform.groundOffset(const FogoCoordinate(0.2, 0)),
      ]);
      expect(runs, isNotEmpty);
      for (final List<Offset> run in runs) {
        expect(run.length, greaterThanOrEqualTo(2));
      }
    });

    test('heights scale with the ground at the camera latitude', () {
      final FogoCameraTransform transform = FogoCameraTransform(
        const FogoCameraState(
          center: FogoCoordinate(-22.2225, -49.8044),
          zoom: 16,
        ),
        const Size(800, 600),
      );
      expect(transform.heightToPixels(0), 0);
      expect(transform.heightToPixels(100), greaterThan(0));
      expect(
        transform.heightToPixels(200),
        closeTo(transform.heightToPixels(100) * 2, 1e-6),
      );
    });

    test('rejects invalid WGS84 and non-finite projected coordinates', () {
      expect(
        () => FogoProjection.project(const FogoCoordinate(91, 0)),
        throwsArgumentError,
      );
      expect(
        () => FogoProjection.unproject(const Offset(double.nan, 0)),
        throwsArgumentError,
      );
      expect(
        () => FogoCameraTransform(
          const FogoCameraState(
            center: FogoCoordinate(0, 0),
            zoom: 4,
            pitch: 61,
          ),
          const Size(800, 600),
        ),
        throwsArgumentError,
      );
    });
  });

  group('camera contract', () {
    test('camera values are immutable and controller validates state', () {
      const FogoCameraState original = FogoCameraState(
        center: FogoCoordinate(0, 0),
        zoom: 8,
      );
      final FogoCameraState changed = original.copyWith(
        center: const FogoCoordinate(45, 45),
      );
      expect(original.center, const FogoCoordinate(0, 0));
      expect(changed.center, const FogoCoordinate(45, 45));
      expect(changed.zoom, 8);
      expect(changed.bearing, 0);

      expect(
        () => FogoMapController(
          initialCamera: const FogoCameraState(
            center: FogoCoordinate(91, 0),
            zoom: 8,
          ),
        ),
        throwsArgumentError,
      );
      final FogoMapController controller = FogoMapController(
        initialCamera: original,
      );
      addTearDown(controller.dispose);
      expect(
        () => controller.setCamera(
          const FogoCameraState(center: FogoCoordinate(91, 0), zoom: 8),
        ),
        throwsArgumentError,
      );
      expect(
        () => controller.setCamera(
          const FogoCameraState(center: FogoCoordinate(0, 0), zoom: double.nan),
        ),
        throwsArgumentError,
      );

      // Pitch clamps to the supported range; bearing normalizes mod 360.
      controller.setPitch(30);
      expect(controller.camera.pitch, 30);
      controller.setPitch(90);
      expect(controller.camera.pitch, kFogoMaxPitchDegrees);
      controller.setBearing(370);
      expect(controller.camera.bearing, 10);
      controller.rotateBy(-20);
      expect(controller.camera.bearing, 350);

      controller.zoomBy(100);
      expect(controller.camera.zoom, controller.maxZoom);
    });

    test(
      'emits changed camera and selection events once; pitch stays transient',
      () async {
        final FogoMapController controller = FogoMapController(
          initialCamera: const FogoCameraState(
            center: FogoCoordinate(0, 0),
            zoom: 8,
          ),
        );
        addTearDown(controller.dispose);
        controller.updateViewportSize(const Size(400, 300));
        final List<FogoCameraState> cameras = [];
        final List<FogoMapSelection> selections = [];
        final StreamSubscription<FogoCameraState> cameraSub = controller
            .cameraEvents
            .listen(cameras.add);
        final StreamSubscription<FogoMapSelection> selectionSub = controller
            .selectionEvents
            .listen(selections.add);
        addTearDown(cameraSub.cancel);
        addTearDown(selectionSub.cancel);

        controller.moveTo(const FogoCoordinate(45, 45), zoom: 9);
        controller.setPitch(45);
        controller.selectAt(
          const Offset(200, 150),
          source: FogoSelectionSource.secondaryClick,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cameras, hasLength(2));
        expect(cameras.last.center, const FogoCoordinate(45, 45));
        expect(cameras.last.pitch, 45);
        expect(selections, hasLength(1));
        expect(selections.single.source, FogoSelectionSource.secondaryClick);
        expect(selections.single.screenPosition, const Offset(200, 150));
        expect(selections.single.coordinate.latitude, closeTo(45, 1e-9));
        expect(selections.single.coordinate.longitude, closeTo(45, 1e-9));
        expect(
          FogoCameraState.initial().pitch,
          0,
          reason:
              'pitch is not stored in the initial/persisted center-zoom value',
        );
      },
    );

    test('fits geographic bounds inside asymmetric padding', () {
      final FogoMapController controller = FogoMapController(
        initialCamera: const FogoCameraState(
          center: FogoCoordinate(0, 0),
          zoom: 5,
        ),
      );
      addTearDown(controller.dispose);
      controller.updateViewportSize(const Size(800, 600));
      controller.fitBounds(
        const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
        padding: const EdgeInsets.fromLTRB(100, 20, 40, 80),
      );

      final Offset sw = FogoProjection.project(const FogoCoordinate(-1, -1));
      final Offset ne = FogoProjection.project(const FogoCoordinate(1, 1));
      final FogoCoordinate projectedMidpoint = FogoProjection.unproject(
        Offset((sw.dx + ne.dx) / 2, (sw.dy + ne.dy) / 2),
      );
      final Offset? screenMidpoint = controller.transform.project(
        projectedMidpoint,
      );
      expect(screenMidpoint, isNotNull);
      expect(screenMidpoint!.dx, closeTo(430, 0.1));
      expect(screenMidpoint.dy, closeTo(270, 0.1));

      for (final FogoCoordinate corner in [
        const FogoCoordinate(-1, -1),
        const FogoCoordinate(-1, 1),
        const FogoCoordinate(1, -1),
        const FogoCoordinate(1, 1),
      ]) {
        final Offset? point = controller.transform.project(corner);
        expect(point, isNotNull);
        expect(point!.dx, greaterThanOrEqualTo(100 - 1e-6));
        expect(point.dx, lessThanOrEqualTo(760 + 1e-6));
        expect(point.dy, greaterThanOrEqualTo(20 - 1e-6));
        expect(point.dy, lessThanOrEqualTo(520 + 1e-6));
      }
    });

    test('zoom anchors keep the focal point fixed at any pitch', () {
      final FogoMapController controller = FogoMapController(
        initialCamera: const FogoCameraState(
          center: FogoCoordinate(0, 0),
          zoom: 10,
          pitch: 45,
          bearing: 30,
        ),
      );
      addTearDown(controller.dispose);
      controller.updateViewportSize(const Size(800, 600));
      const Offset focal = Offset(600, 200);
      final FogoCoordinate? anchor = controller.transform.unproject(focal);
      expect(anchor, isNotNull);
      controller.zoomBy(2, focalPoint: focal);
      final Offset? after = controller.transform.project(anchor!);
      expect(after, isNotNull);
      expect(after!.dx, closeTo(focal.dx, 0.5));
      expect(after.dy, closeTo(focal.dy, 0.5));
    });
  });
}

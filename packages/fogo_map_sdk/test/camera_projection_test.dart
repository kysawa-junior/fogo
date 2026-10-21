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

    test('camera screen inverse matches at zero and 45-degree pitch', () {
      const FogoCoordinate center = FogoCoordinate(0, 0);
      const FogoCoordinate point = FogoCoordinate(45, 45);
      for (final double pitch in [0, 45]) {
        final FogoCameraTransform transform = FogoCameraTransform(
          FogoCameraState(center: center, zoom: 4, pitch: pitch),
          const Size(800, 600),
        );
        final FogoCoordinate actual = transform.unproject(
          transform.project(point),
        );
        expect(actual.latitude, closeTo(point.latitude, 1e-8));
        expect(actual.longitude, closeTo(point.longitude, 1e-8));
        expect(transform.project(center), const Offset(400, 300));
      }
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
      expect(() => controller.setPitch(30), throwsArgumentError);
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
      final Offset screenMidpoint = controller.transform.project(
        projectedMidpoint,
      );
      expect(screenMidpoint.dx, closeTo(430, 0.1));
      expect(screenMidpoint.dy, closeTo(270, 0.1));

      for (final FogoCoordinate corner in [
        const FogoCoordinate(-1, -1),
        const FogoCoordinate(-1, 1),
        const FogoCoordinate(1, -1),
        const FogoCoordinate(1, 1),
      ]) {
        final Offset point = controller.transform.project(corner);
        expect(point.dx, greaterThanOrEqualTo(100 - 1e-6));
        expect(point.dx, lessThanOrEqualTo(760 + 1e-6));
        expect(point.dy, greaterThanOrEqualTo(20 - 1e-6));
        expect(point.dy, lessThanOrEqualTo(520 + 1e-6));
      }
    });
  });
}

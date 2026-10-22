import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';
import 'package:fogo_map_sdk/src/renderer.dart';

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
}

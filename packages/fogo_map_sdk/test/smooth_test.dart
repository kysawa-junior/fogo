import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/src/road_geometry.dart';

void main() {
  group('FogoSmooth', () {
    test('keeps shared junction endpoints exactly fixed', () {
      const List<List<Offset>> junction = [
        [Offset(0, 0), Offset(10, 0), Offset(20, 2)],
        [Offset(20, 2), Offset(30, 6), Offset(40, 12)],
      ];
      final List<List<Offset>> smoothed = [
        for (final List<Offset> way in junction) FogoSmooth.polyline(way),
      ];
      expect(smoothed[0].first, junction[0].first);
      expect(smoothed[0].last, junction[0].last);
      expect(smoothed[1].first, junction[1].first);
      expect(smoothed[1].last, junction[1].last);
      // The shared node stays identical across both ways, so the junction
      // cannot be torn open by smoothing.
      expect(smoothed[0].last, smoothed[1].first);
    });

    test('preserves sharp corners as exact vertices', () {
      final List<Offset> sharp = FogoSmooth.polyline([
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(50, 50),
      ]);
      expect(sharp, contains(const Offset(50, 0)));
      expect(sharp.first, const Offset(0, 0));
      expect(sharp.last, const Offset(50, 50));
    });

    test('resamples gentle curves into more points without wandering', () {
      final List<Offset> curve = FogoSmooth.polyline([
        const Offset(0, 0),
        const Offset(10, 2),
        const Offset(20, 6),
        const Offset(30, 12),
        const Offset(40, 20),
      ]);
      expect(curve.length, greaterThan(5));
      expect(curve.first, const Offset(0, 0));
      expect(curve.last, const Offset(40, 20));
      for (final Offset point in curve) {
        // Monotonic in x: smoothing never loops back on a gentle curve.
        expect(point.dx, inInclusiveRange(0, 40));
      }
    });

    test('returns short inputs unchanged', () {
      const List<Offset> two = [Offset(0, 0), Offset(10, 0)];
      expect(FogoSmooth.polyline(two), same(two));
      expect(FogoSmooth.polyline(const []), isEmpty);
    });
  });
}

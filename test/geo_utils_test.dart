import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fogo/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.haversineMeters', () {
    test('aproxima 111,32 m por 0.001 grau de longitude no equador', () {
      final d = GeoUtils.haversineMeters(
        const LatLng(0, 0),
        const LatLng(0, 0.001),
      );
      expect(d, closeTo(111.32, 1.5));
    });

    test('ponto idêntico tem distância zero', () {
      final d = GeoUtils.haversineMeters(
        const LatLng(-23.56, -46.65),
        const LatLng(-23.56, -46.65),
      );
      expect(d, 0);
    });
  });

  group('GeoUtils.distancePointToSegmentMeters', () {
    test('ponto sobre o segmento tem distância ~zero', () {
      final d = GeoUtils.distancePointToSegmentMeters(
        const LatLng(0, 0.0005),
        const LatLng(0, 0),
        const LatLng(0, 0.001),
      );
      expect(d, lessThan(1));
    });

    test('ponto além do fim converge para o endpoint', () {
      final d = GeoUtils.distancePointToSegmentMeters(
        const LatLng(0, 0.002),
        const LatLng(0, 0),
        const LatLng(0, 0.001),
      );
      expect(d, closeTo(111.32, 2));
    });

    test('ponto lateral ao segmento mede o desvio real', () {
      final d = GeoUtils.distancePointToSegmentMeters(
        const LatLng(0.001, 0.0005),
        const LatLng(0, 0),
        const LatLng(0, 0.001),
      );
      expect(d, closeTo(111.32, 2)); // 0.001° de latitude
    });
  });

  group('GeoUtils.distancePointToPolylineMeters', () {
    test('escolhe o segmento mais próximo', () {
      final d = GeoUtils.distancePointToPolylineMeters(
        const LatLng(0.0005, 0.0006),
        const [LatLng(0, 0), LatLng(0, 0.001), LatLng(0.001, 0.001)],
      );
      // mais próximo do segmento vertical (lng=0.001) do que do horizontal
      expect(d, closeTo(44.5, 3));
    });

    test('polilinha vazia é infinito', () {
      expect(
        GeoUtils.distancePointToPolylineMeters(const LatLng(0, 0), const []),
        double.infinity,
      );
    });
  });

  group('GeoUtils.metersPerPixel', () {
    test('zoom maior reduz metros/pixel', () {
      const c = LatLng(-23.56, -46.65);
      expect(
        GeoUtils.metersPerPixel(c, 16),
        lessThan(GeoUtils.metersPerPixel(c, 12)),
      );
    });
  });
}

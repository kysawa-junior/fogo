import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Utilidades geoespaciais puras (testáveis, sem dependência de UI).
abstract final class GeoUtils {
  /// Distância aproximada em metros entre dois pontos (haversine).
  static double haversineMeters(LatLng a, LatLng b) {
    const double r = 6371000;
    final double dLat = _rad(b.latitude - a.latitude);
    final double dLng = _rad(b.longitude - a.longitude);
    final double sinLat = math.sin(dLat / 2);
    final double sinLng = math.sin(dLng / 2);
    final double h =
        sinLat * sinLat +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            sinLng *
            sinLng;
    return 2 * r * math.asin(math.sqrt(h));
  }

  /// Distância em metros de um ponto ao segmento [a, b]
  /// (projeção equiretangular local — precisão adequada p/ trechos urbanos).
  static double distancePointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final double refLat = (a.latitude + b.latitude) / 2;
    final double mPerLat = 111320.0;
    final double mPerLng = 111320.0 * math.cos(_rad(refLat));

    final double ax = a.longitude * mPerLng, ay = a.latitude * mPerLat;
    final double bx = b.longitude * mPerLng, by = b.latitude * mPerLat;
    final double px = p.longitude * mPerLng, py = p.latitude * mPerLat;

    final double abx = bx - ax, aby = by - ay;
    final double apx = px - ax, apy = py - ay;
    final double lenSq = abx * abx + aby * aby;
    final double t = lenSq == 0
        ? 0.0
        : ((apx * abx + apy * aby) / lenSq).clamp(0.0, 1.0);
    final double cx = ax + t * abx, cy = ay + t * aby;
    final double dx = px - cx, dy = py - cy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Distância em metros de um ponto à polilinha mais próxima.
  static double distancePointToPolylineMeters(LatLng p, List<LatLng> line) {
    if (line.isEmpty) return double.infinity;
    if (line.length == 1) return haversineMeters(p, line.first);
    double min = double.infinity;
    for (int i = 0; i < line.length - 1; i++) {
      final double d = distancePointToSegmentMeters(p, line[i], line[i + 1]);
      if (d < min) min = d;
    }
    return min;
  }

  /// Metros por pixel em um dado centro/zoom (Web Mercator).
  static double metersPerPixel(LatLng center, double zoom) =>
      156543.03392 * math.cos(_rad(center.latitude)) / math.pow(2, zoom);

  static double _rad(double deg) => deg * math.pi / 180;
}

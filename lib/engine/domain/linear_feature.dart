import 'dart:math' as math;

import '../geo/geo_coordinate.dart';
import 'map_feature.dart';

/// Base para elementos lineares: geometria é a sequência ORDENADA completa
/// de coordenadas, não apenas início e fim.
abstract class LinearFeature extends MapFeature {
  const LinearFeature({
    required super.id,
    required super.tags,
    required this.points,
  });

  final GeoPolyline points;

  bool get isClosed =>
      points.length > 2 &&
      points.first.latitude == points.last.latitude &&
      points.first.longitude == points.last.longitude;

  /// Comprimento aproximado em metros (haversine acumulado).
  double get lengthMeters {
    const r = 6371000.0;
    const deg = math.pi / 180;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final sinLat = math.sin((b.latitude - a.latitude) * deg / 2);
      final sinLon = math.sin((b.longitude - a.longitude) * deg / 2);
      final h =
          sinLat * sinLat +
          math.cos(a.latitude * deg) *
              math.cos(b.latitude * deg) *
              sinLon *
              sinLon;
      total += 2 * r * math.asin(math.sqrt(h));
    }
    return total;
  }
}

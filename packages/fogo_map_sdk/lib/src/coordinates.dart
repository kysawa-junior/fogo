import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// WGS84 latitude/longitude in decimal degrees.
@immutable
class FogoCoordinate {
  const FogoCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  @override
  bool operator ==(Object other) =>
      other is FogoCoordinate &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'FogoCoordinate($latitude, $longitude)';
}

/// Geographic rectangle whose longitudes do not cross the antimeridian.
@immutable
class FogoGeoBounds {
  const FogoGeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  bool get isValid =>
      west.isFinite &&
      south.isFinite &&
      east.isFinite &&
      north.isFinite &&
      west >= -180 &&
      east <= 180 &&
      south >= -90 &&
      north <= 90 &&
      west < east &&
      south < north;

  bool contains(FogoCoordinate point) =>
      point.longitude >= west &&
      point.longitude <= east &&
      point.latitude >= south &&
      point.latitude <= north;

  bool intersects(FogoGeoBounds other) =>
      west <= other.east &&
      east >= other.west &&
      south <= other.north &&
      north >= other.south;

  @override
  bool operator ==(Object other) =>
      other is FogoGeoBounds &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north;

  @override
  int get hashCode => Object.hash(west, south, east, north);
}

/// Owned EPSG:3857 projection used for the map and all geographic overlays.
abstract final class FogoProjection {
  static const double earthRadius = 6378137;
  static const double maxLatitude = 85.05112878;
  static const double worldCircumference = 2 * math.pi * earthRadius;

  /// Returns projected Web Mercator metres as `(x, y)`.
  static Offset project(FogoCoordinate coordinate) {
    if (!coordinate.isValid) {
      throw ArgumentError.value(
        coordinate,
        'coordinate',
        'Invalid WGS84 point',
      );
    }
    final double latitude = coordinate.latitude
        .clamp(-maxLatitude, maxLatitude)
        .toDouble();
    final double latRadians = latitude * math.pi / 180;
    return Offset(
      earthRadius * coordinate.longitude * math.pi / 180,
      earthRadius * math.log(math.tan(math.pi / 4 + latRadians / 2)),
    );
  }

  /// Converts Web Mercator metres `(x, y)` back to WGS84 degrees.
  static FogoCoordinate unproject(Offset point) {
    if (!point.dx.isFinite || !point.dy.isFinite) {
      throw ArgumentError.value(
        point,
        'point',
        'Projected point must be finite',
      );
    }
    final double longitude = (point.dx / earthRadius * 180 / math.pi)
        .clamp(-180, 180)
        .toDouble();
    final double latitude =
        ((2 * math.atan(math.exp(point.dy / earthRadius)) - math.pi / 2) *
                180 /
                math.pi)
            .clamp(-maxLatitude, maxLatitude)
            .toDouble();
    return FogoCoordinate(latitude, longitude);
  }
}

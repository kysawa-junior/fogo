import 'dart:ui' show Offset;

/// Shares projected positions for identical OSM coordinates during one paint
/// frame. The source pipeline rounds coordinates to five decimal places; IDs
/// are not present in the map schema.
class RoadProjectionCache {
  final Map<(double, double), Offset> _points = {};

  Offset project(
    double lat,
    double lng,
    Offset Function(double lat, double lng) projection,
  ) => _points.putIfAbsent((lat, lng), () {
    final Offset point = projection(lat, lng);
    return Offset(_snap(point.dx), _snap(point.dy));
  });

  /// Clear once at the start of each paint; camera transforms can then change.
  void clear() => _points.clear();

  static double _snap(double value) => (value * 2).roundToDouble() / 2;
}

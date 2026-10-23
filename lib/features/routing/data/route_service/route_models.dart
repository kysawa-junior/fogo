part of 'route_service.dart';

class RoadRoute {
  const RoadRoute({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.legDistances,
  });

  /// Geometria real pela malha viária.
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<double> legDistances;
}

class RoadDistanceMatrix {
  const RoadDistanceMatrix(this.meters);

  /// meters[i][j] = distância viária entre i e j.
  final List<List<double>> meters;
}

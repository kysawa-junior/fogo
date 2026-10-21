import 'package:latlong2/latlong.dart';

/// Unidade de exibição de distâncias — modelo do Fleetbase Routing Settings
/// ("Routing Distance Unit", apenas apresentação).
enum DistanceUnit { kilometers, miles }

String formatDistance(double meters, DistanceUnit unit) => switch (unit) {
  DistanceUnit.kilometers =>
    meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '${meters.round()} m',
  DistanceUnit.miles => '${(meters / 1609.344).toStringAsFixed(1)} mi',
};

/// Parada de rota. [id] referencia o objeto de origem (ex.: equipamento),
/// permitindo seleção no mapa a partir da rota e vice-versa.
class RouteStop {
  const RouteStop({required this.id, required this.name, required this.point});

  final String id;
  final String name;
  final LatLng point;
}

/// Trecho entre duas paradas consecutivas.
class RouteLeg {
  const RouteLeg({
    required this.fromId,
    required this.toId,
    required this.distanceMeters,
  });

  final String fromId;
  final String toId;
  final double distanceMeters;
}

/// Rota otimizada: sequência final de paradas, trechos e distância total.
class OptimizedRoute {
  const OptimizedRoute({
    required this.stops,
    required this.legs,
    required this.totalDistanceMeters,
    required this.computedAt,
  });

  /// Paradas na ordem de visita.
  final List<RouteStop> stops;

  /// `stops.length - 1` trechos.
  final List<RouteLeg> legs;
  final double totalDistanceMeters;
  final DateTime computedAt;
}

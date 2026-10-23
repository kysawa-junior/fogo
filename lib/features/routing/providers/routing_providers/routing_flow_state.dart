part of 'routing_providers.dart';

/// Parada criada pelo usuário no mapa — dado operacional real.
class RouteStopDraft {
  const RouteStopDraft({
    required this.id,
    required this.label,
    required this.point,
  });

  final String id;
  final String label;
  final LatLng point;

  RouteStop toRouteStop() => RouteStop(id: id, name: label, point: point);
}

enum RoutingStatus { empty, idle, computing, ready, error }

class RoadRouteResult {
  const RoadRouteResult({
    required this.stops,
    required this.legDistances,
    required this.totalDistanceMeters,
    required this.durationSeconds,
    required this.geometry,
  });

  /// Paradas na ordem otimizada.
  final List<RouteStop> stops;
  final List<double> legDistances;
  final double totalDistanceMeters;
  final double durationSeconds;

  /// Geometria real calculada sobre a malha viária.
  final List<LatLng> geometry;
}

class RoutingFlowState {
  const RoutingFlowState({
    this.drafts = const [],
    this.status = RoutingStatus.empty,
    this.error,
    this.result,
  });

  final List<RouteStopDraft> drafts;
  final RoutingStatus status;
  final String? error;
  final RoadRouteResult? result;
}

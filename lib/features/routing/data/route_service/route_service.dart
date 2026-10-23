/// Routing service library: the contract and its exception live here; the
/// result models and the OSRM implementation live in sibling parts.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

part 'route_models.dart';
part 'osrm_route_service.dart';

/// Exceção do serviço de roteamento (rede indisponível, resposta inválida).
class RouteServiceException implements Exception {
  const RouteServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Serviço de roteamento (papel "Routing Service" no modelo Fleetbase):
/// distâncias e geometria pela rede viária REAL. A otimização de paradas
/// vive no RouteOptimizer; a renderização, na camada de mapa.
abstract class RouteService {
  Future<RoadRoute> route(List<LatLng> orderedStops);
  Future<RoadDistanceMatrix> matrix(List<LatLng> points);
}

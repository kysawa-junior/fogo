import '../../../core/utils/geo_utils.dart';
import 'routing_domain.dart';

/// Função de custo entre duas paradas (metros). No runtime usa a matriz
/// da rede viária real (OSRM); nos testes, haversine.
typedef RouteCostFn = double Function(RouteStop a, RouteStop b);

/// Custo em linha reta (haversine) — usado por testes e como referência.
double haversineCost(RouteStop a, RouteStop b) =>
    GeoUtils.haversineMeters(a.point, b.point);

/// Motor de otimização de rotas — implementação própria em Dart.
///
/// Espelha a arquitetura do Fleetbase Routing: lá o "Route Optimization
/// Engine" (OSRM trip / VROOM) apenas REORDENA paradas antes da rota ser
/// renderizada pelo "Routing Service". Aqui a mesma separação vale:
/// esta classe é um solver puro de sequenciamento sobre um custo injetado
/// (rede viária real via OSRM); a renderização vive na camada do mapa.
///
/// Algoritmo: vizinho-mais-próximo + refinamento 2-opt (caminho ABERTO;
/// a primeira parada informada é mantida como ponto de partida).
abstract final class RouteOptimizer {
  /// Ganho mínimo (metros) para aceitar uma inversão 2-opt.
  static const double _epsilon = 1.0;

  static OptimizedRoute build({
    required List<RouteStop> stops,
    RouteCostFn cost = haversineCost,
  }) {
    if (stops.length < 2) {
      throw ArgumentError('A rota requer no mínimo 2 paradas.');
    }
    final List<RouteStop> order = _nearestNeighbor(stops, cost);
    _twoOpt(order, cost);

    final List<RouteLeg> legs = [];
    double total = 0;
    for (int i = 0; i < order.length - 1; i++) {
      final double d = cost(order[i], order[i + 1]);
      legs.add(
        RouteLeg(fromId: order[i].id, toId: order[i + 1].id, distanceMeters: d),
      );
      total += d;
    }
    return OptimizedRoute(
      stops: order,
      legs: legs,
      totalDistanceMeters: total,
      computedAt: DateTime.now(),
    );
  }

  static List<RouteStop> _nearestNeighbor(
    List<RouteStop> stops,
    RouteCostFn cost,
  ) {
    final List<RouteStop> remaining = [...stops];
    final List<RouteStop> route = [remaining.removeAt(0)];
    while (remaining.isNotEmpty) {
      RouteStop best = remaining.first;
      double bestDistance = double.infinity;
      for (final RouteStop candidate in remaining) {
        final double d = cost(route.last, candidate);
        if (d < bestDistance) {
          bestDistance = d;
          best = candidate;
        }
      }
      remaining.remove(best);
      route.add(best);
    }
    return route;
  }

  /// 2-opt para caminho aberto: inverte [i..j] quando encurta o percurso.
  static void _twoOpt(List<RouteStop> route, RouteCostFn cost) {
    final int n = route.length;
    if (n < 4) return; // caminhos curtos: 2-opt não tem ganho possível
    bool improved = true;
    while (improved) {
      improved = false;
      for (int i = 1; i <= n - 2; i++) {
        for (int j = i + 1; j <= n - 1; j++) {
          final RouteStop a = route[i - 1];
          final RouteStop b = route[i];
          final RouteStop c = route[j];
          final RouteStop? d = j + 1 < n ? route[j + 1] : null;
          final double before = cost(a, b) + (d != null ? cost(c, d) : 0);
          final double after = cost(a, c) + (d != null ? cost(b, d) : 0);
          if (before - after > _epsilon) {
            final List<RouteStop> segment = route.sublist(i, j + 1);
            route.setAll(i, segment.reversed.toList());
            improved = true;
          }
        }
      }
    }
  }
}

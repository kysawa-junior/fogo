import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:fogo/core/utils/geo_utils.dart';
import 'package:fogo/features/routing/data/route_service.dart';
import 'package:fogo/features/routing/domain/route_optimizer.dart';
import 'package:fogo/features/routing/domain/routing_domain.dart';
import 'package:fogo/features/routing/providers/routing_providers.dart';

RouteStop _stop(String id, double lat, double lng) =>
    RouteStop(id: id, name: id, point: LatLng(lat, lng));

double _orderDistance(List<RouteStop> order) {
  double total = 0;
  for (int i = 0; i < order.length - 1; i++) {
    total += GeoUtils.haversineMeters(order[i].point, order[i + 1].point);
  }
  return total;
}

const _osrmRouteBody = '''
{"code":"Ok","routes":[{"distance":34500.5,"duration":2100.2,
"geometry":{"type":"LineString","coordinates":[[-49.95,-22.21],[-49.80,-22.22],[-49.66,-22.23]]},
"legs":[{"distance":18000.0,"duration":900.0},{"distance":16500.5,"duration":1200.2}]}]}
''';

const _osrmTableBody = '''
{"code":"Ok","distances":[[0.0,1500.0,9000.0],[1400.0,0.0,8000.0],[8800.0,8100.0,0.0]]}
''';

void main() {
  group('RouteOptimizer (custo injetável)', () {
    test('exige no mínimo 2 paradas', () {
      expect(
        () => RouteOptimizer.build(stops: [_stop('a', -22.56, -49.65)]),
        throwsArgumentError,
      );
    });

    test('mantém todas as paradas e preserva a partida', () {
      final stops = [
        _stop('a', -22.30, -49.95),
        _stop('b', -22.30, -49.80),
        _stop('c', -22.25, -49.95),
        _stop('d', -22.25, -49.80),
        _stop('e', -22.28, -49.87),
      ];
      final route = RouteOptimizer.build(stops: stops);
      expect(route.stops.length, 5);
      expect(route.stops.first.id, 'a');
      expect(route.stops.toSet().length, 5);
      expect(route.legs.length, 4);
    });

    test('otimização reduz drasticamente a ordem em zigue-zague', () {
      final stops = [
        _stop('a', -22.30, -49.95),
        _stop('b', -22.30, -49.80),
        _stop('c', -22.25, -49.95),
        _stop('d', -22.25, -49.80),
        _stop('e', -22.28, -49.87),
      ];
      final double naive = _orderDistance(stops);
      final route = RouteOptimizer.build(stops: stops);
      expect(route.totalDistanceMeters, lessThan(naive));
      expect(route.totalDistanceMeters, greaterThan(2000));
    });

    test('custo de rede viária (matriz) substitui a linha reta', () {
      final stops = [
        _stop('a', -22.21, -49.95),
        _stop('b', -22.22, -49.66),
        _stop('c', -22.23, -49.70),
      ];
      final matrix = {
        'a': {'a': 0.0, 'b': 34500.0, 'c': 26000.0},
        'b': {'a': 34500.0, 'b': 0.0, 'c': 9000.0},
        'c': {'a': 26000.0, 'b': 9000.0, 'c': 0.0},
      };
      final route = RouteOptimizer.build(
        stops: stops,
        cost: (x, y) => matrix[x.id]![y.id]!,
      );
      // a→c→b é o caminho de menor custo viário (35 km ≠ 28 km em linha reta)
      expect(route.stops.map((s) => s.id).toList(), ['a', 'c', 'b']);
      expect(route.totalDistanceMeters, 35000);
    });

    test('total = soma dos trechos', () {
      final stops = [
        _stop('a', -22.30, -49.95),
        _stop('b', -22.28, -49.87),
        _stop('c', -22.25, -49.80),
      ];
      final route = RouteOptimizer.build(stops: stops);
      final double sum = route.legs.fold(
        0.0,
        (acc, leg) => acc + leg.distanceMeters,
      );
      expect(route.totalDistanceMeters, closeTo(sum, 0.001));
    });
  });

  group('OsrmRouteService (parse da rede real)', () {
    test('decodifica rota: geometria, distância, trechos', () async {
      final service = OsrmRouteService(
        client: MockClient((req) async => http.Response(_osrmRouteBody, 200)),
        baseUrl: 'http://test',
      );
      final RoadRoute route = await service.route([
        const LatLng(-22.21, -49.95),
        const LatLng(-22.22, -49.66),
      ]);
      expect(route.geometry, hasLength(3));
      expect(route.geometry.first, const LatLng(-22.21, -49.95));
      expect(route.distanceMeters, 34500.5);
      expect(route.legDistances, [18000.0, 16500.5]);
    });

    test('decodifica matriz de distâncias', () async {
      final service = OsrmRouteService(
        client: MockClient((req) async => http.Response(_osrmTableBody, 200)),
        baseUrl: 'http://test',
      );
      final RoadDistanceMatrix m = await service.matrix([
        const LatLng(-22.21, -49.95),
        const LatLng(-22.22, -49.66),
        const LatLng(-22.23, -49.70),
      ]);
      expect(m.meters[0][1], 1500.0);
      expect(m.meters[2][1], 8100.0);
    });

    test('erro HTTP vira exceção explícita (nunca dado fictício)', () async {
      final service = OsrmRouteService(
        client: MockClient((req) async => http.Response('unavailable', 503)),
        baseUrl: 'http://test',
      );
      expect(
        () => service.route([
          const LatLng(-22.2, -49.9),
          const LatLng(-22.2, -49.7),
        ]),
        throwsA(isA<RouteServiceException>()),
      );
    });
  });

  group('RoutingFlowNotifier (fluxo com serviço real injetado)', () {
    RouteService fakeOk() => OsrmRouteService(
      client: MockClient((req) async {
        if (req.url.path.contains('/table/')) {
          return http.Response(_osrmTableBody, 200);
        }
        return http.Response(_osrmRouteBody, 200);
      }),
      baseUrl: 'http://test',
    );

    RouteService fakeFail() => OsrmRouteService(
      client: MockClient((req) async => throw Exception('sem rede')),
      baseUrl: 'http://test',
    );

    test('paradas reais: adicionar, remover, limpar', () {
      final container = ProviderContainer(
        overrides: [routeServiceProvider.overrideWithValue(fakeOk())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(routingFlowProvider.notifier);

      expect(container.read(routingFlowProvider).status, RoutingStatus.empty);

      notifier.addStop(const LatLng(-22.21, -49.95));
      notifier.addStop(const LatLng(-22.22, -49.66));
      expect(container.read(routingFlowProvider).drafts, hasLength(2));

      notifier.removeStop('stop-1');
      expect(container.read(routingFlowProvider).drafts, hasLength(1));

      notifier.clearAll();
      expect(container.read(routingFlowProvider).drafts, isEmpty);
    });

    test('otimização compõe matriz + rota da malha real', () async {
      final container = ProviderContainer(
        overrides: [routeServiceProvider.overrideWithValue(fakeOk())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(routingFlowProvider.notifier);
      notifier
        ..addStop(const LatLng(-22.21, -49.95))
        ..addStop(const LatLng(-22.22, -49.66))
        ..addStop(const LatLng(-22.23, -49.70));

      await notifier.optimize();
      final RoutingFlowState state = container.read(routingFlowProvider);
      expect(state.status, RoutingStatus.ready);
      expect(state.result, isNotNull);
      expect(state.result!.geometry, hasLength(3));
      expect(state.result!.totalDistanceMeters, 34500.5);
      // ordem usa o custo viário da matriz injetada (0→1→2 = 9,5 km)
      expect(state.result!.stops.map((s) => s.name).toList(), [
        'Parada 1',
        'Parada 2',
        'Parada 3',
      ]);
    });

    test(
      'serviço indisponível = erro explícito, sem fallback fictício',
      () async {
        final container = ProviderContainer(
          overrides: [routeServiceProvider.overrideWithValue(fakeFail())],
        );
        addTearDown(container.dispose);
        final notifier = container.read(routingFlowProvider.notifier);
        notifier
          ..addStop(const LatLng(-22.21, -49.95))
          ..addStop(const LatLng(-22.22, -49.66));

        await notifier.optimize();
        final RoutingFlowState state = container.read(routingFlowProvider);
        expect(state.status, RoutingStatus.error);
        expect(state.error, contains('inacessível'));
        expect(state.result, isNull);
        // paradas do usuário permanecem
        expect(state.drafts, hasLength(2));
      },
    );

    test('menos de 2 paradas: mensagem clara', () async {
      final container = ProviderContainer(
        overrides: [routeServiceProvider.overrideWithValue(fakeOk())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(routingFlowProvider.notifier);
      notifier.addStop(const LatLng(-22.21, -49.95));
      await notifier.optimize();
      expect(container.read(routingFlowProvider).status, RoutingStatus.error);
    });
  });

  group('formatDistance', () {
    test('quilômetros e metros', () {
      expect(formatDistance(850, DistanceUnit.kilometers), '850 m');
      expect(formatDistance(1500, DistanceUnit.kilometers), '1.5 km');
    });

    test('milhas', () {
      expect(formatDistance(1609.344, DistanceUnit.miles), '1.0 mi');
    });
  });
}

/// Routing flow library: the flow state models live in
/// `routing_flow_state.dart`; the provider and its notifier live here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/route_service/route_service.dart';
import '../../domain/route_optimizer.dart';
import '../../domain/routing_domain.dart';

part 'routing_flow_state.dart';

/// Serviço de roteamento viário (rede real). Override aponta para OSRM
/// próprio via OSRM_BASE_URL (dart-define).
final routeServiceProvider = Provider<RouteService>(
  (ref) => OsrmRouteService(),
);

/// Fluxo de roteamento: paradas reais → matriz viária real (OSRM) →
/// sequenciamento próprio (NN + 2-opt) → geometria real sobre o mapa.
/// Sem fallback fictício: falha de serviço = estado de erro explícito.
final routingFlowProvider =
    NotifierProvider<RoutingFlowNotifier, RoutingFlowState>(
      RoutingFlowNotifier.new,
    );

class RoutingFlowNotifier extends Notifier<RoutingFlowState> {
  int _seq = 0;

  @override
  RoutingFlowState build() => const RoutingFlowState();

  void addStop(LatLng point) {
    _seq++;
    final List<RouteStopDraft> drafts = [
      ...state.drafts,
      RouteStopDraft(id: 'stop-$_seq', label: 'Parada $_seq', point: point),
    ];
    state = RoutingFlowState(drafts: drafts, status: RoutingStatus.idle);
  }

  void removeStop(String id) {
    final List<RouteStopDraft> drafts = [
      for (final RouteStopDraft draft in state.drafts)
        if (draft.id != id) draft,
    ];
    state = RoutingFlowState(
      drafts: drafts,
      status: drafts.isEmpty ? RoutingStatus.empty : RoutingStatus.idle,
    );
  }

  void clearAll() => state = const RoutingFlowState();

  Future<void> optimize() async {
    if (state.drafts.length < 2) {
      state = RoutingFlowState(
        drafts: state.drafts,
        status: RoutingStatus.error,
        error: 'Adicione ao menos 2 paradas (botão direito no mapa) antes de otimizar.',
      );
      return;
    }
    state = RoutingFlowState(
      drafts: state.drafts,
      status: RoutingStatus.computing,
    );
    try {
      final RouteService service = ref.read(routeServiceProvider);
      final List<RouteStop> stops = [
        for (final RouteStopDraft draft in state.drafts) draft.toRouteStop(),
      ];

      // 1. Matriz de distâncias pela rede viária real.
      final RoadDistanceMatrix matrix = await service.matrix([
        for (final s in stops) s.point,
      ]);
      final Map<String, int> index = {
        for (int i = 0; i < stops.length; i++) stops[i].id: i,
      };
      final OptimizedRoute ordered = RouteOptimizer.build(
        stops: stops,
        cost: (a, b) => matrix.meters[index[a.id]!][index[b.id]!],
      );

      // 2. Geometria + trechos reais na ordem otimizada.
      final RoadRoute road = await service.route([
        for (final s in ordered.stops) s.point,
      ]);

      state = RoutingFlowState(
        drafts: state.drafts,
        status: RoutingStatus.ready,
        result: RoadRouteResult(
          stops: ordered.stops,
          legDistances: road.legDistances,
          totalDistanceMeters: road.distanceMeters,
          durationSeconds: road.durationSeconds,
          geometry: road.geometry,
        ),
      );
    } on RouteServiceException catch (e) {
      state = RoutingFlowState(
        drafts: state.drafts,
        status: RoutingStatus.error,
        error: e.message,
      );
    }
  }
}

part of 'route_panel.dart';

/// Result area of the route panel, one branch per routing status.
class _RouteResultArea extends StatelessWidget {
  const _RouteResultArea({required this.flow, required this.onSelectStop});

  final RoutingFlowState flow;
  final ValueChanged<RouteStop> onSelectStop;

  @override
  Widget build(BuildContext context) {
    switch (flow.status) {
      case RoutingStatus.computing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: FogoSpacing.md),
          child: Row(
            children: [
              SizedBox(width: 14, height: 14, child: FogoSpinner()),
              SizedBox(width: FogoSpacing.sm),
              Text('Calculando pela malha viária…', style: FogoText.caption),
            ],
          ),
        );
      case RoutingStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: FogoSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.circle_alert,
                size: 14,
                color: FogoColors.statusCritical,
              ),
              const SizedBox(width: FogoSpacing.sm),
              Expanded(
                child: Text(
                  flow.error ?? 'Falha no serviço de roteamento.',
                  style: FogoText.caption.copyWith(
                    color: FogoColors.statusCritical,
                  ),
                ),
              ),
            ],
          ),
        );
      case RoutingStatus.ready:
        final RoadRouteResult result = flow.result!;
        return Padding(
          padding: const EdgeInsets.only(top: FogoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rota otimizada · ${(result.totalDistanceMeters / 1000).toStringAsFixed(1)} km · '
                '${(result.durationSeconds / 60).round()} min',
                style: FogoText.subtitle,
              ),
              const SizedBox(height: FogoSpacing.sm),
              for (int i = 0; i < result.stops.length; i++)
                _ResultRow(
                  order: i + 1,
                  stop: result.stops[i],
                  legToNext: i < result.legDistances.length
                      ? result.legDistances[i]
                      : null,
                  onSelect: () => onSelectStop(result.stops[i]),
                ),
            ],
          ),
        );
      case RoutingStatus.empty:
      case RoutingStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

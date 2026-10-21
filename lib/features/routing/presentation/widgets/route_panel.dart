import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../core/design_system/widgets/fogo_empty_state.dart';
import '../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/design_system/widgets/fogo_spinner.dart';
import '../../../../core/theme/fogo_typography.dart';
import '../../../map/presentation/widgets/panel_header.dart';
import '../../domain/routing_domain.dart';
import '../../providers/routing_providers.dart';

/// Painel de rotas: paradas reais do usuário, otimização sobre a malha
/// viária (OSRM + solver próprio) e resultados com distâncias reais.
class RoutePanel extends ConsumerWidget {
  const RoutePanel({
    super.key,
    required this.onSelectStop,
    required this.onClose,
  });

  final ValueChanged<RouteStop> onSelectStop;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RoutingFlowState flow = ref.watch(routingFlowProvider);

    return FogoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            icon: LucideIcons.route,
            title: 'Rotas e otimização',
            subtitle: 'malha viária real (OSRM)',
            onClose: onClose,
          ),
          const SizedBox(height: FogoSpacing.md),

          // Paradas do usuário
          if (flow.drafts.isEmpty)
            FogoEmptyState(
              icon: LucideIcons.map_pin,
              title: 'Nenhuma parada',
              message:
                  'Clique com o botão direito no mapa (ou toque longo) para '
                  'adicionar paradas georreferenciadas reais.',
              compact: true,
            )
          else
            for (int i = 0; i < flow.drafts.length; i++)
              _DraftRow(
                index: i + 1,
                draft: flow.drafts[i],
                onRemove: () => ref
                    .read(routingFlowProvider.notifier)
                    .removeStop(flow.drafts[i].id),
              ),

          if (flow.drafts.isNotEmpty) ...[
            const SizedBox(height: FogoSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FogoButton(
                    label: 'Otimizar rota',
                    icon: LucideIcons.sparkles,
                    variant: FogoButtonVariant.primary,
                    expanded: true,
                    onTap: flow.drafts.length >= 2
                        ? () =>
                              ref.read(routingFlowProvider.notifier).optimize()
                        : null,
                  ),
                ),
                const SizedBox(width: FogoSpacing.sm),
                FogoButton(
                  label: 'Limpar',
                  variant: FogoButtonVariant.danger,
                  onTap: () =>
                      ref.read(routingFlowProvider.notifier).clearAll(),
                ),
              ],
            ),
          ],

          _buildResultArea(ref, flow),

          const SizedBox(height: FogoSpacing.md),
          Text(
            'Roteamento real sobre o OSM (© OpenStreetMap contributors). '
            'Servidor OSRM de demonstração — defina OSRM_BASE_URL para produção.',
            style: FogoText.micro,
          ),
        ],
      ),
    );
  }

  Widget _buildResultArea(WidgetRef ref, RoutingFlowState flow) {
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

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final RouteStopDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FogoSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FogoColors.accentSoft,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FogoColors.accent),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w700,
                color: FogoColors.accent,
              ),
            ),
          ),
          const SizedBox(width: FogoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.label,
                  style: FogoText.body.copyWith(fontSize: 12.5),
                ),
                Text(
                  '${draft.point.latitude.toStringAsFixed(5)}, '
                  '${draft.point.longitude.toStringAsFixed(5)}',
                  style: FogoText.mono,
                ),
              ],
            ),
          ),
          FogoIconButton(
            icon: LucideIcons.x,
            size: 22,
            iconSize: 12,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.order,
    required this.stop,
    required this.legToNext,
    required this.onSelect,
  });

  final int order;
  final RouteStop stop;
  final double? legToNext;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.only(bottom: FogoSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FogoColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$order',
                style: const TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: FogoSpacing.sm),
            Expanded(
              child: Text(
                stop.name,
                style: FogoText.body.copyWith(fontSize: 12.5),
              ),
            ),
            if (legToNext != null)
              Text(
                '${(legToNext! / 1000).toStringAsFixed(1)} km',
                style: FogoText.mono,
              ),
          ],
        ),
      ),
    );
  }
}

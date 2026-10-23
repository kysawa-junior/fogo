/// Route panel library: the panel, its two row widgets and the result area
/// live in separate files of the same library.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../../core/design_system/widgets/fogo_empty_state.dart';
import '../../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/design_system/widgets/fogo_spinner.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../../map/presentation/widgets/panel_header.dart';
import '../../../domain/routing_domain.dart';
import '../../../providers/routing_providers/routing_providers.dart';

part 'draft_row.dart';
part 'result_row.dart';
part 'route_result_area.dart';

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

          _RouteResultArea(flow: flow, onSelectStop: onSelectStop),

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
}

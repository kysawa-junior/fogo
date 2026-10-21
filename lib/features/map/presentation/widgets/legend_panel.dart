import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart'
    show FogoMapDataPhase, FogoMapDataStatus;

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_map_style.dart' as map_style;
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/theme/fogo_typography.dart';
import '../../../routing/providers/routing_providers.dart';

/// Legenda da base cartográfica real + estado do roteamento.
class LegendPanel extends ConsumerWidget {
  const LegendPanel({super.key, required this.status});

  final FogoMapDataStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool routeOn = ref.watch(routingFlowProvider).result != null;
    final String statusLabel = switch (status.phase) {
      FogoMapDataPhase.loading => 'Base OSM local carregando',
      FogoMapDataPhase.outsideCoverage => 'Fora da cobertura OSM',
      FogoMapDataPhase.error => 'Erro ao carregar base OSM',
      FogoMapDataPhase.ready || FogoMapDataPhase.empty =>
        status.hasErrors ? 'Base OSM local · parcial' : 'Base OSM local',
    };

    return FogoPanel(
      elevated: false,
      bordered: false,
      width: 230,
      padding: const EdgeInsets.all(FogoSpacing.md),
      maxHeightFactor: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Base cartográfica', style: FogoText.subtitle),
          const SizedBox(height: FogoSpacing.xs),
          Text(statusLabel, style: FogoText.micro),
          const SizedBox(height: FogoSpacing.sm),
          _row(map_style.FogoMapStyle.roadPrimary, 'Vias (OSM)', round: true),
          _row(map_style.FogoMapStyle.water, 'Água', round: true),
          _row(map_style.FogoMapStyle.railTie, 'Ferrovias', round: true),
          _row(map_style.FogoMapStyle.green, 'Áreas verdes', round: true),
          _row(map_style.FogoMapStyle.building, 'Edificações', round: false),
          if (routeOn) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 14, height: 2, color: FogoColors.accent),
                const SizedBox(width: FogoSpacing.sm),
                Text('Rota otimizada', style: FogoText.caption),
              ],
            ),
          ],
          const SizedBox(height: FogoSpacing.sm),
          Text(
            status.manifest?.attribution.isNotEmpty != true
                ? '© OpenStreetMap contributors'
                : status.manifest!.attribution,
            style: FogoText.micro,
          ),
          Text('Base: Marília-SP · Garça-SP · corredor', style: FogoText.micro),
        ],
      ),
    );
  }

  static Widget _row(Color color, String label, {required bool round}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: round ? null : BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: FogoSpacing.sm),
            Expanded(child: Text(label, style: FogoText.caption)),
          ],
        ),
      );
}

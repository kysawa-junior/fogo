import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/theme/fogo_typography.dart';
import '../../../map/presentation/widgets/panel_header.dart';
import '../../domain/road.dart';
import '../road_labels.dart';

/// Painel contextual de uma via selecionada.
class RoadContextPanel extends StatelessWidget {
  const RoadContextPanel({
    super.key,
    required this.road,
    required this.onCenter,
    required this.onProposeChange,
    required this.onClose,
  });

  final Road road;
  final VoidCallback onCenter;
  final VoidCallback onProposeChange;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return FogoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            icon: _typeIcon(road.type),
            title: road.name,
            subtitle: road.id,
            onClose: onClose,
          ),
          const SizedBox(height: FogoSpacing.sm),
          Row(
            children: [
              FogoChip(
                label: operationalStatusLabel(road.status),
                color: operationalStatusColor(road.status),
              ),
              const SizedBox(width: FogoSpacing.sm),
              const FogoDemoTag(),
            ],
          ),
          const SizedBox(height: FogoSpacing.md),
          _InfoRow(label: 'Tipo', value: roadTypeLabel(road.type)),
          _InfoRow(label: 'Sentido', value: flowDirectionLabel(road.direction)),
          _InfoRow(label: 'Faixas', value: '${road.lanes}'),
          _InfoRow(label: 'Limite', value: '${road.speedLimitKmh} km/h'),
          _InfoRow(label: 'Atualizada', value: _formatDate(road.updatedAt)),
          const SizedBox(height: FogoSpacing.md),
          Text('Permissões', style: FogoText.caption),
          const SizedBox(height: FogoSpacing.xs),
          Wrap(
            spacing: FogoSpacing.xs,
            runSpacing: FogoSpacing.xs,
            children: [
              if (road.permissions.isEmpty)
                Text(
                  'Restrita — sem classes permitidas registradas',
                  style: FogoText.caption,
                )
              else
                for (final permission in road.permissions)
                  FogoChip(
                    label: permissionLabel(permission),
                    color: FogoColors.info,
                    showDot: false,
                  ),
            ],
          ),
          const SizedBox(height: FogoSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FogoButton(
                  label: 'Propor alteração',
                  icon: LucideIcons.pencil,
                  variant: FogoButtonVariant.primary,
                  expanded: true,
                  onTap: onProposeChange,
                ),
              ),
              const SizedBox(width: FogoSpacing.sm),
              FogoButton(
                label: 'Centralizar',
                icon: LucideIcons.locate_fixed,
                onTap: onCenter,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _typeIcon(RoadType type) => switch (type) {
    RoadType.avenue || RoadType.arterial => LucideIcons.milestone,
    RoadType.street => LucideIcons.map,
    RoadType.corridor => LucideIcons.footprints,
  };

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FogoSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: FogoText.caption)),
          Expanded(child: Text(value, style: FogoText.body)),
        ],
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/theme/fogo_typography.dart';
import '../../../map/presentation/widgets/panel_header.dart';
import '../../domain/equipment.dart';
import '../equipment_labels.dart';

/// Painel contextual de um equipamento selecionado.
class EquipmentContextPanel extends StatelessWidget {
  const EquipmentContextPanel({
    super.key,
    required this.equipment,
    required this.associatedRoadName,
    required this.onCenter,
    required this.onOpenInventory,
    required this.onClose,
  });

  final Equipment equipment;
  final String? associatedRoadName;
  final VoidCallback onCenter;
  final VoidCallback onOpenInventory;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final LatLng loc = equipment.location;
    return FogoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            icon: equipmentCategoryIcon(equipment.category),
            title: equipment.name,
            subtitle: equipment.id,
            onClose: onClose,
          ),
          const SizedBox(height: FogoSpacing.sm),
          Row(
            children: [
              FogoChip(
                label: equipmentStatusLabel(equipment.status),
                color: equipmentStatusColor(equipment.status),
              ),
              const SizedBox(width: FogoSpacing.sm),
              const FogoDemoTag(),
            ],
          ),
          const SizedBox(height: FogoSpacing.md),
          _row('Categoria', equipmentCategoryLabel(equipment.category)),
          _row(
            'Localização',
            '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
          ),
          _row(
            'Última atualização',
            equipment.lastSeenAt == null
                ? 'Desconhecida'
                : _formatDate(equipment.lastSeenAt!),
          ),
          _row('Via associada', associatedRoadName ?? 'Sem associação'),
          if (equipment.telemetry.isNotEmpty) ...[
            const SizedBox(height: FogoSpacing.md),
            Text('Telemetria (demo)', style: FogoText.caption),
            const SizedBox(height: FogoSpacing.xs),
            for (final entry in equipment.telemetry.entries)
              _row(entry.key, entry.value),
          ],
          const SizedBox(height: FogoSpacing.md),
          Text('Alertas associados', style: FogoText.caption),
          const SizedBox(height: FogoSpacing.xs),
          Text(
            'Nenhum alerta — fonte de alertas não integrada nesta etapa.',
            style: FogoText.caption,
          ),
          const SizedBox(height: FogoSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FogoButton(
                  label: 'Centralizar',
                  icon: LucideIcons.locate_fixed,
                  expanded: true,
                  onTap: onCenter,
                ),
              ),
              const SizedBox(width: FogoSpacing.sm),
              FogoButton(
                label: 'Inventário',
                icon: LucideIcons.box,
                onTap: onOpenInventory,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: FogoSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: FogoText.caption)),
        Expanded(child: Text(value, style: FogoText.body)),
      ],
    ),
  );
}

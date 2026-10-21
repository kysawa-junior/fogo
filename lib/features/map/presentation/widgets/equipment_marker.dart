import 'package:flutter/widgets.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../inventory/domain/equipment.dart';
import '../../../inventory/presentation/equipment_labels.dart';

/// Marcador de equipamento sobre o mapa (selecionável).
class EquipmentMarker extends StatelessWidget {
  const EquipmentMarker({
    super.key,
    required this.equipment,
    required this.selected,
    required this.onTap,
  });

  final Equipment equipment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color status = equipmentStatusColor(equipment.status);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? FogoColors.accentSoft : FogoColors.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? FogoColors.accent : status,
              width: selected ? 2.4 : 1.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(
            equipmentCategoryIcon(equipment.category),
            size: 13,
            color: selected ? FogoColors.accent : status,
          ),
        ),
      ),
    );
  }
}

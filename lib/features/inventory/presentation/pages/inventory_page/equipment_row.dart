part of 'inventory_page.dart';

/// One equipment entry: category icon, name, location and status chip.
class _EquipmentRow extends StatefulWidget {
  const _EquipmentRow({required this.equipment, required this.onTap});

  final Equipment equipment;
  final VoidCallback onTap;

  @override
  State<_EquipmentRow> createState() => _EquipmentRowState();
}

class _EquipmentRowState extends State<_EquipmentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Equipment equipment = widget.equipment;
    final Color status = equipmentStatusColor(equipment.status);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(FogoSpacing.md),
          decoration: BoxDecoration(
            color: _hover ? FogoColors.surfaceHover : FogoColors.surfaceRaised,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
            border: Border.all(
              color: _hover ? FogoColors.borderStrong : FogoColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: status.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
                ),
                child: Icon(
                  equipmentCategoryIcon(equipment.category),
                  size: 15,
                  color: status,
                ),
              ),
              const SizedBox(width: FogoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(equipment.name, style: FogoText.subtitle),
                    Text(
                      '${equipment.id} · ${equipmentCategoryLabel(equipment.category)} · '
                      '${equipment.location.latitude.toStringAsFixed(4)}, '
                      '${equipment.location.longitude.toStringAsFixed(4)}',
                      style: FogoText.mono,
                    ),
                  ],
                ),
              ),
              FogoChip(
                label: equipmentStatusLabel(equipment.status),
                color: status,
              ),
              const SizedBox(width: FogoSpacing.sm),
              Icon(
                LucideIcons.chevron_down,
                size: 14,
                color: FogoColors.textDisabled,
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}

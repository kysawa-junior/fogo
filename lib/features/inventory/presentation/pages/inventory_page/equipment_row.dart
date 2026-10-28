part of 'inventory_page.dart';

/// Card de equipamento: tile de categoria, nome, categoria·id, coords
/// e estado. Largura fixa — a página distribui em grade (Wrap).
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
          width: _cardWidth,
          constraints: const BoxConstraints(minHeight: _cardMinHeight),
          padding: const EdgeInsets.all(FogoSpacing.md),
          decoration: BoxDecoration(
            color: _hover ? FogoColors.surfaceHover : FogoColors.surfaceRaised,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusMd),
            border: Border.all(
              color: _hover ? FogoColors.borderStrong : FogoColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: status.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
                  border: Border.all(color: status.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  equipmentCategoryIcon(equipment.category),
                  size: 17,
                  color: status,
                ),
              ),
              const SizedBox(width: FogoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.name,
                      style: FogoText.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${equipmentCategoryLabel(equipment.category)} · '
                      '${equipment.id}',
                      style: FogoText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
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
                LucideIcons.chevron_right,
                size: 14,
                color: _hover
                    ? FogoColors.textSecondary
                    : FogoColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

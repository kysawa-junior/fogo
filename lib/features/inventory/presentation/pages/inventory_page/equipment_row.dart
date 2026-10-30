part of 'inventory_page.dart';

/// Card compacto de equipamento: tile de categoria, nome, categoria·id e
/// badge de estado. Todo o resto (coordenadas, última leitura, via e
/// telemetria) fica no modal de detalhes — o card existe para varredura
/// rápida de catálogos grandes.
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
      child: Semantics(
        button: true,
        label: 'Abrir detalhes de ${equipment.name}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: _cardWidth,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              // Card sem borda: o fundo escuro recorta do card flutuante.
              color: _hover ? FogoColors.surface : FogoColors.bg,
              borderRadius: BorderRadius.circular(FogoSpacing.radiusLg),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: status.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(FogoSpacing.radiusMd),
                  ),
                  child: Icon(
                    equipmentCategoryIcon(equipment.category),
                    size: 18,
                    color: status,
                  ),
                ),
                const SizedBox(width: FogoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        equipment.name,
                        style: FogoText.subtitle.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${equipmentCategoryLabel(equipment.category)} · '
                        '${equipment.id}',
                        style: FogoText.caption.copyWith(
                          fontSize: 11.5,
                          color: FogoColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FogoSpacing.sm),
                _StatusBadge(
                  label: equipmentStatusLabel(equipment.status),
                  color: status,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

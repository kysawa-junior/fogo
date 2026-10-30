part of 'inventory_page.dart';

/// Faixa de status do inventário: contagem por estado do equipamento.
/// Sem caixas — o card flutuante é o fundo; os números é que carregam a
/// leitura rápida (base-design.pen "Resumo de Métricas").
class _InventoryStats extends StatelessWidget {
  const _InventoryStats({required this.equipments});

  final List<Equipment> equipments;

  @override
  Widget build(BuildContext context) {
    int byStatus(EquipmentStatus status) =>
        equipments.where((Equipment item) => item.status == status).length;
    final List<(String, int, Color)> stats = <(String, int, Color)>[
      ('Equipamentos', equipments.length, FogoColors.textPrimary),
      ('Disponíveis', byStatus(EquipmentStatus.online), FogoColors.activeSurface),
      ('Atenção', byStatus(EquipmentStatus.attention), FogoColors.statusAttention),
      (
        'Indisponíveis',
        byStatus(EquipmentStatus.offline),
        FogoColors.statusCritical,
      ),
      ('Manutenção', byStatus(EquipmentStatus.maintenance), FogoColors.info),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: FogoColors.bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: FogoSpacing.md),
            Expanded(
              child: _Stat(
                label: stats[i].$1,
                value: stats[i].$2,
                color: stats[i].$3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Número + rótulo de um estado, com barra de acento na cor do estado.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: FogoText.title.copyWith(
                  fontSize: 26,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label.toUpperCase(),
                style: FogoText.micro.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filtro por estado do equipamento (seleção única).
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final EquipmentStatus? selected;
  final ValueChanged<EquipmentStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('ESTADO', style: FogoText.micro),
        const SizedBox(width: FogoSpacing.md),
        Expanded(
          child: Wrap(
            spacing: FogoSpacing.sm,
            runSpacing: FogoSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterChip(
                label: 'Todos',
                selected: selected == null,
                onTap: () => onSelected(null),
              ),
              for (final EquipmentStatus status in EquipmentStatus.values)
                _FilterChip(
                  label: equipmentStatusLabel(status),
                  selected: selected == status,
                  onTap: () => onSelected(status),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip de filtro — seleção em ciano (accent do base-design.pen), sem borda.
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: FogoMotion.fast,
          curve: FogoMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? FogoColors.activeSurface : FogoColors.overlayFaint,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            widget.label,
            style: FogoText.caption.copyWith(
              color: selected
                  ? FogoColors.onActiveSurface
                  : (_hover
                        ? FogoColors.textPrimary
                        : FogoColors.textSecondary),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

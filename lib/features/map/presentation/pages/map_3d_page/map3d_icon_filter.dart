part of 'map_3d_page.dart';

/// Filtro de ícones do Modo Normal: chips por tipo — marcado = visível
/// no mapa, apagado = oculto. Afeta SOMENTE o Modo Normal (o modo
/// Cidade Preditiva oculta todos os ícones de qualquer forma).
/// Mesma linguagem do Card Base Cartográfica: FogoGlass surfaceCard,
/// 240 px, header ícone + título.
class _IconFilterBar extends ConsumerWidget {
  const _IconFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mapIconFilterProvider);
    return FogoGlass(
      radius: FogoSpacing.radiusLg,
      fill: FogoColors.surfaceCard,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.funnel,
                  size: 14,
                  color: FogoColors.textSecondary,
                ),
                const SizedBox(width: FogoSpacing.sm),
                const Expanded(
                  child: Text(
                    'Filtros de Ícones',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FogoColors.textPrimary,
                    ),
                  ),
                ),
                // Restaura todos os tipos (comportamento original).
                FogoIconButton(
                  icon: LucideIcons.rotate_ccw,
                  size: 22,
                  iconSize: 13,
                  onTap: () => ref.read(mapIconFilterProvider.notifier).all(),
                ),
              ],
            ),
            const SizedBox(height: FogoSpacing.sm),
            Wrap(
              spacing: FogoSpacing.xs,
              runSpacing: FogoSpacing.xs,
              children: [
                for (final kind in MapIconKind.values)
                  GestureDetector(
                    onTap: () =>
                        ref.read(mapIconFilterProvider.notifier).toggle(kind),
                    child: FogoChip(
                      label: kind.label,
                      color: selected.contains(kind)
                          ? Map2DRenderer.iconKindColor(kind)
                          : FogoColors.textDisabled,
                      outlined: !selected.contains(kind),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

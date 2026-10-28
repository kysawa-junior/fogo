part of 'map_3d_page.dart';

/// Painel de seleção: propriedades da entidade cartográfica escolhida no
/// viewport (rua, edifício, travessia, semáforo ou área).
class _SelectionPanel extends ConsumerWidget {
  const _SelectionPanel({required this.details, required this.onFrame});

  final EntityDetails? details;

  /// Enquadra a entidade selecionada (botão de foco do painel).
  final VoidCallback onFrame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = details;
    if (data == null) return const SizedBox.shrink();
    return FogoPanel(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(data.title, style: FogoText.title)),
              FogoIconButton(icon: LucideIcons.locate_fixed, onTap: onFrame),
              const SizedBox(width: FogoSpacing.xs),
              FogoIconButton(
                icon: LucideIcons.x,
                onTap: () =>
                    ref.read(mapEngineProvider.notifier).clearSelection(),
              ),
            ],
          ),
          Text(
            data.subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: FogoColors.textSecondary,
            ),
          ),
          const SizedBox(height: FogoSpacing.md),
          for (final (label, value) in data.properties) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: FogoColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FogoSpacing.xs),
          ],
        ],
      ),
    );
  }
}

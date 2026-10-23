part of 'route_panel.dart';

/// One user-created stop with its real coordinates and remove action.
class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final RouteStopDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FogoSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FogoColors.accentSoft,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FogoColors.accent),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w700,
                color: FogoColors.accent,
              ),
            ),
          ),
          const SizedBox(width: FogoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.label,
                  style: FogoText.body.copyWith(fontSize: 12.5),
                ),
                Text(
                  '${draft.point.latitude.toStringAsFixed(5)}, '
                  '${draft.point.longitude.toStringAsFixed(5)}',
                  style: FogoText.mono,
                ),
              ],
            ),
          ),
          FogoIconButton(
            icon: LucideIcons.x,
            size: 22,
            iconSize: 12,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

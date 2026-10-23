part of 'route_panel.dart';

/// One stop of the optimized route with its leg distance.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.order,
    required this.stop,
    required this.legToNext,
    required this.onSelect,
  });

  final int order;
  final RouteStop stop;
  final double? legToNext;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.only(bottom: FogoSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FogoColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$order',
                style: const TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: FogoSpacing.sm),
            Expanded(
              child: Text(
                stop.name,
                style: FogoText.body.copyWith(fontSize: 12.5),
              ),
            ),
            if (legToNext != null)
              Text(
                '${(legToNext! / 1000).toStringAsFixed(1)} km',
                style: FogoText.mono,
              ),
          ],
        ),
      ),
    );
  }
}

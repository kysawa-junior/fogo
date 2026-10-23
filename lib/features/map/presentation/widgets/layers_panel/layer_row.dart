part of 'layers_panel.dart';

/// One layer toggle with availability state ("sem fonte" when missing).
class _LayerRow extends StatefulWidget {
  const _LayerRow({
    required this.spec,
    required this.active,
    required this.onToggle,
  });

  final LayerSpec spec;
  final bool active;
  final VoidCallback? onToggle;

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool available = widget.spec.available;
    return MouseRegion(
      cursor: available ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Opacity(
          opacity: available ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.active
                        ? FogoColors.accent
                        : (_hover && available
                              ? FogoColors.surfaceHover
                              : FogoColors.transparent),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: widget.active
                          ? FogoColors.accent
                          : FogoColors.borderStrong,
                    ),
                  ),
                  child: widget.active
                      ? const Icon(
                          LucideIcons.check,
                          size: 11,
                          color: FogoColors.onAccent,
                        )
                      : null,
                ),
                const SizedBox(width: FogoSpacing.sm),
                Expanded(
                  child: Text(
                    widget.spec.label,
                    style: FogoText.body.copyWith(fontSize: 12.5),
                  ),
                ),
                if (!available)
                  const FogoChip(
                    label: 'sem fonte',
                    color: FogoColors.statusOffline,
                    showDot: false,
                    outlined: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

part of 'search_results_panel.dart';

/// One search result: title from the first label segment, subtitle from the
/// remaining segments.
class _SearchResultRow extends StatefulWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final GeoSearchResult result;
  final VoidCallback onTap;

  @override
  State<_SearchResultRow> createState() => _SearchResultRowState();
}

class _SearchResultRowState extends State<_SearchResultRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final int comma = widget.result.label.indexOf(',');
    final String title = comma > 0
        ? widget.result.label.substring(0, comma)
        : widget.result.label;
    final String subtitle = comma > 0 && widget.result.label.length > comma + 2
        ? widget.result.label
              .substring(comma + 2)
              .split(',')
              .take(3)
              .join(' · ')
        : widget.result.sublabel;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? FogoColors.surfaceHover : FogoColors.transparent,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.map_pin,
                size: 14,
                color: FogoColors.textSecondary,
              ),
              const SizedBox(width: FogoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FogoText.body.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: FogoText.micro,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

part of 'top_bar.dart';

/// Module entry of the top bar with hover and active states.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.active
        ? FogoColors.textPrimary
        : (_hover ? FogoColors.textPrimary : FogoColors.textSecondary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.active
                ? FogoColors.activeSurface
                : FogoColors.transparent,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              height: 1,
              fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

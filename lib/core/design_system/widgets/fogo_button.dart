import 'package:flutter/widgets.dart';

import '../fogo_colors.dart';
import '../fogo_spacing.dart';

enum FogoButtonVariant { primary, active, ghost, danger }

/// Botão do design system (nenhum widget Material é usado).
class FogoButton extends StatefulWidget {
  const FogoButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.variant = FogoButtonVariant.ghost,
    this.expanded = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final FogoButtonVariant variant;
  final bool expanded;

  @override
  State<FogoButton> createState() => _FogoButtonState();
}

class _FogoButtonState extends State<FogoButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color border;
    final Color bg;
    final Color fg;
    switch (widget.variant) {
      case FogoButtonVariant.primary:
        bg = enabled
            ? (_hover
                  ? FogoColors.accent.withValues(alpha: 0.9)
                  : FogoColors.accent)
            : FogoColors.surfaceRaised;
        fg = enabled ? FogoColors.onAccent : FogoColors.textDisabled;
        border = enabled ? FogoColors.accent : FogoColors.border;
      case FogoButtonVariant.active:
        bg = enabled
            ? (_hover
                  ? FogoColors.activeSurface.withValues(alpha: 0.9)
                  : FogoColors.activeSurface)
            : FogoColors.surfaceRaised;
        fg = enabled ? FogoColors.onActiveSurface : FogoColors.textDisabled;
        border = enabled ? FogoColors.activeSurface : FogoColors.border;
      case FogoButtonVariant.ghost:
        bg = enabled && _hover
            ? FogoColors.surfaceHover
            : FogoColors.transparent;
        fg = enabled ? FogoColors.textPrimary : FogoColors.textDisabled;
        border = enabled ? FogoColors.borderStrong : FogoColors.border;
      case FogoButtonVariant.danger:
        bg = enabled && _hover
            ? FogoColors.statusCritical.withValues(alpha: 0.12)
            : FogoColors.transparent;
        fg = enabled ? FogoColors.statusCritical : FogoColors.textDisabled;
        border = enabled
            ? FogoColors.statusCritical.withValues(alpha: 0.5)
            : FogoColors.border;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: FogoSpacing.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
            border: Border.all(color: border),
          ),
          child: Center(
            child: Row(
              mainAxisSize: widget.expanded
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 15, color: fg),
                  const SizedBox(width: FogoSpacing.sm),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

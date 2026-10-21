import 'package:flutter/widgets.dart';

import '../fogo_colors.dart';
import '../fogo_spacing.dart';

/// Botão apenas-ícone do design system.
class FogoIconButton extends StatefulWidget {
  const FogoIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = FogoSpacing.iconButtonSize,
    this.iconSize = 16,
    this.iconColor,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool danger;

  @override
  State<FogoIconButton> createState() => _FogoIconButtonState();
}

class _FogoIconButtonState extends State<FogoIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color fg = enabled
        ? (widget.iconColor ??
              (widget.danger
                  ? FogoColors.statusCritical
                  : FogoColors.textSecondary))
        : FogoColors.textDisabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: enabled && _hover
                ? FogoColors.surfaceHover
                : FogoColors.transparent,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
            border: Border.all(color: FogoColors.transparent),
          ),
          child: Icon(widget.icon, size: widget.iconSize, color: fg),
        ),
      ),
    );
  }
}

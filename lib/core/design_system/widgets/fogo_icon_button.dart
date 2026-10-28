import 'package:flutter/widgets.dart';

import '../fogo_colors.dart';
import '../fogo_spacing.dart';
import 'fogo_animated_color.dart';

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
    this.filled = true,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool danger;

  /// Preenchimento `#01010e` (base-design.pen: ferramentas do header e
  /// botões de fechar dos modais). Falso = transparente.
  final bool filled;

  /// Estado ativo (base-design.pen: Aba Ativa do rail de navegação) —
  /// ciano `bg-active-surface` com glifo escuro sobre ele.
  final bool active;

  @override
  State<FogoIconButton> createState() => _FogoIconButtonState();
}

class _FogoIconButtonState extends State<FogoIconButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final bool lifted = enabled && (_hover || _pressed);
    final Color fg;
    final Color bg;
    if (!enabled) {
      fg = FogoColors.textDisabled;
      bg = widget.filled ? FogoColors.surfaceCard : FogoColors.transparent;
    } else if (widget.active) {
      fg = FogoColors.onActiveSurface;
      bg = lifted
          ? FogoColors.activeSurface.withValues(alpha: 0.9)
          : FogoColors.activeSurface;
    } else {
      fg =
          widget.iconColor ??
          (widget.danger
              ? FogoColors.statusCritical
              : FogoColors.textSecondary);
      bg = lifted
          ? FogoColors.surfaceHover
          : (widget.filled ? FogoColors.surfaceCard : FogoColors.transparent);
    }
    // Mesma mecânica do _WindowButton da titlebar: press escala 0.94.
    // Fundo anima como animateColorAsState (FogoAnimatedColor); o glifo
    // é filho estático — não é reconstruído nos ticks da animação.
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? FogoMotion.pressScale : 1,
          duration: FogoMotion.fast,
          curve: FogoMotion.curve,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: FogoAnimatedColor(
              color: bg,
              // Glifo também anima (ativo/inativo cruzam sem snap).
              child: FogoAnimatedColor(
                color: fg,
                builder: (context, color, _) =>
                    Icon(widget.icon, size: widget.iconSize, color: color),
              ),
              builder: (context, color, icon) => DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

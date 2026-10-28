import 'package:flutter/widgets.dart';

import '../fogo_colors.dart';
import '../fogo_spacing.dart';
import 'fogo_animated_color.dart';

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
    this.height = FogoSpacing.controlHeight,
    this.radius = FogoSpacing.radiusSm,
    this.glow = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final FogoButtonVariant variant;
  final bool expanded;

  /// Altura do controle (Navegador de Cidades usa 32, CTA de modal 42).
  final double height;

  /// Raio dos cantos (padrão `radiusSm`, modais usam `radiusMd`).
  final double radius;

  /// Glow com tinta do accent (base-design.pen: botão ativo do
  /// Navegador de Cidades).
  final bool glow;

  /// Preenchimento horizontal (padrão 14; botões de cidade usam 16).
  final EdgeInsetsGeometry padding;

  @override
  State<FogoButton> createState() => _FogoButtonState();
}

class _FogoButtonState extends State<FogoButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color border;
    final Color bg;
    final Color fg;
    switch (widget.variant) {
      case FogoButtonVariant.primary:
      case FogoButtonVariant.active:
        // base-design.pen: primário = ciano (bg-active-surface), sem
        // borda, rótulo escuro sobre ele.
        bg = enabled
            ? ((_hover || _pressed)
                  ? FogoColors.activeSurface.withValues(alpha: 0.9)
                  : FogoColors.activeSurface)
            : FogoColors.surfaceRaised;
        fg = enabled ? FogoColors.onActiveSurface : FogoColors.textDisabled;
        border = FogoColors.transparent;
      case FogoButtonVariant.ghost:
        // base-design.pen: fantasma = transparente, sem borda, rótulo
        // secundário; hover levanta o texto ao primário.
        bg = enabled && (_hover || _pressed)
            ? FogoColors.surfaceHover
            : FogoColors.transparent;
        fg = enabled
            ? ((_hover || _pressed)
                  ? FogoColors.textPrimary
                  : FogoColors.textSecondary)
            : FogoColors.textDisabled;
        border = FogoColors.transparent;
      case FogoButtonVariant.danger:
        bg = enabled && (_hover || _pressed)
            ? FogoColors.statusCritical.withValues(alpha: 0.12)
            : FogoColors.transparent;
        fg = enabled ? FogoColors.statusCritical : FogoColors.textDisabled;
        border = enabled
            ? FogoColors.statusCritical.withValues(alpha: 0.5)
            : FogoColors.border;
    }

    // Glow: só entra na árvore quando o botão pode brilhar (glow:true);
    // a cor anima entre accent e transparente — sem pop.
    final Color glowColor = enabled && widget.variant != FogoButtonVariant.ghost
        ? FogoColors.accentSoft
        : FogoColors.transparent;

    // Mesma mecânica do _WindowButton da titlebar: MouseRegion +
    // GestureDetector (down/up/cancel) + AnimatedScale no press. O hover
    // usa animateColorAsState (FogoAnimatedColor) para o fundo e
    // AnimatedDefaultTextStyle para o rótulo — nada troca de cor no snap.
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
            height: widget.height,
            // Três canais animados (animateColorAsState): glow → borda →
            // fundo. Cada um retarget independente; o conteúdo é filho
            // estático do canal mais interno.
            child: FogoAnimatedColor(
              color: border,
              builder: (context, borderColor, child) => FogoAnimatedColor(
                color: glowColor,
                child: child,
                builder: (context, glow, child) => FogoAnimatedColor(
                  color: bg,
                  child: child,
                  builder: (context, color, child) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(widget.radius),
                      border: Border.all(color: borderColor),
                      // Glow do botão ativo do Navegador de Cidades
                      // (base-design.pen: sombra com tinta do accent) —
                      // a cor anima entre accent e transparente.
                      boxShadow: widget.glow
                          ? [BoxShadow(color: glow, blurRadius: 12)]
                          : null,
                    ),
                    child: child,
                  ),
                ),
              ),
              child: Padding(
                padding: widget.padding,
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: FogoMotion.fast,
                    curve: FogoMotion.curve,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1,
                      // base-design.pen: rótulos inativos (ghost) usam peso
                      // médio; ativos/primários são semibold.
                      fontWeight: widget.variant == FogoButtonVariant.ghost
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color: fg,
                    ),
                    child: Row(
                      mainAxisSize: widget.expanded
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          FogoAnimatedColor(
                            color: fg,
                            builder: (context, color, _) =>
                                Icon(widget.icon, size: 15, color: color),
                          ),
                          const SizedBox(width: FogoSpacing.sm),
                        ],
                        Text(widget.label),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

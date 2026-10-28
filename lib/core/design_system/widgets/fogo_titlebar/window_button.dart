part of 'fogo_titlebar.dart';

enum WindowAction { minimize, maximize, close }

/// Botão de janela — porte fiel do LienneDart: 20×20, raio 6, glyphs
/// desenhados em canvas (stroke 2), hover accent (close → crítico),
/// press scale 0.94, 120ms easeInOut.
class _WindowButton extends StatefulWidget {
  const _WindowButton({required this.action, this.onTap});

  final WindowAction action;
  final VoidCallback? onTap;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _hovered || _pressed;
    final Color bg = switch (widget.action) {
      WindowAction.close when active => FogoColors.statusCritical,
      _ when active => FogoColors.accent,
      _ => FogoColors.surface,
    };
    final Color icon = active ? FogoColors.onAccent : FogoColors.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? FogoTitlebarMotion.windowButtonPressScale : 1,
          duration: FogoTitlebarMotion.fast,
          curve: FogoTitlebarMotion.curve,
          child: AnimatedContainer(
            width: 20,
            height: 20,
            duration: FogoTitlebarMotion.fast,
            curve: FogoTitlebarMotion.curve,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              // Glifo anima a cor junto com o fundo (sem snap).
              child: FogoAnimatedColor(
                color: icon,
                builder: (context, color, _) => CustomPaint(
                  size: const Size.square(12),
                  painter: _WindowGlyphPainter(widget.action, color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

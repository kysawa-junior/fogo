import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/window_close_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../fogo_colors.dart';

/// Motion tokens da titlebar — mesmos valores do LienneDart
/// (`TitlebarMotion`: fast 120ms, press scale 0.94).
abstract final class FogoTitlebarMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Curve curve = Curves.easeInOut;
  static const double windowButtonPressScale = 0.94;
}

/// Titlebar própria do F.O.G.O. — janela frameless (title bar nativa
/// ocultada via window_manager): marca à esquerda, área central arrastável
/// e botões de janela à direita. Porte do padrão LienneDart.
class FogoTitlebar extends StatelessWidget {
  const FogoTitlebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(color: FogoColors.bg),
      child: Row(
        children: [
          const _Brand(),
          // Área central arrastável (arrasta a janela frameless).
          const Expanded(child: DragToMoveArea(child: SizedBox(height: 40))),
          _WindowButton(
            action: WindowAction.minimize,
            onTap: () => windowManager.minimize(),
          ),
          const SizedBox(width: 6),
          _WindowButton(
            action: WindowAction.maximize,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.restore();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          const SizedBox(width: 6),
          _WindowButton(action: WindowAction.close, onTap: closeApplication),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppConstants.appTitle,
          style: TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: FogoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

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
              child: CustomPaint(
                size: const Size.square(12),
                painter: _WindowGlyphPainter(widget.action, icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glyphs 12×12 desenhados (mesma linguagem do LienneDart), stroke 2.
class _WindowGlyphPainter extends CustomPainter {
  const _WindowGlyphPainter(this.action, this.color);

  final WindowAction action;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    switch (action) {
      case WindowAction.minimize:
        canvas.drawLine(
          Offset(size.width * 0.15, size.height / 2),
          Offset(size.width * 0.85, size.height / 2),
          paint,
        );
      case WindowAction.maximize:
        final double inset = size.width * 0.15;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              inset,
              inset,
              size.width - inset * 2,
              size.height - inset * 2,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      case WindowAction.close:
        final double p = size.width * 0.25;
        canvas.drawLine(
          Offset(p, p),
          Offset(size.width - p, size.height - p),
          paint,
        );
        canvas.drawLine(
          Offset(size.width - p, p),
          Offset(p, size.height - p),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_WindowGlyphPainter old) =>
      old.action != action || old.color != color;
}

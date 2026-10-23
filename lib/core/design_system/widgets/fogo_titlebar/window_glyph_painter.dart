part of 'fogo_titlebar.dart';

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

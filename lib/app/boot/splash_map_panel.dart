import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/design_system/fogo_colors.dart';
import 'splash_brand_panel.dart';
import 'splash_type.dart';

/// Painel cartográfico da Splash (470×500) — base-design.pen, frame
/// "Metade Clara · Mapa": mock da malha urbana com a rota ativa.
class SplashMapPanel extends StatelessWidget {
  const SplashMapPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: CustomPaint(painter: _SplashMapPainter())),
        const Positioned(
          left: 420,
          top: 242,
          child: Icon(
            LucideIcons.map_pin,
            size: 26,
            color: FogoColors.activeSurface,
          ),
        ),
        const Positioned(left: 48, bottom: 23, child: SplashSinalTag()),
        const Positioned(
          left: 292,
          bottom: 23,
          child: Text('23.5505 S · 46.6333 W', style: SplashType.coordinates),
        ),
      ],
    );
  }
}

/// Desenha o mock cartográfico da Splash. Geometria copiada do frame
/// "Metade Clara · Mapa" do base-design.pen (coordenadas do frame).
class _SplashMapPainter extends CustomPainter {
  // Malha viária (t Bronx 1,5px).
  static const List<double> _streetsH = <double>[90, 180, 310, 410];
  static const List<double> _streetsV = <double>[70, 160, 340, 430];

  // Avenidas (2,5px).
  static const double _avenueH = 250;
  static const double _avenueV = 250;

  // Quarteirões.
  static const List<Rect> _blocks = <Rect>[
    Rect.fromLTWH(86, 104, 64, 56),
    Rect.fromLTWH(166, 104, 70, 56),
    Rect.fromLTWH(86, 196, 64, 60),
    Rect.fromLTWH(330, 104, 90, 56),
    Rect.fromLTWH(330, 196, 90, 60),
    Rect.fromLTWH(86, 376, 150, 56),
    Rect.fromLTWH(340, 376, 76, 56),
  ];

  // Curvas de nível (arcos concêntricos).
  static const List<Rect> _arcs = <Rect>[
    Rect.fromLTWH(328, 384, 140, 112),
    Rect.fromLTWH(290, 354, 216, 173),
    Rect.fromLTWH(252, 323, 292, 234),
  ];

  // Malha de pontos de interesse.
  static const List<double> _poiX = <double>[88, 156, 224, 292, 360, 428];
  static const List<double> _poiY = <double>[88, 146, 204, 262, 320, 378, 436];

  // Rótulo da rota ativa.
  static const Rect _sinal = Rect.fromLTWH(166, 286, 70, 60);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = FogoColors.splashMapPaper,
    );
    _wash(canvas);
    _streets(canvas, size);
    _blocksLayer(canvas);
    _arcsLayer(canvas);
    _routes(canvas);
    _markers(canvas);
  }

  /// Lavagem azul radial no alto à esquerda.
  void _wash(Canvas canvas) {
    final Rect rect = const Rect.fromLTWH(-60, -70, 400, 400);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            FogoColors.activeSurface.withValues(alpha: 0.16),
            FogoColors.activeSurface.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  /// Malha viária: ruas finas e avenidas destacadas.
  void _streets(Canvas canvas, Size size) {
    final Paint street = Paint()
      ..color = FogoColors.activeSurface.withValues(alpha: 0.10)
      ..strokeWidth = 1.5;
    for (final double y in _streetsH) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), street);
    }
    for (final double x in _streetsV) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), street);
    }
    final Paint avenue = Paint()
      ..color = FogoColors.activeSurface.withValues(alpha: 0.22)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, _avenueH), Offset(size.width, _avenueH), avenue);
    canvas.drawLine(Offset(_avenueV, 0), Offset(_avenueV, size.height), avenue);
  }

  /// Quarteirões (um deles em destaque, na cor de acento).
  void _blocksLayer(Canvas canvas) {
    final Paint block = Paint()
      ..color = FogoColors.activeSurface.withValues(alpha: 0.08);
    for (final Rect rect in _blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        block,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(_sinal, const Radius.circular(2)),
      Paint()..color = FogoColors.accent.withValues(alpha: 0.15),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(_sinal, const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = FogoColors.accent.withValues(alpha: 0.35),
    );
  }

  /// Curvas de nível.
  void _arcsLayer(Canvas canvas) {
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = FogoColors.activeSurface.withValues(alpha: 0.18);
    for (final Rect rect in _arcs) {
      canvas.drawOval(rect, arc);
    }
  }

  /// Rota ativa (ciano) e rota secundária (laranja).
  void _routes(Canvas canvas) {
    canvas.drawPath(
      _route(const Offset(20, 254)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = FogoColors.accent.withValues(alpha: 0.4),
    );
    canvas.drawPath(
      _route(const Offset(20, 240)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = FogoColors.activeSurface,
    );
  }

  /// Traçado da rota (viewBox 430×210 do design).
  Path _route(Offset origin) => Path()
    ..moveTo(origin.dx, origin.dy + 210)
    ..cubicTo(
      origin.dx + 100,
      origin.dy + 210,
      origin.dx + 130,
      origin.dy + 120,
      origin.dx + 230,
      origin.dy + 120,
    )
    ..cubicTo(
      origin.dx + 330,
      origin.dy + 120,
      origin.dx + 360,
      origin.dy + 30,
      origin.dx + 430,
      origin.dy + 30,
    );

  /// Pontos de interesse e losango da rota.
  void _markers(Canvas canvas) {
    final Paint poi = Paint()
      ..color = FogoColors.activeSurface.withValues(alpha: 0.3);
    for (final double y in _poiY) {
      for (final double x in _poiX) {
        canvas.drawCircle(Offset(x, y), 1.2, poi);
      }
    }
    canvas.save();
    canvas.translate(233, 357);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 10),
      Paint()..color = FogoColors.activeSurface,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashMapPainter old) => false;
}

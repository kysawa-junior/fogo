import 'package:flutter/widgets.dart';

/// Tokens de espaçamento, raios e dimensões recorrentes.
abstract final class FogoSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 12;
  static const double radiusXl = 14;

  static const double controlHeight = 34;
  static const double iconButtonSize = 32;
  static const double panelWidth = 340;
  static const double topBarHeight = 52;

  static const EdgeInsets panelPadding = EdgeInsets.all(14);

  /// Sombra dos cards flutuantes (base-design.pen: Header, Navegador de
  /// Cidades, Card Base Cartográfica).
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -10,
    ),
  ];

  /// Sombra de modais (base-design.pen: Modal Cidade Preditiva).
  static const List<BoxShadow> modalShadow = [
    BoxShadow(
      color: Color(0xCC000000),
      offset: Offset(0, 18),
      blurRadius: 48,
      spreadRadius: -12,
    ),
  ];
}

/// Tokens de movimento do design system — mesmos valores do WindowButton
/// da titlebar (fast 120ms, easeInOut, press scale 0.94).
abstract final class FogoMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Curve curve = Curves.easeInOut;

  /// Escala do botão pressionado (feedback de OnClick).
  static const double pressScale = 0.94;
}

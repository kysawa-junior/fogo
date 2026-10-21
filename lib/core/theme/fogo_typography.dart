import 'package:flutter/widgets.dart';

import '../design_system/fogo_colors.dart';

/// Tipografia F.O.G.O. — hierarquia compacta para central operacional desktop.
abstract final class FogoText {
  static const TextStyle title = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: FogoColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: FogoColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: FogoColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    height: 1.35,
    color: FogoColors.textSecondary,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 10,
    height: 1.3,
    letterSpacing: 0.6,
    color: FogoColors.textDisabled,
  );

  /// Números alinhados (ids, contadores, coordenadas).
  static const TextStyle mono = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
    color: FogoColors.textSecondary,
  );
}

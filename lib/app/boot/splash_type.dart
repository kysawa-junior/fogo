import 'package:flutter/widgets.dart';

import '../../core/design_system/fogo_colors.dart';

/// Tipografia da Splash — base-design.pen, frame "Splash / Carregamento".
/// Inter para UI, JetBrains Mono para dados e rótulos técnicos.
abstract final class SplashType {
  /// Família UI do design (Inter).
  static const String ui = 'Inter';

  /// Família mono do design (JetBrains Mono).
  static const String mono = 'JetBrainsMono';

  /// Logotipo "FOGO".
  static const TextStyle logo = TextStyle(
    fontFamily: ui,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: 6,
    color: FogoColors.textPrimary,
  );

  /// Subtítulo sob o logotipo.
  static const TextStyle subtitle = TextStyle(
    fontFamily: mono,
    fontSize: 8.5,
    letterSpacing: 2.5,
    color: FogoColors.textTertiary,
  );

  /// Linha de status (à esquerda da linha de progresso).
  static const TextStyle status = TextStyle(
    fontFamily: ui,
    fontSize: 10,
    letterSpacing: 2,
    color: FogoColors.textPrimary,
  );

  /// Contador/percentual (à direita da linha de status).
  static const TextStyle counter = TextStyle(
    fontFamily: mono,
    fontSize: 10,
    color: FogoColors.activeSurface,
  );

  /// Linha de versão.
  static const TextStyle version = TextStyle(
    fontFamily: mono,
    fontSize: 8,
    letterSpacing: 1,
    color: FogoColors.textTertiary,
  );

  /// Linha de créditos.
  static const TextStyle credits = TextStyle(
    fontFamily: mono,
    fontSize: 8,
    letterSpacing: 0.5,
    color: FogoColors.textTertiary,
  );

  /// Mensagem de erro da carga.
  static const TextStyle error = TextStyle(
    fontFamily: ui,
    fontSize: 10,
    height: 1.5,
    color: FogoColors.statusCritical,
  );

  /// Etiqueta sobre o mock cartográfico.
  static const TextStyle tag = TextStyle(
    fontFamily: mono,
    fontSize: 9,
    letterSpacing: 1,
    color: FogoColors.activeSurface,
  );

  /// Coordenadas sobre o mock cartográfico.
  static const TextStyle coordinates = TextStyle(
    fontFamily: mono,
    fontSize: 9,
    letterSpacing: 1,
    color: FogoColors.splashMapInk,
  );
}

import 'package:flutter/widgets.dart';

/// Tokens de cor do design system F.O.G.O.
/// Nenhum widget deve declarar cores arbitrárias — usar sempre estes tokens.
abstract final class FogoColors {
  // Fundos e superfícies
  static const Color bg = Color(0xFF01010A);
  static const Color surface = Color(0xFF121824);

  // Cards flutuantes (espelham a variável bg-surface do base-design.pen)
  static const Color surfaceCard = Color(0xFF01010E);
  static const Color surfaceRaised = Color(0xFF1A2231);
  static const Color surfaceHover = Color(0xFF202A3C);
  static const Color border = Color(0xFF243044);
  static const Color borderStrong = Color(0xFF33425C);

  // Texto
  static const Color textPrimary = Color(0xFFF4F5FA);
  static const Color textSecondary = Color(0xFFA2A8C6);
  static const Color textTertiary = Color(0xFF6A7095);
  static const Color textDisabled = textTertiary;

  // Identidade F.O.G.O.
  static const Color accent = Color(0xFFFF6A2B);
  static const Color accentSoft = Color(0x26FF6A2B);
  static const Color onAccent = Color(0xFF1A0E08);

  // Acento de superfície ativa (variável bg-active-surface do base-design.pen)
  static const Color activeSurface = Color(0xFF0FC3FF);
  static const Color onActiveSurface = Color(0xFF0B0B14);
  static const Color transparent = Color(0x00000000);

  // Estados operacionais (semântica compartilhada)
  static const Color statusNormal = Color(0xFF4ADE80);
  static const Color statusAttention = Color(0xFFF5B84C);
  static const Color statusCritical = Color(0xFFFF5A5F);
  static const Color statusOffline = Color(0xFF7C879B);
  static const Color info = Color(0xFF5CA8FF);

  // Navegação flutuante (header e navegador de cidades — base-design.pen)
  static const Color overlayFaint = Color(0x08FFFFFF);
  static const Color borderSubtle = Color(0x14FFFFFF);

  // Splash (base-design.pen · frame "Splash / Carregamento")
  /// Trilho do progresso (2px) da Splash.
  static const Color splashTrack = Color(0x1FFFFFFF);

  /// Cabeça da barra de progresso da Splash.
  static const Color splashProgressHead = Color(0xFFB3E9FF);

  /// Papel do mock cartográfico (metade clara da Splash).
  static const Color splashMapPaper = Color(0xFFD9D9D9);

  /// Tinta secundária do mock cartográfico (coordenadas).
  static const Color splashMapInk = Color(0xFF5E7B94);
}

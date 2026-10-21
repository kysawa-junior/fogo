import 'dart:math' as math;

import 'vector_data.dart';

/// Perfis de largura em px de tela com clamp por classe. Vias poligonais
/// mantêm em todas as escalas o valor de cada classe em z16. O perfil raw
/// continua adaptativo apenas para escalas auxiliares (ex.: dormentes).
///
/// Todas as escalas: motorway 11, trunk 10, primary 9, secondary 6,
/// tertiary 5.75, unclassified/residential 5, other 4.25, service 3.5,
/// track 2.75 e path 2 px.
///
/// Nenhuma via pode ultrapassar o máximo da sua classe em NENHUM zoom —
/// elimina a hipertrofia que cobria quarteirões/lotes em zoom profundo.
abstract final class RoadWidths {
  // Curvas-base por zoom (interpolação linear; clamp nas extremidades).
  static const List<(double, double)> _mainAnchors = [
    (7, 0.8),
    (10, 1.8),
    (12, 2.2),
    (13, 2.4),
    (14, 2.5), // ≤14: principais 2–3px
    (15, 5), // 15: 4–6px
    (16, 10), // 16: 8–12px
    (17, 16), // 17: 14–18px
    (18, 20),
    (18.5, 22), // ≥18: máx 22px
    (19, 22),
  ];

  static const List<(double, double)> _localAnchors = [
    (7, 0.3),
    (10, 0.7),
    (12, 0.9),
    (13, 0.95),
    (14, 1.0), // ≤14: secundárias ~1px
    (15, 2.5), // 15: 2–3px
    (16, 5), // 16: 4–6px
    (17, 10), // 17: 8–12px
    (18, 13),
    (18.5, 14), // ≥18: máx 14px
    (19, 14),
  ];

  /// Perfil por classe: (curva-base, fator, MÁXIMO PERMITIDO em px).
  /// O clamp é a Regra de Ouro — nada ultrapassa o máximo da classe.
  static const Map<RoadClass, (String base, double factor, double maxPx)>
  _profile = {
    RoadClass.motorway: ('main', 1.10, 22),
    RoadClass.trunk: ('main', 1.00, 22),
    RoadClass.primary: ('main', 0.90, 20),
    RoadClass.secondary: ('local', 1.20, 14),
    RoadClass.tertiary: ('local', 1.15, 14),
    RoadClass.unclassified: ('local', 1.00, 14),
    RoadClass.residential: ('local', 1.00, 14),
    RoadClass.other: ('local', 0.85, 12),
    RoadClass.service: ('local', 0.70, 10),
    RoadClass.track: ('local', 0.55, 8),
    RoadClass.path: ('local', 0.40, 6),
  };

  static double _interp(List<(double, double)> pts, double zoom) {
    if (zoom <= pts.first.$1) return pts.first.$2;
    for (int i = 1; i < pts.length; i++) {
      if (zoom <= pts[i].$1) {
        final (z0, w0) = pts[i - 1];
        final (z1, w1) = pts[i];
        final double t = (zoom - z0) / (z1 - z0);
        return w0 + (w1 - w0) * t;
      }
    }
    return pts.last.$2;
  }

  /// Curva-base adaptativa em px, ainda usada para escala de ferrovias.
  /// Retorna a largura após o CLAMP da classe.
  static double width(RoadClass cls, double zoom) {
    final (base, factor, maxPx) = _profile[cls]!;
    final double curve = base == 'main'
        ? _interp(_mainAnchors, zoom)
        : _interp(_localAnchors, zoom);
    return math.min(curve * factor, maxPx);
  }

  /// Fixed screen width used by polygon roads at every camera zoom.
  static double surfaceWidth(RoadClass cls, double _) => width(cls, 16);

  /// MÁXIMO PERMITIDO da classe (px) — para testes e UI.
  static double maxAllowed(RoadClass cls) => _profile[cls]!.$3;

  /// Casing width delta (px) is fixed to the zoom-16 value at every zoom.
  static double casingDelta(double _) => 2.4;

  /// MEIA-largura do FILL em METROS no zoom atual: largura em px convertida
  /// por m/px da câmera (px → metros, conversão única e explícita).
  static double halfFillMeters(RoadClass cls, double zoom, double mpp) =>
      surfaceWidth(cls, zoom) / 2 * mpp;

  /// MEIA-largura do CASING em METROS: fill + delta do casing em metros.
  static double halfCasingMeters(RoadClass cls, double zoom, double mpp) =>
      halfFillMeters(cls, zoom, mpp) + casingDelta(zoom) / 2 * mpp;
}

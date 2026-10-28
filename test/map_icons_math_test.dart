import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/features/map/presentation/render/map_2d/map_2d_renderer.dart';

/// Ícones 2D: matemática pura (transform compartilhado + banda de alpha).
/// A extração ([extractMapIcons]) precisa do motor carregado — coberta
/// indiretamente pelos smoke tests de mount; aqui validamos o contrato
/// de tela e zoom que o hit-test e o painter compartilham.
void main() {
  group('iconScreenPoint (mesma base do painter)', () {
    const s = 10.0, w = 200.0, h = 200.0;
    ui.Offset? p(double x, double z, [double az = 0]) =>
        Map2DRenderer.iconScreenPoint(
          worldX: x,
          worldZ: z,
          targetX: 0,
          targetZ: 0,
          azimuth: az,
          s: s,
          viewWidth: w,
          viewHeight: h,
        );

    test('alvo no centro; +x pinta para BAIXO e +z para a DIREITA', () {
      expect(p(0, 0), const ui.Offset(100, 100));
      expect(p(10, 0), const ui.Offset(100, 200));
      expect(p(0, 10), const ui.Offset(200, 100));
    });

    test('fora da view (com margem) → null', () {
      expect(p(500, 0), isNull);
      expect(p(0, -500), isNull);
    });

    test('s <= 0 → null (câmera inválida)', () {
      expect(
        Map2DRenderer.iconScreenPoint(
          worldX: 1,
          worldZ: 1,
          targetX: 0,
          targetZ: 0,
          azimuth: 0,
          s: 0,
          viewWidth: 100,
          viewHeight: 100,
        ),
        isNull,
      );
    });
  });

  group('iconAlpha (banda de zoom)', () {
    test('full afastado, zero com o 3D opaco e na visão geral', () {
      expect(Map2DRenderer.iconAlpha(5000), 1.0);
      expect(Map2DRenderer.iconAlpha(12000), 0.0);
      expect(Map2DRenderer.iconAlpha(12500), 0.0);
      expect(Map2DRenderer.iconAlpha(1000), 0.0);
    });

    test('monotônico decrescente; meia-alfa onde o 3D dos semáforos surge', () {
      // Em 1200 m os semáforos 3D começam a surgir (LOD 2) — o ícone já
      // está a ~50% (overlay a 50% + banda própria) e some até 1000 m.
      expect(Map2DRenderer.iconAlpha(1200), closeTo(0.5, 0.05));
      double previous = double.infinity;
      for (double d = 1400; d >= 900; d -= 25) {
        final a = Map2DRenderer.iconAlpha(d);
        expect(a, lessThanOrEqualTo(previous));
        expect(a, greaterThanOrEqualTo(0.0));
        previous = a;
      }
    });
  });
}

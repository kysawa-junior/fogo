import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/engine/scene/lod_policy.dart';

/// ENG: modo mapa — LOD de edifícios + trava 2D da câmera. LOD de
/// volumes em 3500 m; trava top-down até 1000 m (= banda de opacidade
/// do overlay 3D, 1400→1000): afastado = base do mapa de cima;
/// aproximar libera a camada 3D e, abaixo de 1000 m, o pitch.
void main() {
  group('LodPolicy', () {
    test('edifício: oculto de longe, visível em aproximação', () {
      expect(LodPolicy.levelOf(SceneObjectKind.building), 1);
      expect(
        LodPolicy.isLevelVisible(1, 5000, previousDistance: 6000),
        isFalse,
      );
      expect(LodPolicy.isLevelVisible(1, 3000, previousDistance: 6000), isTrue);
    });

    test('base do mapa (via/área/água): sempre visível; pad é L1', () {
      // Base 2D limpa na visão geral: vias, áreas e água em qualquer
      // distância.
      for (final kind in [
        SceneObjectKind.road,
        SceneObjectKind.landArea,
        SceneObjectKind.water,
      ]) {
        expect(LodPolicy.levelOf(kind), 0);
        expect(
          LodPolicy.isLevelVisible(0, 25000, previousDistance: 25000),
          isTrue,
        );
      }
      // Pads de junção: ~7 mil malhas pequenas invisíveis na escala de
      // km — mesmas gate de volume (L1) que edifícios.
      expect(LodPolicy.levelOf(SceneObjectKind.junctionPad), 1);
      expect(
        LodPolicy.isLevelVisible(1, 5000, previousDistance: 6000),
        isFalse,
      );
      expect(LodPolicy.isLevelVisible(1, 3000, previousDistance: 6000), isTrue);
    });
  });

  group('OrbitCamera trava 2D', () {
    test('afastado: elevação converge para o topo (vista de mapa)', () {
      final camera = OrbitCamera();
      camera.goalDistance = 10000;
      camera.goalElevation = 0.9; // tentativa de vista oblíqua
      camera.tick(1e9); // convergência instantânea
      // ~85° (zênite limitado) — top-down prático, sem usar órbita
      // exata de 90°.
      expect(camera.elevationRadians, greaterThan(1.45));
      expect(camera.distanceMeters, closeTo(10000, 1e-6));
    });

    test('rotação ignorada afastado; aproximar devolve o controle', () {
      final camera = OrbitCamera();
      camera.goalDistance = 10000;
      camera.tick(1e9);
      camera.rotate(30, 30); // tentativa de inclinar
      camera.tick(1e9);
      expect(camera.elevationRadians, greaterThan(1.45));

      camera.zoom(16); // 10000/16 = 625 < 1000 → camada 3D opaca, pitch livre
      camera.rotate(0, 40); // dy positivo baixa a elevação
      camera.tick(1e9);
      expect(camera.elevationRadians, lessThan(1.48));
    });

    test('perto: inclinação livre preservada (regressão do limite)', () {
      final camera = OrbitCamera();
      // 900 m < 1000 (trava top-down): pitch livre abaixo da banda do 3D.
      camera.goalDistance = 900;
      camera.goalElevation = 0.5;
      camera.tick(1e9);
      expect(camera.elevationRadians, closeTo(0.5, 1e-6));
    });
  });
}

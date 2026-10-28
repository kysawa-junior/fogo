import 'package:fogo/features/map/presentation/render/scene_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneOverlayOpacity.compute', () {
    test('invisível acima do limiar (câmera afastada)', () {
      expect(SceneOverlayOpacity.compute(25000), 0.0);
      expect(SceneOverlayOpacity.compute(1400), 0.0);
      expect(SceneOverlayOpacity.compute(2000), 0.0);
    });

    test('opaco abaixo da banda (câmera próxima)', () {
      expect(SceneOverlayOpacity.compute(1000), 1.0);
      expect(SceneOverlayOpacity.compute(100), 1.0);
    });

    test('monotônico crescente dentro da banda 1400→1000', () {
      double previous = -1;
      for (double d = 1400; d >= 1000; d -= 10) {
        final o = SceneOverlayOpacity.compute(d);
        expect(o, greaterThanOrEqualTo(previous));
        previous = o;
      }
    });

    test('extremos da banda interpolam entre 0 e 1 (sem pop)', () {
      final justInside = SceneOverlayOpacity.compute(1390);
      expect(justInside, greaterThan(0));
      expect(justInside, lessThan(0.1));
      final nearFull = SceneOverlayOpacity.compute(1010);
      expect(nearFull, greaterThan(0.9));
      expect(nearFull, lessThan(1));
    });
  });
}

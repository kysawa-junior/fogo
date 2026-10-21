import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/vector/label_layout.dart';

void main() {
  group('LabelLayout — colisão AABB (spec §2a)', () {
    test('rótulo sobre rótulo é rejeitado', () {
      final LabelLayout layout = LabelLayout();
      const Rect a = Rect.fromLTWH(100, 100, 80, 12);
      expect(
        layout.tryPlace(key: 'Rua A', anchor: const Offset(140, 106), aabb: a),
        isTrue,
      );
      // colide com A
      const Rect overlap = Rect.fromLTWH(150, 100, 80, 12);
      expect(
        layout.tryPlace(
          key: 'Rua B',
          anchor: const Offset(190, 106),
          aabb: overlap,
        ),
        isFalse,
      );
      // livre ao lado
      const Rect free = Rect.fromLTWH(200, 100, 80, 12);
      expect(
        layout.tryPlace(
          key: 'Rua B',
          anchor: const Offset(240, 106),
          aabb: free,
        ),
        isTrue,
      );
      expect(layout.placed, 2);
      expect(layout.hidden, 1);
    });

    test('AABB rotacionado cobre a diagonal (texto inclinado)', () {
      final Rect r = LabelLayout.rotatedAabb(
        const Offset(500, 400),
        100,
        10,
        0.785, // 45°
      );
      // AABB de 100×10 a 45° ≈ 77.8 (|cos|+|sin| combinados) — cobre o
      // retângulo rotacionado inteiro sem passar da diagonal (110)
      expect(r.width, closeTo(77.8, 0.5));
      expect(r.height, closeTo(77.8, 0.5));
      expect(r.center, const Offset(500, 400));
    });
  });

  group('LabelLayout — dedup por distância (spec §2b)', () {
    test('mesma via só reaparece após 350px', () {
      final LabelLayout layout = LabelLayout(sameLabelDistance: 350);
      const Rect box = Rect.fromLTWH(0, 0, 90, 10);
      expect(
        layout.tryPlace(
          key: 'Rua Melchiades',
          anchor: const Offset(100, 200),
          aabb: box,
        ),
        isTrue,
      );
      // 200px depois: rejeitado
      expect(
        layout.tryPlace(
          key: 'Rua Melchiades',
          anchor: const Offset(300, 200),
          aabb: box.shift(const Offset(200, 0)),
        ),
        isFalse,
      );
      // 400px depois: aceito
      expect(
        layout.tryPlace(
          key: 'Rua Melchiades',
          anchor: const Offset(500, 200),
          aabb: box.shift(const Offset(400, 0)),
        ),
        isTrue,
      );
    });

    test('chaves distintas não sofrem dedup entre si (só colisão AABB)', () {
      final LabelLayout layout = LabelLayout();
      const Rect box = Rect.fromLTWH(0, 0, 90, 10);
      expect(
        layout.tryPlace(
          key: 'Rua X',
          anchor: const Offset(100, 100),
          aabb: box,
        ),
        isTrue,
      );
      expect(
        layout.tryPlace(
          key: 'Rua Y',
          anchor: const Offset(500, 500),
          aabb: box.shift(const Offset(400, 400)),
        ),
        isTrue,
      );
    });
  });
}

import 'package:fogo/engine/load_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fração global: base das fases + peso da fase atual', () {
    final phases = <String>[];
    final fractions = <double>[];
    final progress = LoadProgress((phase, count, fraction) {
      phases.add(phase);
      fractions.add(fraction);
    });

    progress.begin('Interpretando OSM');
    progress.step(500, 0.5);
    progress.begin('Deduplicando vias');
    progress.step(10, 1);
    progress.finish(10);

    expect(phases.first, 'Interpretando OSM');
    expect(fractions.first, 0);
    // Metade do peso do parse (0,076 / 2).
    expect(fractions[1], closeTo(0.038, 1e-9));
    // A fase seguinte começa onde a anterior terminou.
    expect(fractions[2], closeTo(0.076, 1e-9));
    expect(fractions.last, 1.0);
    for (var i = 1; i < fractions.length; i++) {
      expect(fractions[i], greaterThanOrEqualTo(fractions[i - 1]));
    }
  });

  test('pesos das fases somam 1 (barra fecha em 100%)', () {
    final double total = kLoadPhaseWeight.values.fold(
      0,
      (double sum, double w) => sum + w,
    );
    expect(total, closeTo(1.0, 1e-9));
  });
}

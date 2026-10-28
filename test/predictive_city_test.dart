import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/presentation/render/map_icons.dart';
import 'package:fogo/features/predictive_city/domain/risk_area.dart';
import 'package:fogo/features/predictive_city/providers/predictive_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RiskArea (fogo-server JSON)', () {
    const json = {
      'id': 'RA-3-2',
      'centroid': {'latitude': -22.2, 'longitude': -49.9},
      'bounds': [-22.21, -49.91, -22.20, -49.90],
      'score': 62,
      'level': 'alto',
      'breakdown': {
        'chuva': 9.0,
        'eletricos': 25.0,
        'manutencao': 20.0,
        'falhas': 0.0,
        'viario': 8.0,
      },
    };

    test('parse completo', () {
      final area = RiskArea.fromJson(json);
      expect(area.id, 'RA-3-2');
      expect(area.score, 62);
      expect(area.level, RiskLevel.alto);
      expect(area.centroidLatitude, -22.2);
      expect(area.bounds, [-22.21, -49.91, -22.20, -49.90]);
      expect(area.breakdown.eletricos, 25.0);
    });

    test('ranked() ordena fatores por contribuição', () {
      final ranked = RiskArea.fromJson(json).breakdown.ranked();
      expect(ranked.first, ('Elétricos (semáforo/radar/câmera)', 25.0));
      // Ordenação estritamente decrescente nos valores > 0.
      final values = [for (final (_, v) in ranked) v];
      final nonIncreasing = [
        for (var i = 0; i < values.length - 1; i++) values[i] >= values[i + 1],
      ];
      expect(nonIncreasing, everyElement(isTrue));
    });
  });

  group('providers Cidade Preditiva', () {
    test('modo começa desligado e alterna', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(predictiveModeProvider), isFalse);
      container.read(predictiveModeProvider.notifier).set(true);
      expect(container.read(predictiveModeProvider), isTrue);
    });

    test('filtro de ícones: todos por default, toggle remove e readiciona', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(mapIconFilterProvider), MapIconKind.values.toSet());
      final notifier = container.read(mapIconFilterProvider.notifier);
      notifier.toggle(MapIconKind.signal);
      expect(
        container.read(mapIconFilterProvider).contains(MapIconKind.signal),
        isFalse,
      );
      notifier.toggle(MapIconKind.signal);
      expect(container.read(mapIconFilterProvider), MapIconKind.values.toSet());
      notifier.toggle(MapIconKind.radar);
      notifier.all();
      expect(container.read(mapIconFilterProvider), MapIconKind.values.toSet());
    });
  });

  test('mapIconFilterProvider cobre todos os kinds', () {
    // Sanidade: 5 tipos (signal, policeVehicle, fireVehicle, radar,
    // camera) — novos kinds devem entrar no default do filtro.
    expect(MapIconKind.values.length, 5);
  });
}

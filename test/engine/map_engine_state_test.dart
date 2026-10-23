import 'package:fogo/features/map/domain/map_selection.dart';
import 'package:fogo/features/map/presentation/selection_details.dart';
import 'package:fogo/features/map/providers/map_engine_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('MapEngineState', () {
    test('copyWith preserva o resto e limpa details quando pedido', () {
      const state = MapEngineState(
        phase: MapReady(),
        activeCityId: 'marilia',
        sourceLabel: 'Marília-SP',
        details: EntityDetails(title: 'x', subtitle: 'y', properties: []),
      );
      final next = state.copyWith(selection: const FeatureSelection('way/1'));
      expect(next.sourceLabel, 'Marília-SP');
      expect(next.details, isNotNull);

      final cleared = next.copyWith(clearDetails: true);
      expect(cleared.details, isNull);
      expect(cleared.phase, isA<MapReady>());
    });
  });

  group('buildEntityDetails', () {
    test('rua: nome, tipo, largura conhecida e sentido', () {
      final engine = fogoEngineOfTest;
      final road = engine!.model.byId('way/10')!;
      final details = buildEntityDetails(road);
      expect(details.title, 'Rua Reta');
      expect(details.subtitle, contains('Via'));
      final width = details.properties.firstWhere((p) => p.$1 == 'Largura').$2;
      expect(width, contains('7.0 m (tag)'));
      expect(
        details.properties.firstWhere((p) => p.$1 == 'Sentido único').$2,
        'não',
      );
    });

    test('edifício: altura conhecida vs estimada são distinguíveis', () {
      final engine = fogoEngineOfTest;
      final known = buildEntityDetails(engine!.model.byId('way/20')!);
      expect(
        known.properties.firstWhere((p) => p.$1 == 'Altura').$2,
        contains('(tag)'),
      );

      final estimated = buildEntityDetails(engine.model.byId('way/22')!);
      expect(
        estimated.properties.firstWhere((p) => p.$1 == 'Altura').$2,
        contains('estimado'),
      );
    });

    test('travessia lista múltiplas vias conectadas', () {
      final engine = fogoEngineOfTest;
      final crossing = buildEntityDetails(engine!.model.byId('node/2')!);
      expect(crossing.title, 'Travessia de pedestres');
      final vias = crossing.properties
          .firstWhere((p) => p.$1 == 'Vias conectadas')
          .$2;
      expect(vias, contains('way/10'));
      expect(vias, contains('way/12'));
    });
  });
}

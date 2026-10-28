import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/features/map/domain/map_selection.dart';
import 'package:fogo/features/map/presentation/selection_details.dart';
import 'package:fogo/features/map/providers/map_engine_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('MapEngineState', () {
    test('uploadProgress/sceneReady reiniciam e propagam no copyWith', () {
      const state = MapEngineState(phase: MapLoading('Região', 0));
      expect(state.sceneReady, isFalse);
      expect(state.uploadProgress, 0);

      final uploading = state.copyWith(uploadProgress: 0.42);
      expect(uploading.uploadProgress, 0.42);
      expect(uploading.sceneReady, isFalse);

      final ready = uploading.copyWith(sceneReady: true);
      expect(ready.sceneReady, isTrue);
      expect(ready.uploadProgress, 0.42);

      // Nova carga zera a prontidão da cena.
      final reload = ready.copyWith(
        phase: const MapLoading('novo', 0),
        sceneReady: false,
        uploadProgress: 0,
      );
      expect(reload.sceneReady, isFalse);
      expect(reload.uploadProgress, 0);
    });

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

  group('focusCity', () {
    test('alvo no centro da caixa urbana e distância para enquadrá-la', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mapEngineProvider.notifier);
      notifier.engine = fogoEngineOfTest;

      notifier.focusCity(RegionCatalog.marilia);
      final state = container.read(mapEngineProvider);
      expect(state.focusLat, closeTo(-22.2175, 0.0001));
      expect(state.focusLng, closeTo(-49.95, 0.0001));
      expect(state.focusDistanceMeters, greaterThan(1000));
      // ~0,05° × ~0,035°: diagonal projetada ≈ 6 km, ×1,15 de margem.
      expect(state.focusDistanceMeters, lessThan(9000));
    });

    test('foco de busca limpa a distância fixada por cidade', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mapEngineProvider.notifier);
      notifier.engine = fogoEngineOfTest;

      notifier.focusCity(RegionCatalog.marilia);
      notifier.focusGeoPoint(-22.21, -49.94);
      final state = container.read(mapEngineProvider);
      expect(state.focusLat, -22.21);
      expect(state.focusLng, -49.94);
      expect(state.focusDistanceMeters, isNull);
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

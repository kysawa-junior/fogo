import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/domain/map_selection.dart';
import 'package:fogo/features/map/domain/road_filter.dart';
import 'package:fogo/features/map/providers/layers_provider.dart';
import 'package:fogo/features/map/providers/workspace_providers.dart';
import 'package:fogo/features/map/vector/vector_data.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('seleção (estado preservado para operações futuras)', () {
    test('seleciona, troca e limpa', () {
      final selection = container.read(selectionProvider.notifier);
      expect(container.read(selectionProvider), isA<NoSelection>());

      selection.selectPlace('op-001');
      expect(
        container.read(selectionProvider),
        isA<PlaceSelection>().having((s) => s.placeId, 'placeId', 'op-001'),
      );

      selection.clear();
      expect(container.read(selectionProvider), isA<NoSelection>());
    });
  });

  group('camadas da base real', () {
    test('edificações e rótulos ativos por padrão e alternáveis', () {
      expect(container.read(layersProvider), {
        MapLayerId.buildings,
        MapLayerId.labels,
      });
      container.read(layersProvider.notifier).toggle(MapLayerId.buildings);
      expect(container.read(layersProvider), {MapLayerId.labels});
      container.read(layersProvider.notifier).toggle(MapLayerId.buildings);
      expect(
        container.read(layersProvider).contains(MapLayerId.buildings),
        isTrue,
      );
    });

    test('camadas sem fonte não podem ser ativadas', () {
      container.read(layersProvider.notifier).toggle(MapLayerId.alerts);
      expect(
        container.read(layersProvider).contains(MapLayerId.alerts),
        isFalse,
      );
    });
  });

  group('filtro de vias por classe', () {
    test('vazio = todas visíveis', () {
      expect(
        roadFilterApplies(
          RoadClass.motorway,
          container.read(roadFilterProvider),
        ),
        isTrue,
      );
      expect(
        roadFilterApplies(
          RoadClass.residential,
          container.read(roadFilterProvider),
        ),
        isTrue,
      );
    });

    test('grupo selecionado filtra de verdade', () {
      container.read(roadFilterProvider.notifier).toggle(RoadFilterGroup.main);
      expect(
        roadFilterApplies(
          RoadClass.motorway,
          container.read(roadFilterProvider),
        ),
        isTrue,
      );
      expect(
        roadFilterApplies(
          RoadClass.residential,
          container.read(roadFilterProvider),
        ),
        isFalse,
      );
    });
  });

  group('modelo vetorial', () {
    test('código de classe de via converte com segurança', () {
      expect(roadClassFromCode(0), RoadClass.motorway);
      expect(roadClassFromCode(6), RoadClass.residential);
      expect(roadClassFromCode(99), RoadClass.other);
    });

    test('manifesto calcula índice de célula e cobertura', () {
      const manifest = MapManifest(
        version: 2,
        bbox: [-50.04, -22.31, -49.59, -22.13],
        tileBounds: MapTileBounds(
          west: -50.04,
          south: -22.31,
          east: -49.59,
          north: -22.13,
        ),
        cellSize: 0.05,
        cols: 9,
        rows: 4,
        attribution: '© OpenStreetMap contributors',
        source: 'test',
        generatedAt: 'test',
      );
      // Centro de Marília
      expect(manifest.cellIndex(-22.2172, -49.9500), (1, 1));
      // Centro de Garça
      expect(manifest.cellIndex(-22.2280, -49.6588), (7, 1));
      // Fora da cobertura
      expect(manifest.cellIndex(-23.0, -49.0), isNull);
      expect(manifest.covers(-22.22, -49.9), isTrue);
      expect(manifest.covers(-23.0, -49.0), isFalse);
    });

    test('célula l0 decodifica feições reais (formato v2)', () {
      final MapCellData cell = MapCellData.l0FromJson({
        'roads': [
          {
            'c': 0,
            'n': 'Rodovia SP-333',
            'r': 'SP-333',
            'o': 1,
            'br': 1,
            'tn': 0,
            'p': [-22.22, -49.8, -22.22, -49.79],
            'b': [-22.22, -49.8, -22.22, -49.79],
          },
        ],
        'areas': [
          {
            'k': 0,
            'p': [
              -22.20,
              -49.70,
              -22.19,
              -49.70,
              -22.19,
              -49.69,
              -22.20,
              -49.69,
            ],
            'b': [-22.20, -49.70, -22.19, -49.69],
          },
        ],
        'rail': [
          {
            'p': [-22.21, -49.66, -22.20, -49.65],
            'b': [-22.21, -49.66, -22.20, -49.65],
          },
        ],
        'wl': [
          {
            'k': 0,
            'n': 'Córrego',
            'p': [-22.20, -49.64, -22.19, -49.63],
            'b': [-22.20, -49.64, -22.19, -49.63],
          },
        ],
        'pois': [
          {'k': 0, 'x': -22.21, 'y': -49.65, 'n': 'Hospital'},
        ],
        'labels': [
          {'k': 0, 'x': -22.21, 'y': -49.65, 'n': 'Marília'},
        ],
      });
      expect(cell.roads.single.cls, RoadClass.motorway);
      expect(cell.roads.single.name, 'Rodovia SP-333');
      expect(cell.roads.single.ref, 'SP-333');
      expect(cell.roads.single.oneway, isTrue);
      expect(cell.roads.single.bridge, isTrue);
      expect(cell.roads.single.tunnel, isFalse);
      expect(cell.areas.single.kind, AreaKind.water);
      expect(cell.pois.single.name, 'Hospital');
      expect(cell.labels.single.text, 'Marília');
      expect(cell.rails.single.pointCount, 2);
      expect(cell.waterLines.single.kind, WaterLineKind.river);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';

import 'test_support.dart';

void main() {
  group('manifest validation and cell addressing', () {
    test('accepts a valid grid and exact coverage edges', () {
      final FogoMapManifest manifest = FogoMapManifest.fromJson(manifestJson());

      expect(
        manifest.bounds,
        const FogoGeoBounds(west: -2, south: -2, east: 2, north: 2),
      );
      expect(manifest.cellIndex(const FogoCoordinate(-2, -2)), (0, 0));
      expect(manifest.cellIndex(const FogoCoordinate(2, 2)), (3, 3));
      expect(manifest.cellIndex(const FogoCoordinate(0, 0)), (2, 2));
      expect(manifest.cellIndex(const FogoCoordinate(2.001, 0)), isNull);
      expect(manifest.cellIndex(const FogoCoordinate(0, -2.001)), isNull);
    });

    test(
      'rejects malformed bounds, mismatched bounds, and undersized grids',
      () {
        final Map<String, Object?> valid = manifestJson();
        expect(
          () => FogoMapManifest.fromJson({
            ...valid,
            'bbox': [-2, -2, 2],
          }),
          throwsFormatException,
        );
        expect(
          () => FogoMapManifest.fromJson({
            ...valid,
            'tileBounds': {'west': -2, 'south': -2, 'east': 1, 'north': 2},
          }),
          throwsFormatException,
        );
        expect(
          () => FogoMapManifest.fromJson({...valid, 'cols': 3}),
          throwsFormatException,
        );
        expect(
          () => FogoMapManifest.fromJson({...valid, 'cellSize': 0}),
          throwsFormatException,
        );
        expect(
          () => FogoMapManifest.fromJson({...valid, 'rows': 4.0}),
          throwsFormatException,
        );
      },
    );
  });

  test(
    'only positive finite numeric height values produce extrusion height',
    () {
      final List<Map<String, Object?>> records = [
        areaRecord(height: 12),
        areaRecord(),
        areaRecord(height: '12'),
        areaRecord(height: 0),
        areaRecord(height: -2),
        areaRecord(height: double.infinity),
        {...areaRecord(), 'levels': 3},
      ];
      final FogoMapCellData cell = FogoMapCellData.l1FromJson({'bld': records});

      expect(cell.buildings.map((area) => area.heightMeters).toList(), [
        12,
        null,
        null,
        null,
        null,
        null,
        null,
      ]);
    },
  );

  group('local cell source', () {
    test(
      'loads a validated manifest and reports typed corrupt-cell errors',
      () async {
        const String manifestPath = 'assets/map/manifest.json';
        const String corruptPath = 'assets/map/cells/l0_0_0.json.gz';
        final MemoryAssetBundle bundle = MemoryAssetBundle({
          manifestPath: utf8.encode(jsonEncode(manifestJson())),
          corruptPath: [0x1f, 0x8b, 0x00],
        });
        final FogoMapDataSource source = FogoMapDataSource(assetBundle: bundle);
        final FogoMapManifest manifest = await source.loadManifest();
        expect(manifest.bounds.west, -2);

        await expectLater(
          source.loadCell(FogoCellTier.l0, 0, 0),
          throwsA(
            isA<FogoMapDataException>().having(
              (error) => error.error,
              'typed cell error',
              isA<FogoMapDataError>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    FogoMapDataErrorKind.cell,
                  )
                  .having((error) => error.tier, 'tier', FogoCellTier.l0)
                  .having((error) => error.x, 'x', 0)
                  .having((error) => error.y, 'y', 0),
            ),
          ),
        );
        await expectLater(
          source.loadCell(FogoCellTier.l0, 0, 0),
          throwsA(isA<FogoMapDataException>()),
          reason: 'failed decode must not cache partial data',
        );
        expect(
          bundle.loadRequests.where((path) => path == corruptPath),
          hasLength(2),
        );
      },
    );

    test(
      'bounds both tier caches and evicts least-recently-used cells',
      () async {
        final Map<String, List<int>> assets = {
          'assets/map/manifest.json': utf8.encode(
            jsonEncode(
              manifestJson(
                west: 0,
                south: 0,
                east: 3.25,
                north: 0.05,
                cellSize: 0.05,
                columns: 65,
                rows: 1,
              ),
            ),
          ),
        };
        for (int x = 0; x < 65; x++) {
          final List<int> bytes = gzipJson({});
          assets['assets/map/cells/l0_${x}_0.json.gz'] = bytes;
          if (x < 25) assets['assets/map/cells/l1_${x}_0.json.gz'] = bytes;
        }
        final MemoryAssetBundle bundle = MemoryAssetBundle(assets);
        final FogoMapDataSource source = FogoMapDataSource(assetBundle: bundle);
        await source.loadManifest();

        for (int x = 0; x < FogoMapDataSource.l0CacheLimit; x++) {
          await source.loadCell(FogoCellTier.l0, x, 0);
        }
        await source.loadCell(FogoCellTier.l0, 0, 0); // refresh LRU position
        await source.loadCell(
          FogoCellTier.l0,
          FogoMapDataSource.l0CacheLimit,
          0,
        );
        await source.loadCell(FogoCellTier.l0, 0, 0); // still cached
        await source.loadCell(FogoCellTier.l0, 1, 0); // evicted, reload

        for (int x = 0; x < FogoMapDataSource.l1CacheLimit; x++) {
          await source.loadCell(FogoCellTier.l1, x, 0);
        }
        await source.loadCell(FogoCellTier.l1, 0, 0);
        await source.loadCell(
          FogoCellTier.l1,
          FogoMapDataSource.l1CacheLimit,
          0,
        );
        await source.loadCell(FogoCellTier.l1, 0, 0); // refreshed entry remains
        await source.loadCell(
          FogoCellTier.l1,
          1,
          0,
        ); // least-recently-used reload

        int requests(String path) =>
            bundle.loadRequests.where((request) => request == path).length;
        expect(requests('assets/map/cells/l0_0_0.json.gz'), 1);
        expect(requests('assets/map/cells/l0_1_0.json.gz'), 2);
        expect(
          requests(
            'assets/map/cells/l0_${FogoMapDataSource.l0CacheLimit}_0.json.gz',
          ),
          1,
        );
        expect(requests('assets/map/cells/l1_0_0.json.gz'), 1);
        expect(requests('assets/map/cells/l1_1_0.json.gz'), 2);
        expect(
          requests(
            'assets/map/cells/l1_${FogoMapDataSource.l1CacheLimit}_0.json.gz',
          ),
          1,
        );
      },
    );

    test(
      'treats out-of-grid and missing cells as normal empty coverage',
      () async {
        final MemoryAssetBundle bundle = MemoryAssetBundle({
          'assets/map/manifest.json': utf8.encode(jsonEncode(manifestJson())),
        });
        final FogoMapDataSource source = FogoMapDataSource(assetBundle: bundle);
        await source.loadManifest();

        expect(await source.loadCell(FogoCellTier.l0, -1, 0), isNull);
        expect(await source.loadCell(FogoCellTier.l0, 0, 0), isNull);
        expect(await source.loadCell(FogoCellTier.l0, 0, 0), isNull);
        expect(
          bundle.loadRequests.where(
            (path) => path == 'assets/map/cells/l0_0_0.json.gz',
          ),
          hasLength(1),
        );
      },
    );
  });
}

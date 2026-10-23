import 'dart:convert';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('FogoEngine end-to-end (bytes OSM → cena)', () {
    test('constrói motor completo a partir da fixture', () {
      final engine = FogoEngine.build(fixtureBytes());
      expect(engine, isNotNull);
      final stats = engine!.stats;
      // way 15 (ref pendente → 1 ponto) é descartada com issue.
      expect(stats.roadCount, 5, reason: 'ways 10..14 têm highway válida');
      expect(stats.buildingCount, 2);
      expect(stats.landAreaCount, 1);
      expect(stats.crossingCount, 1);
      expect(stats.signalCount, 1);
      expect(stats.meshObjectCount, 10);
      expect(stats.triangleCount, greaterThan(0));
    });

    test('todas as malhas são válidas: índices no range e valores finitos', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      for (final obj in engine.scene.objects) {
        expect(
          obj.mesh.isValid,
          isTrue,
          reason: '${obj.entityId} deve produzir malha válida',
        );
      }
    });

    test('elevação por camada: ponte acima, túnel abaixo do solo', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      double yOf(String id) {
        final obj = engine.scene.objects
            .singleWhere((o) => o.entityId == id)
            .mesh
            .computeBounds()!;
        return obj.min.y;
      }

      expect(yOf('way/13'), closeTo(4, 1e-6), reason: 'layer 1 → +4 m');
      expect(yOf('way/14'), closeTo(-4, 1e-6), reason: 'layer -1 → -4 m');
      expect(yOf('way/10'), 0);
    });

    test(
      'particionamento: tiles agrupam objetos, dono = tile do centroide',
      () {
        final engine = FogoEngine.build(fixtureBytes())!;
        expect(engine.scene.tileIds, isNotEmpty);
        for (final obj in engine.scene.objects) {
          expect(
            engine.tileManager.ownerTileOf(obj.entityId),
            isNotNull,
            reason: 'todo objeto tem tile dono',
          );
          expect(engine.scene.tileIds, contains(obj.tileId));
        }
        // Via longa (way 10) atravessa múltiplos tiles: registrada em todos
        // os tiles tocados, mas com UM único dono.
        final touched = engine.tileManager.tiles.values
            .where((t) => t.entityIds.contains('way/10'))
            .toList();
        expect(
          touched.length,
          greaterThanOrEqualTo(2),
          reason: 'via atravessa fronteiras de tiles',
        );
      },
    );

    test('gzip: mesma cena a partir de .osm.gz', () {
      final plain = FogoEngine.build(fixtureBytes())!;
      final gz = FogoEngine.build(fixtureGzipBytes())!;
      expect(gz.stats.meshObjectCount, plain.stats.meshObjectCount);
      expect(gz.stats.triangleCount, plain.stats.triangleCount);
    });

    test('arquivo vazio/não-OSM retorna null sem exceção', () {
      expect(FogoEngine.build(_bytes('nada aqui')), isNull);
    });

    test('cores por tipo: malhas recebem cor da paleta', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final building = engine.scene.objects.firstWhere(
        (o) => o.kind == SceneObjectKind.building,
      );
      final buildingColor = building.color;
      final palette = FogoPalette.building;
      expect(buildingColor.x, palette.x);
      expect(buildingColor.y, palette.y);
      expect(buildingColor.z, palette.z);
      final crossing = engine.scene.objects.singleWhere(
        (o) => o.kind == SceneObjectKind.crossing,
      );
      expect(crossing.color.x, FogoPalette.crossing.x);
      expect(crossing.color.y, FogoPalette.crossing.y);
      expect(crossing.color.z, FogoPalette.crossing.z);
    });

    test('issues de importação ficam expostas (refs ausentes)', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      expect(engine.issues.any((i) => i.message.contains('999')), isTrue);
    });

    test('seleção por id: byId recupera a entidade correta', () {
      final engine = FogoEngine.build(fixtureBytes())!;
      final feature = engine.model.byId('way/10')!;
      expect(feature.tags['name'], 'Rua Reta');
      expect(engine.model.byId('way/999'), isNull);
    });
  });
}

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

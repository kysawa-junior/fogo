import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/engine/scene/lod_policy.dart';

/// TASK-0011: pads planos por tile — fallback dos volumes fora do raio.
void main() {
  final engine = FogoEngine.build(Uint8List.fromList(utf8.encode(_osm)))!;

  test('todo tile com volume gated tem um batch de pad plano', () {
    final scene = engine.scene;
    expect(scene.buildingFootprints, isNotEmpty);

    final padTiles = {
      for (final batch in scene.buildingFootprints) batch.tileId,
    };
    final gatedTiles = <String>{
      for (final obj in scene.objects)
        if (obj.rangeGated) obj.tileId,
    };
    expect(gatedTiles, isNotEmpty);
    for (final tileId in gatedTiles) {
      expect(
        padTiles,
        contains(tileId),
        reason: 'tile $tileId tem volumes gated e precisa de pad',
      );
    }
    for (final batch in scene.buildingFootprints) {
      expect(scene.tileIds, contains(batch.tileId));
      expect(batch.mesh.isValid, isTrue);
      expect(batch.mesh.vertexCount, greaterThan(0));
      // Pad plano ao solo: tudo em +Y.
      for (var i = 0; i < batch.mesh.vertexCount; i++) {
        expect(
          batch.mesh.positions[i * 3 + 1],
          lessThan(1),
          reason: 'pad no nível do solo',
        );
      }
    }
  });

  test('volumes de prédio são rangeGated; landmarks não', () {
    final gated = engine.scene.objects.where((o) => o.rangeGated).toList();
    expect(gated, isNotEmpty);
    for (final obj in gated) {
      expect(obj.kind, SceneObjectKind.building);
    }
    // amenity=police (landmark) continua sem gate.
    final police = engine.scene.objects.where(
      (o) => o.entityId.contains('way/200'),
    );
    expect(police, isNotEmpty);
    for (final obj in police) {
      expect(obj.kind, SceneObjectKind.building);
      expect(obj.rangeGated, isFalse, reason: 'landmark fora do gate');
    }
  });

  test('pads não vazam para a cena 2D', () {
    // Modo 2D continua com APENAS os fills de footprint por prédio.
    final buildings = engine.model.buildings.length;
    expect(
      engine.map2d.fills.where((f) => f.footprint).length,
      buildings,
      reason: 'um fill por prédio, nada a mais',
    );
  });

  test('constantes do gate: 600 m com histerese de 100 m', () {
    expect(LodPolicy.buildingVolumeRadiusMeters, 600);
    expect(LodPolicy.buildingVolumeHysteresisMeters, 100);
  });
}

const _osm = '''
<osm version="0.6">
  <node id="1" lat="-22.220" lon="-49.970"/>
  <node id="2" lat="-22.220" lon="-49.969"/>
  <node id="3" lat="-22.219" lon="-49.969"/>
  <node id="4" lat="-22.219" lon="-49.970"/>
  <node id="5" lat="-22.220" lon="-49.968"/>
  <node id="6" lat="-22.220" lon="-49.967"/>
  <node id="7" lat="-22.219" lon="-49.967"/>
  <node id="8" lat="-22.219" lon="-49.968"/>
  <way id="100">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/>
    <tag k="building" v="yes"/>
  </way>
  <way id="200">
    <nd ref="5"/><nd ref="6"/><nd ref="7"/><nd ref="8"/><nd ref="5"/>
    <tag k="amenity" v="police"/>
  </way>
</osm>
''';

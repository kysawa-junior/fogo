import 'dart:convert';
import 'dart:typed_data';

import 'package:fogo/engine/domain/land_area.dart' show LandAreaKind;
import 'package:fogo/engine/domain/road_type.dart' show RoadType;
import 'package:fogo/engine/osm/map_topology_builder.dart';
import 'package:fogo/engine/osm/osm_elements.dart';
import 'package:fogo/engine/osm/osm_feature_mapper.dart';
import 'package:fogo/engine/osm/osm_xml_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart' show XmlParserException;

import 'fixtures.dart';

void main() {
  group('OsmXmlReader', () {
    test('lê nodes, ways e relations preservando ids e tags', () {
      final store = OsmDataStore();
      OsmXmlReader.read(fixtureBytes(), store);
      expect(store.nodeCount, greaterThanOrEqualTo(24));
      expect(store.wayCount, 11);
      expect(store.relationCount, 1);

      final way = store.wayById(10)!;
      expect(way.nodeRefs, [1, 2, 3, 4], reason: 'ordem dos nd preservada');
      expect(way.tags['highway'], 'residential');
      expect(way.tags['name'], 'Rua Reta');

      final node = store.nodeById(2)!;
      expect(node.tags['highway'], 'crossing');
      expect(node.lat, closeTo(-22.22, 1e-9));

      final rel = store.relationById(30)!;
      expect(rel.members.length, 2);
      expect(rel.members.first.role, 'outer');
      expect(rel.tags['type'], 'multipolygon');
    });

    test('nó com id inválido gera issue, não exceção', () {
      final store = OsmDataStore();
      OsmXmlReader.read(fixtureBytes(), store);
      expect(store.nodeById(-1), isNull);
      expect(
        store.issues.any((i) => i.message.contains('id inválido')),
        isTrue,
      );
    });

    test('suporta .osm.gz (gzip transparente)', () {
      final plain = OsmDataStore();
      final gzipped = OsmDataStore();
      OsmXmlReader.read(fixtureBytes(), plain);
      OsmXmlReader.read(fixtureGzipBytes(), gzipped);
      expect(gzipped.nodeCount, plain.nodeCount);
      expect(gzipped.wayCount, plain.wayCount);
      expect(gzipped.wayById(10)!.tags['name'], 'Rua Reta');
    });

    test('reporta progresso', () {
      final store = OsmDataStore();
      final phases = <String>[];
      OsmXmlReader.read(
        fixtureBytes(),
        store,
        onProgress: (phase, count) => phases.add(phase),
      );
      expect(phases, contains('OSM lido'));
    });

    test('XML malformado lança (arquivo, não elemento)', () {
      final store = OsmDataStore();
      expect(
        () => OsmXmlReader.read(
          Uint8List.fromList(utf8.encode('<osm><node id="1"')),
          store,
        ),
        throwsA(isA<XmlParserException>()),
      );
    });
  });

  group('OsmFeatureMapper', () {
    OsmDataStore readFixture() {
      final store = OsmDataStore();
      OsmXmlReader.read(fixtureBytes(), store);
      return store;
    }

    test('mapeia vias com tipo, nome e ordem dos pontos', () {
      final model = OsmFeatureMapper().map(readFixture());
      final road = model.roads.firstWhere((r) => r.id == 'way/10');
      expect(road.name, 'Rua Reta');
      expect(road.type, RoadType.residential);
      expect(road.points.length, 4);
      expect(road.points.first.longitude, closeTo(-49.95, 1e-9));
      expect(road.nodeRefs, [1, 2, 3, 4]);
    });

    test('distingue known/estimated/defaulted em largura e altura', () {
      final model = OsmFeatureMapper().map(readFixture());
      final reta = model.roads.firstWhere((r) => r.id == 'way/10');
      expect(reta.properties.widthMeters!.isKnown, isTrue);
      expect(reta.properties.widthMeters!.value, 7);

      final curva = model.roads.firstWhere((r) => r.id == 'way/11');
      expect(
        curva.properties.widthMeters!.isDefaulted,
        isTrue,
        reason: 'sem width nem lanes → padrão do tipo',
      );

      final transversal = model.roads.firstWhere((r) => r.id == 'way/12');
      expect(transversal.properties.widthMeters!.isEstimated, isTrue);
      expect(transversal.properties.widthMeters!.raw, 'lanes=2');

      final known = model.buildings.firstWhere((b) => b.id == 'way/20');
      expect(known.height.isKnown, isTrue);
      expect(known.height.value, 12.5);

      final levels = model.buildings.firstWhere((b) => b.id == 'way/22');
      expect(levels.height.isEstimated, isTrue);
      expect(levels.height.raw, 'building:levels=3');
      expect(levels.height.value, closeTo(3 * 3.2, 1e-9));
    });

    test('propriedades de via: oneway, surface, layer, bridge, tunnel', () {
      final model = OsmFeatureMapper().map(readFixture());
      final transversal = model.roads.firstWhere((r) => r.id == 'way/12');
      expect(transversal.properties.oneway, isTrue);
      expect(transversal.properties.lanes, 2);

      final viaduto = model.roads.firstWhere((r) => r.id == 'way/13');
      expect(viaduto.properties.bridge, isTrue);
      expect(viaduto.properties.layer, 1);

      final tunnel = model.roads.firstWhere((r) => r.id == 'way/14');
      expect(tunnel.properties.tunnel, isTrue);
      expect(tunnel.properties.layer, -1);
    });

    test('travessia e semáforo ficam associados às vias do nó', () {
      final store = readFixture();
      final model = OsmFeatureMapper().map(store);
      final network = MapTopologyBuilder().build(model, store);

      final crossing = model.crossings.firstWhere((c) => c.id == 'node/2');
      expect(crossing.connectedWayIds, {
        'way/10',
        'way/12',
      }, reason: 'nó 2 pertence às duas vias');
      expect(crossing.headingRadians, isNotNull);

      final signal = model.signals.firstWhere((s) => s.id == 'node/26');
      expect(signal.connectedWayIds, {'way/12'});

      expect(network, isNotNull);
    });

    test('relation multipolygon vira área com buraco', () {
      final model = OsmFeatureMapper().map(readFixture());
      final area = model.landAreas.firstWhere((a) => a.id == 'relation/30');
      expect(area.name, 'Bosque');
      expect(area.kind, LandAreaKind.forest);
      expect(area.polygons.single.length, 2, reason: 'outer + inner');
    });

    test('way sem tags não vira entidade; way pendente não derruba', () {
      final store = readFixture();
      final model = OsmFeatureMapper().map(store);
      expect(model.byId('way/16'), isNull, reason: 'sem tags → nada');
      // way 15 tem ref 999 ausente: issue registrada, sem exceção.
      expect(store.issues.any((i) => i.message.contains('999')), isTrue);
    });

    test('elevação (ele) é preservada quando presente, nunca inventada', () {
      final xml = '''
<osm version="0.6">
  <node id="1" lat="-22.0" lon="-49.0">
    <tag k="ele" v="730.5"/>
  </node>
  <node id="2" lat="-22.0" lon="-48.999"/>
</osm>
''';
      final store = OsmDataStore();
      OsmXmlReader.read(Uint8List.fromList(utf8.encode(xml)), store);
      expect(store.nodeById(1)!.elevation, 730.5);
      expect(store.nodeById(2)!.elevation, isNull);
    });
  });
}

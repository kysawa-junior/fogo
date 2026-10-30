import 'dart:convert';
import 'dart:typed_data';

import 'package:fogo/engine/domain/land_area.dart' show LandAreaKind;
import 'package:fogo/engine/domain/road_type.dart' show RoadType;
import 'package:fogo/engine/load_progress.dart';
import 'package:fogo/engine/osm/map_topology_builder.dart';
import 'package:fogo/engine/osm/osm_elements.dart';
import 'package:fogo/engine/osm/osm_feature_mapper.dart'
    show BuildingHeightEstimator, OsmFeatureMapper;
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
      // 31 originais + ESTÁDIO way/80 + pitch way/81 (ENG tigela 3D).
      expect(store.wayCount, 33);
      expect(store.relationCount, 2);

      final way = store.wayById(10)!;
      expect(
        way.nodeRefs,
        [1, 99, 2, 3, 101, 4],
        reason:
            'ordem dos nd preservada (com stop e level crossing '
            'intercalados na ETAPA 05)',
      );
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

    test('reporta progresso com fração real e crescente', () {
      final store = OsmDataStore();
      final phases = <String>[];
      final fractions = <double>[];
      OsmXmlReader.read(
        fixtureBytes(),
        store,
        progress: LoadProgress((phase, count, fraction) {
          phases.add(phase);
          fractions.add(fraction);
        }),
      );
      expect(phases, contains('Interpretando OSM'));
      expect(fractions.last, greaterThan(0));
      expect(fractions.last, lessThanOrEqualTo(1));
      for (var i = 1; i < fractions.length; i++) {
        expect(fractions[i], greaterThanOrEqualTo(fractions[i - 1]));
      }
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

  group('BuildingHeightEstimator (ETAPA 03)', () {
    final est = BuildingHeightEstimator();

    test('height explícito vence tudo (conhecido)', () {
      final h = est.estimate({'building': 'house', 'height': '25'});
      expect(h.isKnown, isTrue);
      expect(h.value, 25);
    });

    test('levels estimado; roof:levels/roof:height somam', () {
      final h = est.estimate({'building:levels': '3'});
      expect(h.isEstimated, isTrue);
      expect(h.value, closeTo(9.6, 1e-9));
      final hRoof = est.estimate({'building:levels': '2', 'roof:levels': '1'});
      expect(hRoof.value, closeTo(9.6, 1e-9));
      final hRh = est.estimate({'building:levels': '2', 'roof:height': '2.5'});
      expect(hRh.value, closeTo(8.9, 1e-9));
    });

    test('sem altura: categoria documentada, NUNCA valor universal', () {
      // Alturas distintas por categoria (calibradas com os dados
      // reais das três cidades; majoradas p/ presença 3D).
      expect(est.estimate({'building': 'house'}).value, 6);
      expect(est.estimate({'building': 'church'}).value, 18);
      expect(est.estimate({'building': 'apartments'}).value, 16);
      expect(est.estimate({'building': 'school'}).value, 10.5);
      expect(est.estimate({'building': 'hangar'}).value, 13.5);
      expect(est.estimate({'building': 'shed'}).value, 3.5);
      expect(est.estimate({'building': 'roof'}).value, 3.5);
      // Genérico (yes: 637/653 em Garça) tem o PRÓPRIO padrão.
      expect(est.estimate({'building': 'yes'}).value, 9);
      // Categoria desconhecida cai no genérico, não numa constante
      // mágica universal.
      expect(est.estimate({'building': 'monumento_exotico'}).value, 9);
      // Todos defaulted — origem explícita na UI.
      expect(est.estimate({'building': 'church'}).isDefaulted, isTrue);
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
      expect(road.points.length, 6);
      expect(road.points.first.longitude, closeTo(-49.95, 1e-9));
      expect(road.nodeRefs, [1, 99, 2, 3, 101, 4]);
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
      // Modelo CRU (este teste usa o mapper direto): a duplicata
      // way/42 ainda está presente — o pipeline a remove depois.
      expect(crossing.connectedWayIds, {
        'way/42',
        'way/10',
        'way/12',
      }, reason: 'nó 2 pertence às vias (incl. duplicata crua)');
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

    test('amenity de edifício de interesse não cai em "other"', () {
      expect(
        LandAreaKind.fromTags({'amenity': 'fuel'}),
        LandAreaKind.fuelStation,
      );
      expect(LandAreaKind.fromTags({'amenity': 'police'}), LandAreaKind.police);
      expect(
        LandAreaKind.fromTags({'amenity': 'clinic'}),
        LandAreaKind.hospital,
      );
      expect(
        LandAreaKind.fromTags({'amenity': 'place_of_worship'}),
        LandAreaKind.placeOfWorship,
      );
      expect(
        LandAreaKind.fromTags({'amenity': 'parking'}),
        LandAreaKind.parking,
      );
      // Sem tag conhecida: segue "other" (rótulo PT, sem classe falsa).
      expect(LandAreaKind.fromTags({}), LandAreaKind.other);
      expect(LandAreaKind.other.label, 'Outros');
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

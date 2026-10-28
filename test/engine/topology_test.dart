import 'package:fogo/engine/domain/road_network.dart' show RoadNetwork;
import 'package:fogo/engine/osm/map_topology_builder.dart';
import 'package:fogo/engine/osm/osm_elements.dart';
import 'package:fogo/engine/osm/osm_feature_mapper.dart';
import 'package:fogo/engine/osm/road_deduplicator.dart';
import 'package:fogo/engine/osm/osm_xml_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  late OsmDataStore store;
  late MapModel model;
  late RoadNetwork network;

  setUpAll(() {
    store = OsmDataStore();
    OsmXmlReader.read(fixtureBytes(), store);
    model = OsmFeatureMapper().map(store);
    // Modelo DEDUPLICADO — o mesmo caminho do pipeline real
    // (FogoEngine.build): a duplicata comprovada (way/42) sai ANTES da
    // topologia, exatamente como na aplicação.
    final dedup = RoadDeduplicator.dedupe(model.roads, store);
    model.roads
      ..clear()
      ..addAll(dedup.roads);
    model.indexAll();
    network = MapTopologyBuilder().build(model, store);
  });

  test('nó compartilhado conecta vias (junção real)', () {
    final junction = network.nodes['node/2'];
    expect(junction, isNotNull);
    expect(junction!.isJunction, isTrue, reason: 'way 10 e way 12 o contêm');
    // Modelo DEDUPLICADO (como o pipeline): a duplicata way/42 já saiu.
    expect(junction.wayIds, {'way/10', 'way/12'});

    // Conectividade: node/1 e node/9 estão ligados via segmentos de
    // way/10 + way/12 passando por node/2. node/26 (semáforo) é nó
    // interior de way/12 e não divide o segmento — junções são apenas
    // nós COMPARTILHADOS.
    final fromOne = network.neighborNodeIds('node/1').toSet();
    expect(fromOne, contains('node/2'));
    // Modelo CRU: a duplicata way/42 (mesmos nós da way/10) torna os
    // nós internos 3 e 4 junções — vizinhos diretos de node/2 mudam.
    // O pipeline completo deduplica antes da topologia (ver
    // fogo_engine_test).
    final fromTwo = network.neighborNodeIds('node/2').toSet();
    expect(fromTwo, containsAll(['node/1', 'node/101', 'node/9']));
  });

  test('cruzamento geométrico sem nó compartilhado NÃO conecta', () {
    // way 13 (viaduto) cruza way 10 visualmente; nenhuma areta deve
    // conectar seus nós aos de way 10.
    final bridgeNeighbors = <String>{
      ...network.neighborNodeIds('node/10'),
      ...network.neighborNodeIds('node/11'),
    };
    expect(
      bridgeNeighbors.intersection({'node/1', 'node/2', 'node/3', 'node/4'}),
      isEmpty,
      reason: 'viaduto sem nó compartilhado: sem conexão topológica',
    );
    // E o nó do viaduto não é junção.
    expect(network.nodes['node/10']!.isJunction, isFalse);
  });

  test('segmentos têm ids estáveis e geometria preservada na via', () {
    final way10Segments = network.segments.values
        .where((s) => s.roadId == 'way/10')
        .toList();
    // way 10: nós 1,99,2,3,101,4 (dedup); junções em 2 (way/12) e 101
    // (way/61, cruzamento ferroviário) → [1..2], [2..101], [101..4].
    expect(way10Segments.length, 3);
    final segIds = way10Segments.map((s) => s.id).toSet();
    expect(segIds.length, 3, reason: 'ids estáveis e distintos');
    final road = model.roads.firstWhere((r) => r.id == 'way/10');
    for (final seg in way10Segments) {
      expect(seg.pointStart, lessThan(seg.pointEnd));
      expect(seg.pointEnd, lessThan(road.points.length));
      expect(
        road.nodeRefs[seg.pointStart],
        int.parse(seg.startNodeId.split('/').last),
      );
      expect(
        road.nodeRefs[seg.pointEnd],
        int.parse(seg.endNodeId.split('/').last),
      );
    }
  });

  test('travessia e semáforo conectados às vias corretas', () {
    final crossing = model.crossings.singleWhere((c) => c.id == 'node/2');
    expect(crossing.connectedWayIds, {'way/10', 'way/12'});
    expect(crossing.headingRadians, isNotNull);

    final signal = model.signals.singleWhere((s) => s.id == 'node/26');
    expect(signal.connectedWayIds, {'way/12'});
  });

  test('referência pendente registra issue sem derrubar a topologia', () {
    expect(store.issues.any((i) => i.message.contains('999')), isTrue);
    expect(
      network.segments.values.where((s) => s.roadId == 'way/15'),
      isEmpty,
      reason: 'via com 1 ponto válido não gera segmento',
    );
  });
}

// ignore_for_file: avoid_print, dangling_library_doc_comments
// Auditoria ETAPA 05 — ferrovias, travessias e sinalização nos extratos.
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';

void main() {
  for (final city in ['garca', 'vera-cruz', 'marilia']) {
    final bytes = File('assets/map/osm/$city.osm.gz').readAsBytesSync();
    final engine = FogoEngine.build(Uint8List.fromList(bytes));
    final store = engine!.store;

    final railWays = <String, int>{};
    var railNoHighway = 0, railWithLayer = 0, railWithBridge = 0;
    var levelCrossings = 0, tramStops = 0, platforms = 0, stations = 0;
    final crossingValues = <String, int>{};
    final crossingMarkings = <String, int>{};
    var stopNodes = 0, giveWayNodes = 0, trafficSigns = 0, trafficCalming = 0;
    final signals = engine.model.signals.length;
    final crossings = engine.model.crossings.length;

    for (final w in store.ways) {
      final rw = w.tags['railway'];
      if (rw != null) {
        railWays[rw] = (railWays[rw] ?? 0) + 1;
        if (w.tags['highway'] == null) railNoHighway++;
        if ((int.tryParse(w.tags['layer'] ?? '0') ?? 0) != 0) railWithLayer++;
        if (w.tags['bridge'] != null) railWithBridge++;
      }
      if (w.tags['railway'] == 'platform') platforms++;
      if (w.tags['railway'] == 'station') stations++;
      if (w.tags['railway'] == 'tram_stop' || w.tags['railway'] == 'halt') {
        tramStops++;
      }
    }
    for (final n in store.nodes) {
      final t = n.tags;
      if (t['railway'] == 'level_crossing') levelCrossings++;
      if (t['highway'] == 'crossing') {
        crossingValues[t['crossing'] ?? '(sem valor)'] =
            (crossingValues[t['crossing'] ?? '(sem valor)'] ?? 0) + 1;
        final mk = t['crossing:markings'];
        if (mk != null) crossingMarkings[mk] = (crossingMarkings[mk] ?? 0) + 1;
      }
      if (t['highway'] == 'stop') stopNodes++;
      if (t['highway'] == 'give_way') giveWayNodes++;
      if (t.containsKey('traffic_sign')) trafficSigns++;
      if (t.containsKey('traffic_calming')) trafficCalming++;
    }
    print('=== $city ===');
    print(
      'railway-ways: $railWays (sem highway: $railNoHighway, '
      'layer≠0: $railWithLayer, bridge: $railWithBridge)',
    );
    print(
      'level_crossing=$levelCrossings platform=$platforms '
      'station=$stations tram_stop=$tramStops',
    );
    print(
      'crossings(no modelo)=$crossings valores: $crossingValues '
      'markings: $crossingMarkings',
    );
    print(
      'signals=$signals stop=$stopNodes give_way=$giveWayNodes '
      'traffic_sign=$trafficSigns traffic_calming=$trafficCalming',
    );
  }
}

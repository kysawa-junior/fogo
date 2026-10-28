// ignore_for_file: avoid_print, dangling_library_doc_comments
// Auditoria ETAPA 04 — infraestrutura viária nos dados reais.
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';

void main() {
  for (final city in ['garca', 'vera-cruz', 'marilia']) {
    final bytes = File('assets/map/osm/$city.osm.gz').readAsBytesSync();
    final engine = FogoEngine.build(Uint8List.fromList(bytes));
    final store = engine!.store;

    var sidewalkTag = 0, sidewalkWays = 0, footwaySidewalk = 0;
    var bridgeNoLayer = 0, tunnelNoLayer = 0, bridgeTotal = 0, tunnelTotal = 0;
    var links = 0, nonZeroLayer = 0, embankment = 0;
    var parkingAreas = 0, pedestrianAreas = 0, trafficIsland = 0;
    var serviceWays = 0, areaHighway = 0;
    for (final w in store.ways) {
      final t = w.tags;
      final hw = t['highway'];
      if (t.containsKey('sidewalk')) sidewalkTag++;
      if (hw == 'sidewalk' || (hw == 'footway' && t['footway'] == 'sidewalk')) {
        sidewalkWays++;
      }
      if (hw == 'footway') footwaySidewalk++;
      if (t['bridge'] != null && t['bridge'] != 'no') {
        bridgeTotal++;
        final layer = int.tryParse(t['layer'] ?? '0') ?? 0;
        if (layer == 0) bridgeNoLayer++;
      }
      if (t['tunnel'] != null && t['tunnel'] != 'no') {
        tunnelTotal++;
        final layer = int.tryParse(t['layer'] ?? '0') ?? 0;
        if (layer == 0) tunnelNoLayer++;
      }
      if (hw != null && hw.endsWith('_link')) links++;
      final layer = int.tryParse(t['layer'] ?? '0') ?? 0;
      if (layer != 0) nonZeroLayer++;
      if (t.containsKey('embankment')) embankment++;
      if (t.containsKey('area:highway')) areaHighway++;
      if (hw == 'traffic_island' ||
          t['area:highway'] == 'traffic_island' ||
          (hw != null && t['area'] == 'yes' && hw.contains('island'))) {
        trafficIsland++;
      }
      if (hw == 'service') serviceWays++;
      if (t['amenity'] == 'parking' && w.isClosed) parkingAreas++;
      if ((hw == 'pedestrian' || t['area:highway'] == 'pedestrian') &&
          t['area'] == 'yes') {
        pedestrianAreas++;
      }
    }
    final parkingInModel = engine.model.landAreas
        .where((a) => a.kind.name == 'parking')
        .length;
    print('=== $city ===');
    print(
      'sidewalk-tag=$sidewalkTag, ways-sidewalk=$sidewalkWays, '
      'footway=$footwaySidewalk',
    );
    print(
      'bridge=$bridgeTotal (SEM layer: $bridgeNoLayer), '
      'tunnel=$tunnelTotal (SEM layer: $tunnelNoLayer), '
      'layer≠0=$nonZeroLayer, links=$links, embankment=$embankment',
    );
    print(
      'service=$serviceWays, traffic_island=$trafficIsland, '
      'area:highway=$areaHighway',
    );
    print(
      'parking-fechado=$parkingAreas (no modelo: $parkingInModel), '
      'pedestrian-area=$pedestrianAreas',
    );
  }
}

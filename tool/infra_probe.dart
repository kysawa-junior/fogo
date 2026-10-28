// ignore_for_file: avoid_print, dangling_library_doc_comments
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';

void main() {
  // Garça: parking fechado fora do modelo.
  final g = File('assets/map/osm/garca.osm.gz').readAsBytesSync();
  final eg = FogoEngine.build(Uint8List.fromList(g))!;
  for (final w in eg.store.ways) {
    if (w.tags['amenity'] == 'parking' && w.isClosed) {
      final inModel = eg.model.landAreas.any((a) => a.id == 'way/${w.id}');
      if (!inModel) {
        print(
          'garca parking way/${w.id}: nós=${w.nodeRefs.length} '
          'tags=${w.tags}',
        );
      }
    }
  }
  // Marília: valores de area:highway e traffic_island.
  final m = File('assets/map/osm/marilia.osm.gz').readAsBytesSync();
  final em = FogoEngine.build(Uint8List.fromList(m))!;
  final areaHw = <String, int>{};
  for (final w in em.store.ways) {
    final v = w.tags['area:highway'];
    if (v != null) areaHw[v] = (areaHw[v] ?? 0) + 1;
  }
  print('marilia area:highway valores: $areaHw');
  for (final w in em.store.ways) {
    if (w.tags['highway'] == 'traffic_island') {
      print(
        'marilia traffic_island way/${w.id}: fechado=${w.isClosed} '
        'area=${w.tags['area']} nós=${w.nodeRefs.length}',
      );
    }
  }
  // Túnel sem layer (Garça).
  for (final w in eg.store.ways) {
    final t = w.tags;
    if (t['tunnel'] != null &&
        t['tunnel'] != 'no' &&
        (int.tryParse(t['layer'] ?? '0') ?? 0) == 0) {
      print(
        'garca túnel SEM layer: way/${w.id} highway=${t['highway']} '
        'tunnel=${t['tunnel']}',
      );
    }
  }
}

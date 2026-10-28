// ignore_for_file: avoid_print, dangling_library_doc_comments
// Auditoria ETAPA 06 — áreas, vegetação, hidrografia e mobiliário.
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';

void main() {
  for (final city in ['garca', 'vera-cruz', 'marilia']) {
    final bytes = File('assets/map/osm/$city.osm.gz').readAsBytesSync();
    final engine = FogoEngine.build(Uint8List.fromList(bytes));
    final store = engine!.store;

    // Áreas verdes: contar por kind do modelo.
    final kinds = <String, int>{};
    for (final a in engine.model.landAreas) {
      kinds[a.kind.name] = (kinds[a.kind.name] ?? 0) + 1;
    }

    // Árvores individuais (natural=tree), bancos, postes, etc.
    var trees = 0, benches = 0, streetLamps = 0, waste = 0, shelters = 0;
    var otherAmenity = 0;
    final treeSpecies = <String, int>{};
    for (final n in store.nodes) {
      final t = n.tags;
      if (t['natural'] == 'tree') {
        trees++;
        final sp = t['species'] ?? t['leaf_type'] ?? '(sem espécie)';
        treeSpecies[sp] = (treeSpecies[sp] ?? 0) + 1;
      }
      if (t['amenity'] == 'bench') benches++;
      if (t['highway'] == 'street_lamp') {
        streetLamps++;
      }
      if (t['amenity'] == 'waste_basket') {
        waste++;
      }
      if (t['public_transport'] == 'platform' || t['amenity'] == 'shelter') {
        shelters++;
      }
      if (t['amenity'] != null && t['amenity'] != 'parking') otherAmenity++;
    }

    // Hidrografia: ways lineares (waterway) + polígonos (natural=water).
    final waterways = <String, int>{};
    var waterAreas = 0;
    for (final w in store.ways) {
      if (w.tags.containsKey('waterway')) {
        waterways[w.tags['waterway']!] =
            (waterways[w.tags['waterway']!] ?? 0) + 1;
      }
      if (w.tags['natural'] == 'water' || w.tags['water'] != null) waterAreas++;
    }

    // Áreas com trees dentro (amostra: parques).
    final parks = engine.model.landAreas
        .where((a) => a.kind.name == 'park' || a.kind.name == 'forest')
        .length;

    print('=== $city ===');
    print('áreas: $kinds (parques+florestas: $parks)');
    print(
      'árvores=$trees espécies: $treeSpecies | bancos=$benches '
      'postes=$streetLamps lixeiras=$waste abrigos=$shelters '
      'outros-amenity=$otherAmenity',
    );
    print('waterways: $waterways | waterAreas(polygons)=$waterAreas');
  }
}

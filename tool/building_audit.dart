// ignore_for_file: avoid_print, dangling_library_doc_comments
// Auditoria ETAPA 03 — categorias de edifícios, parts e alturas nos dados.
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';

void main() {
  for (final city in ['garca', 'vera-cruz', 'marilia']) {
    final bytes = File('assets/map/osm/$city.osm.gz').readAsBytesSync();
    final engine = FogoEngine.build(Uint8List.fromList(bytes));
    final buildings = engine!.model.buildings;
    final cats = <String, int>{};
    var withHeight = 0, withLevels = 0, noInfo = 0, withMinHeight = 0;
    var withRoofInfo = 0, parts = 0, multiOuter = 0;
    for (final b in buildings) {
      final c = b.tags['building'] ?? '?';
      cats[c] = (cats[c] ?? 0) + 1;
      if (b.tags.containsKey('height')) withHeight++;
      if (b.tags.containsKey('building:levels')) withLevels++;
      if (b.tags.containsKey('min_height')) withMinHeight++;
      if (b.tags.containsKey('roof:shape') ||
          b.tags.containsKey('roof:height') ||
          b.tags.containsKey('roof:levels')) {
        withRoofInfo++;
      }
      if (!b.tags.containsKey('height') &&
          !b.tags.containsKey('building:levels')) {
        noInfo++;
      }
    }
    // building:part e relações multi-outer: conta no store cru.
    for (final w in engine.store.ways) {
      if (w.tags['building:part'] == 'yes') parts++;
    }
    for (final r in engine.store.relations) {
      if (r.tags['type'] == 'multipolygon' &&
          (r.tags['building'] != null || r.tags['building:part'] != null)) {
        final outers = r.members.where((m) => m.role == 'outer').length;
        if (outers > 1) multiOuter++;
      }
    }
    print('=== $city: ${buildings.length} edifícios ===');
    final sorted = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    print('categorias: $sorted');
    print(
      'height=$withHeight levels=$withLevels min_height=$withMinHeight '
      'roofInfo=$withRoofInfo SEM-NADA=$noInfo',
    );
    print(
      'building:part(ways)=$parts relações-edifício-multi-outer=$multiOuter',
    );
  }
}

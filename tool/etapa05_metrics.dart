// ignore_for_file: avoid_print, dangling_library_doc_comments
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';

void main() {
  print(
    'regiao | vias | edif | areas | trav | semaf | marcacoes | '
    'objs | tris | pads | ms',
  );
  for (final city in ['garca', 'vera-cruz', 'marilia']) {
    final bytes = File('assets/map/osm/$city.osm.gz').readAsBytesSync();
    final sw = Stopwatch()..start();
    final engine = FogoEngine.build(Uint8List.fromList(bytes));
    final s = engine!.stats;
    final markings = engine.model.markings.length;
    print(
      '$city | ${s.roadCount} | ${s.buildingCount} | '
      '${s.landAreaCount} | ${s.crossingCount} | ${s.signalCount} | '
      '$markings | ${s.meshObjectCount} | ${s.triangleCount} | '
      '${s.junctionPadCount} | ${sw.elapsedMilliseconds}',
    );
  }
}

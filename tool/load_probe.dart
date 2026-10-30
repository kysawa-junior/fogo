// ignore_for_file: avoid_print
import 'dart:io';

import 'package:fogo/engine/fogo_engine.dart';

/// Sonda de carga: tempo por fase do pipeline com o extrato real.
/// Uso: dart run tool/load_probe.dart [caminho/do.osm.gz]
void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'assets/map/osm/regiao.osm.gz';
  final bytes = File(path).readAsBytesSync();
  final sw = Stopwatch()..start();
  final engine = FogoEngine.build(
    bytes,
    onProgress: (phase, count, fraction) =>
        print('${sw.elapsed}: $phase ($count) ${(fraction * 100).toStringAsFixed(1)}%'),
  )!;
  print('${sw.elapsed}: TOTAL');
  print('buildings=${engine.model.buildings.length}');
  print('sceneObjects=${engine.scene.objects.length}');
  print('footprintBatches=${engine.scene.buildingFootprints.length}');
  final padVerts = engine.scene.buildingFootprints.fold<int>(
    0,
    (n, b) => n + b.mesh.vertexCount,
  );
  print('footprintVerts=$padVerts');
  final byKind = <String, int>{};
  for (final o in engine.scene.objects) {
    byKind[o.kind.name] = (byKind[o.kind.name] ?? 0) + 1;
  }
  print('byKind=$byKind');
}

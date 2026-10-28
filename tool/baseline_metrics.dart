// ignore_for_file: avoid_print, dangling_library_doc_comments
// Linha de base ETAPA 00 — métricas do motor por região real.
// Uso: dart run tool/baseline_metrics.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';

void main() {
  final regions = ['regiao'];
  print(
    'regiao | ms | objetos | pads | tris | nos | vias | edif | areas | '
    'trav | semaf | issues | slivers',
  );
  for (final city in regions) {
    final f = File('assets/map/osm/$city.osm.gz');
    if (!f.existsSync()) {
      print('$city | AUSENTE');
      continue;
    }
    final bytes = f.readAsBytesSync();
    final sw = Stopwatch()..start();
    final engine = FogoEngine.build(Uint8List.fromList(bytes));
    final ms = sw.elapsedMilliseconds;
    if (engine == null) {
      print('$city | SEM CONTEÚDO');
      continue;
    }
    var slivers = 0;
    for (final o in engine.scene.objects) {
      final m = o.mesh;
      for (var i = 0; i < m.indices.length; i += 3) {
        final ax = m.positions[m.indices[i] * 3],
            ay = m.positions[m.indices[i] * 3 + 1],
            az = m.positions[m.indices[i] * 3 + 2];
        final bx = m.positions[m.indices[i + 1] * 3],
            by = m.positions[m.indices[i + 1] * 3 + 1],
            bz = m.positions[m.indices[i + 1] * 3 + 2];
        final cx = m.positions[m.indices[i + 2] * 3],
            cy = m.positions[m.indices[i + 2] * 3 + 1],
            cz = m.positions[m.indices[i + 2] * 3 + 2];
        // Área 3D (cross product completo) — paredes verticais contam.
        final ux = bx - ax, uy = by - ay, uz = bz - az;
        final vx = cx - ax, vy = cy - ay, vz = cz - az;
        final nx = uy * vz - uz * vy,
            ny = uz * vx - ux * vz,
            nz = ux * vy - uy * vx;
        if ((nx * nx + ny * ny + nz * nz) < 4e-18) slivers++;
      }
    }
    final s = engine.stats;
    print(
      '$city | $ms | ${s.meshObjectCount} | ${s.junctionPadCount} | '
      '${s.triangleCount} | ${s.nodeCount} | ${s.roadCount} | '
      '${s.buildingCount} | ${s.landAreaCount} | ${s.crossingCount} | '
      '${s.signalCount} | ${s.issueCount} | $slivers',
    );
  }
}

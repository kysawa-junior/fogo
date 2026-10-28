// ignore_for_file: avoid_print, dangling_library_doc_comments
// Auditoria ETAPA 02 — classifica pares de vias com geometria coincidente.
// Distingue: duplicatas comprovadas (mesma sequência de nós), sobreposições
// parciais, pistas paralelas e níveis distintos.
// Uso: dart run tool/duplicate_roads_audit.dart [regiao]
import 'dart:io';
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/engine/domain/road.dart';

void main(List<String> args) {
  final region = args.isNotEmpty ? args.first : 'garca';
  final bytes = File('assets/map/osm/$region.osm.gz').readAsBytesSync();
  final engine = FogoEngine.build(Uint8List.fromList(bytes));
  final roads = engine!.model.roads;

  // 1) Duplicatas FORTES: mesma sequência de nodeRefs (frente ou ré).
  final byRefs = <String, List<Road>>{};
  for (final r in roads) {
    for (final key in [_refKey(r.nodeRefs), _refKey(r.nodeRefs.reversed)]) {
      byRefs.putIfAbsent(key, () => []).add(r);
    }
  }
  var strongSameTags = 0, strongDiffTags = 0;
  final strongExamples = <String>[];
  for (final group in byRefs.values) {
    if (group.length < 2) continue;
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        final a = group[i], b = group[j];
        if (a.id == b.id) continue;
        final sameProfile =
            a.properties.layer == b.properties.layer &&
            a.properties.bridge == b.properties.bridge &&
            a.properties.tunnel == b.properties.tunnel;
        final sameSemantic =
            a.type == b.type && (a.name ?? '') == (b.name ?? '');
        if (sameProfile && sameSemantic) {
          strongSameTags++;
        } else {
          strongDiffTags++;
        }
        if (strongExamples.length < 8) {
          strongExamples.add(
            '${a.id}(${a.tags['highway']},layer=${a.properties.layer}) × '
            '${b.id}(${b.tags['highway']},layer=${b.properties.layer}) '
            '${a.name ?? b.name ?? ''}',
          );
        }
      }
    }
  }

  // 2) Sobreposição parcial: pares que compartilham ≥ 3 refs consecutivas
  // (sem ser duplicata forte) — típico de mapeamento em duas vias.
  final refIndex = <int, Set<int>>{}; // nodeRef -> índices de roads
  for (var i = 0; i < roads.length; i++) {
    for (final ref in roads[i].nodeRefs.toSet()) {
      refIndex.putIfAbsent(ref, () => {}).add(i);
    }
  }
  var partialPairs = 0;
  var longestShared = 0;
  String? partialExample;
  for (final indices in refIndex.values) {
    if (indices.length < 2) continue;
    final list = indices.toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = roads[list[i]], b = roads[list[j]];
        if (_refKey(a.nodeRefs) == _refKey(b.nodeRefs) ||
            _refKey(a.nodeRefs) == _refKey(b.nodeRefs.reversed)) {
          continue; // já contado como forte
        }
        final shared = _longestSharedRun(a.nodeRefs, b.nodeRefs);
        if (shared >= 3) {
          partialPairs++;
          if (shared > longestShared) {
            longestShared = shared;
            partialExample =
                '${a.id} × ${b.id} '
                '(${a.tags['highway']}/${b.tags['highway']}, '
                '${a.name ?? b.name ?? '?'}) — $shared nós compartilhados';
          }
        }
      }
    }
  }

  // 3) Nós duplicados: ids distintos, mesmas coordenadas.
  final coordToIds = <String, Set<int>>{};
  for (final n in engine.store.nodes) {
    final key = '${n.lat.toStringAsFixed(7)}:${n.lon.toStringAsFixed(7)}';
    coordToIds.putIfAbsent(key, () => {}).add(n.id);
  }
  var dupNodeCoords = 0;
  for (final ids in coordToIds.values) {
    if (ids.length > 1) dupNodeCoords++;
  }

  print('=== $region ===');
  print('vias no modelo: ${roads.length}');
  print('duplicatas FORTES (mesma sequência de nós):');
  print('  - perfil + semântica idênticos (deduplicável): $strongSameTags');
  print('  - atributos divergentes (ambíguo, preservar): $strongDiffTags');
  for (final e in strongExamples) {
    print('    ex: $e');
  }
  print(
    'sobreposições PARCIAIS (≥3 nós consecutivos compartilhados): '
    '$partialPairs (maior trecho: $longestShared nós)',
  );
  if (partialExample != null) print('    ex: $partialExample');
  print('pares de pistas paralelas/largura: NÃO são duplicatas (preservar)');
  print('nós com coordenadas iguais e ids distintos: $dupNodeCoords');
}

String _refKey(Iterable<int> refs) => refs.join(',');

int _longestSharedRun(List<int> a, List<int> b) {
  // Faz simple O(n·m) via janelas: suficiente p/ diagnóstico.
  var best = 0;
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      if (a[i] != b[j]) continue;
      var run = 0;
      while (i + run < a.length &&
          j + run < b.length &&
          a[i + run] == b[j + run]) {
        run++;
      }
      if (run > best) best = run;
    }
  }
  return best;
}

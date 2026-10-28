import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/domain/land_area.dart';
import 'package:fogo/engine/fogo_engine.dart';

/// Regressões contra o ASSET REAL da região (fixture esconde bugs que
/// só o extrato revela — exemplo: o "edifício oco"). UM build, dois
/// testes (o build custa ~18 s: 75k prédios Overture no extrato).
void main() {
  late final FogoEngine engine;

  setUpAll(() {
    final gz = File('assets/map/osm/regiao.osm.gz').readAsBytesSync();
    engine = FogoEngine.build(gz)!;
  });

  test('todos os edifícios têm teto (triângulo up-facing)', () {
    final buildings = engine.scene.objects
        .where((o) => o.kind == SceneObjectKind.building)
        .toList();
    expect(buildings.length, greaterThan(1000), reason: 'amostra do extrato');
    final semTeto = buildings.where((b) {
      for (var i = 0; i + 2 < b.mesh.indices.length; i += 3) {
        if (b.mesh.normals[b.mesh.indices[i] * 3 + 1] > 0.9) return false;
      }
      return true;
    }).length;
    expect(semTeto, 0, reason: 'teto indexado em 100% dos edifícios');
  });

  test('mato rural fora do perímetro urbano removido da cena', () {
    // Natureza (park/forest/farmland) fora das caixas urbanas do
    // catálogo OU > 1 km² NÃO pode ter objeto na cena — forest 76 km²
    // / grass rural 21,9 km² no extrato pesavam sem valor visual.
    // Parques urbanos dentro dos perímetros (≤ 0,75 km²) ficam.
    final sceneAreaIds = engine.scene.objects.map((o) => o.entityId).toSet();
    var rural = 0;
    for (final area in engine.model.landAreas) {
      final isNature =
          area.kind == LandAreaKind.park ||
          area.kind == LandAreaKind.forest ||
          area.kind == LandAreaKind.farmland;
      if (!isNature) continue;
      if (!_foraDoPerimetro(area) && _polygonAreaM2(area) <= 1e6) continue;
      rural++;
      expect(
        sceneAreaIds.contains(area.id),
        isFalse,
        reason: '${area.id} (${area.kind.name}) é mato rural',
      );
    }
    expect(rural, greaterThan(50), reason: 'o filtro precisa remover de fato');
  });

  test('estádio Platzeck: tigela 3D (arquibancada + pitch elevado)', () {
    // leisure=stadium → modelo AmenityMeshBuilder.stadium (plataforma +
    // anel de arquibancada); o pitch interno renderiza acima da
    // plataforma — nunca mais "plano tipo Outros".
    final stadium = engine.scene.objects
        .where((o) => o.entityId.startsWith('way/515659208'))
        .toList();
    expect(stadium, isNotEmpty, reason: 'Platzeck na cena');
    final obj = stadium.first;
    expect(obj.kind, SceneObjectKind.building);
    final b = obj.mesh.computeBounds()!;
    expect(b.max.y - b.min.y, greaterThan(7), reason: 'arquibancada ~8 m');
  });

  test('cena 2D independente cobre a região (modo mapa)', () {
    // Primitivas leves, uma por entidade: vias traçadas + áreas flat +
    // footprints — SEM mesh 3D. A visão geral desenha isto em canvas.
    final map2d = engine.map2d;
    expect(map2d.strokes.length, greaterThan(500), reason: 'vias');
    final footprints = map2d.fills.where((f) => f.footprint).length;
    expect(footprints, greaterThan(1000), reason: 'footprint por edifício');
    expect(
      map2d.fills.where((f) => !f.footprint).length,
      greaterThan(150),
      reason: 'áreas urbanas mantidas (mato rural filtrado)',
    );
    // Nenhuma coordenada infinita (projeção de todos os pontos).
    for (final stroke in map2d.strokes.take(100)) {
      expect(stroke.points.first.isFinite, isTrue);
      expect(stroke.points.last.isFinite, isTrue);
    }
  });
}

/// Centro da área fora de TODAS as caixas urbanas do catálogo
/// (replica a regra do motor — [_isRuralNature] do engine).
bool _foraDoPerimetro(dynamic area) {
  var minLat = double.infinity, maxLat = -double.infinity;
  var minLon = double.infinity, maxLon = -double.infinity;
  for (final polygon in area.polygons) {
    if (polygon.isEmpty) continue;
    for (final p in polygon.first) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
  }
  if (minLat.isInfinite) return false;
  final lat = (minLat + maxLat) / 2;
  final lon = (minLon + maxLon) / 2;
  for (final city in RegionCatalog.cities) {
    final b = city.bounds;
    if (lat >= b.south && lat <= b.north && lon >= b.west && lon <= b.east) {
      return false;
    }
  }
  return true;
}

/// Shoelace em graus (mesma métrica do motor — [_polygonAreaM2]).
double _polygonAreaM2(dynamic area) {
  var total = 0.0;
  for (final polygon in area.polygons) {
    if (polygon.isEmpty) continue;
    final outer = polygon.first;
    var sum = 0.0;
    for (var i = 0; i < outer.length; i++) {
      final a = outer[i];
      final b = outer[(i + 1) % outer.length];
      sum += a.longitude * b.latitude - b.longitude * a.latitude;
    }
    total += (sum.abs() / 2) * 111320 * 111320;
  }
  return total;
}

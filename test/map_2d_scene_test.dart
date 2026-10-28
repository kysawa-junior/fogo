import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/domain/land_area.dart' show LandAreaKind;
import 'package:fogo/engine/domain/road_type.dart';
import 'package:fogo/engine/fogo_engine.dart';

import 'engine/fixtures.dart';

/// ENG: cena 2D independente — primitivas leves coletadas nos mesmos
/// loops da cena 3D (mesmos filtros, sem reprojeção), sem mesh 3D.
void main() {
  group('Map2DScene (fixture)', () {
    late FogoEngine engine;

    setUpAll(() => engine = FogoEngine.build(fixtureBytes())!);

    test('strokes: uma por via da cena (mesma coleta, mesmos filtros)', () {
      expect(engine.map2d.strokes.length, engine.stats.roadCount);
    });

    test('bounds de tile cobrem conteúdo para limitar vista 3D', () {
      expect(engine.scene.tileBounds, isNotEmpty);
      for (final obj in engine.scene.objects) {
        expect(
          engine.scene.tileBounds.containsKey(obj.tileId),
          isTrue,
          reason: 'tile sem bounds: ${obj.tileId}',
        );
      }
    });

    test('stroke carrega geometria x/z intercalada e largura real', () {
      final stroke = engine.map2d.strokes.firstWhere(
        (s) => s.type == RoadType.residential,
      );
      // Pontos pares/impares = x/z — nada infinito/NaN.
      for (var i = 0; i < stroke.points.length; i++) {
        expect(stroke.points[i].isFinite, isTrue);
      }
      expect(stroke.points.length, greaterThanOrEqualTo(4));
      expect(stroke.widthMeters, greaterThan(0));
    });

    test('todas as classes de via usam cor residencial em 2D e 3D', () {
      final residential = FogoPalette.road(RoadType.residential);
      void expectResidentialColor(double x, double y, double z) {
        expect(x, closeTo(residential.x, 1e-6));
        expect(y, closeTo(residential.y, 1e-6));
        expect(z, closeTo(residential.z, 1e-6));
      }

      for (final type in RoadType.values) {
        final color = FogoPalette.road(type);
        expectResidentialColor(color.x, color.y, color.z);
      }
      for (final stroke in engine.map2d.strokes) {
        expectResidentialColor(stroke.color.x, stroke.color.y, stroke.color.z);
      }
      for (final object in engine.scene.objects.where(
        (o) => o.kind == SceneObjectKind.road,
      )) {
        expectResidentialColor(object.color.x, object.color.y, object.color.z);
      }
    });

    test('fills: 5 áreas urbanas + 4 footprints de edifício', () {
      // way/59, way/60, way/70, way/80, way/81 = 5 áreas urbanas;
      // relation/30 (forest) cai FORA do perímetro urbano do catálogo
      // → rural-filtrada na cena 3D e AQUI TAMBÉM (consistência 2D↔3D:
      // modo 2D nunca mostra mato rural).
      expect(engine.map2d.fills.length, 9);
      final footprints = engine.map2d.fills.where((f) => f.footprint);
      expect(footprints.length, 4);
      // Sem fill multi-ring: a única área com buraco da fixture era a
      // forest rural-filtrada.
      expect(engine.map2d.fills.any((f) => f.rings.length > 1), isFalse);
    });

    test('cor do fill usa a MESMA paleta land(kind) da cena 3D', () {
      final fill = engine.map2d.fills.firstWhere((f) => !f.footprint);
      final expected = FogoPalette.land(LandAreaKind.other);
      expect(fill.color.x, closeTo(expected.x, 1e-6));
      expect(fill.color.y, closeTo(expected.y, 1e-6));
      expect(fill.color.z, closeTo(expected.z, 1e-6));
    });

    test('estádio no 2D é FILL (silhueta), nunca volume', () {
      // Primeiro nó do anel do estádio (node 150) projetado identifica
      // o fill dele entre as áreas.
      final stadium = engine.model.landAreas.firstWhere(
        (a) => a.kind == LandAreaKind.stadium,
      );
      final ring = stadium.polygons.first.first;
      final p0 = engine.projector.project(ring.first);
      final stadiumFill = engine.map2d.fills.firstWhere(
        (f) =>
            !f.footprint &&
            (f.rings.first[0] - p0.x).abs() < 1e-3 &&
            (f.rings.first[1] - p0.z).abs() < 1e-3,
      );
      expect(stadiumFill.footprint, isFalse, reason: 'flat no 2D');
      // 8 nós do anel do estádio (way/80) no fill.
      expect(stadiumFill.rings.first.length ~/ 2, 8);
    });
  });
}

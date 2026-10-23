import 'dart:math' as math;

import 'package:fogo/engine/geometry/polygon_triangulator.dart';
import 'package:fogo/engine/mesh/box_builder.dart';
import 'package:fogo/engine/mesh/building_mesh_builder.dart';
import 'package:fogo/engine/mesh/crossing_mesh_builder.dart';
import 'package:fogo/engine/mesh/road_mesh_builder.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoadMeshBuilder', () {
    test('rua reta: malha válida, largura coerente, winding +Y', () {
      const width = 8.0;
      final mesh = RoadMeshBuilder.build([
        Vector3(0, 0, 0),
        Vector3(100, 0, 0),
      ], width)!;

      expect(mesh.isValid, isTrue, reason: 'índices válidos + finitos');
      expect(mesh.triangleCount, 2);
      // Largura: extensão em z é exatamente `width`.
      final b = mesh.computeBounds()!;
      expect(b.max.z - b.min.z, closeTo(width, 1e-4));
      expect(b.max.x - b.min.x, closeTo(100, 1e-4));
      expect(b.min.y, 0);

      // Winding: normal do primeiro triângulo aponta para +Y.
      final tri = mesh.indices;
      final v = <Vector3>[
        for (var i = 0; i < 6; i++)
          Vector3(
            mesh.positions[tri[i] * 3],
            mesh.positions[tri[i] * 3 + 1],
            mesh.positions[tri[i] * 3 + 2],
          ),
      ];
      final n = (v[1] - v[0]).cross(v[2] - v[0]);
      expect(n.y, greaterThan(0));
    });

    test('rua curva: malha válida, sem degenerados, largura coerente', () {
      // Arco de ~90°: 20 pontos sobre um quarto de círculo r=200.
      final pts = <Vector3>[
        for (var i = 0; i <= 20; i++)
          Vector3(
            200 * math.cos(i / 20 * math.pi / 2),
            0,
            200 * math.sin(i / 20 * math.pi / 2),
          ),
      ];
      final mesh = RoadMeshBuilder.build(pts, 6)!;
      expect(mesh.isValid, isTrue);
      expect(
        mesh.triangleCount,
        2 * (pts.length - 1),
        reason: '1 quad (2 triângulos) por segmento',
      );
      // Largura máx: no arco, o miter estica as bordas externas um pouco
      // além de 6 m; limite de tolerância 2×.
      final b = mesh.computeBounds()!;
      final diag = (b.max.x - b.min.x) + (b.max.z - b.min.z);
      expect(diag, greaterThan(2 * 200));
      // Sem NaN/inf já coberto por isValid; sem vértices colapsados:
      for (var i = 0; i < mesh.positions.length; i += 3) {
        expect(mesh.positions[i].abs(), lessThan(500));
      }
    });

    test('curva de 180° (reversão) não explode (miter clamp)', () {
      final mesh = RoadMeshBuilder.build([
        Vector3(0, 0, 0),
        Vector3(10, 0, 0),
        Vector3(0, 0, 0),
        Vector3(-10, 0, 0),
      ], 4)!;
      expect(mesh.isValid, isTrue);
      final b = mesh.computeBounds()!;
      expect(b.max.x - b.min.x, lessThan(60), reason: 'clamp do miter');
    });

    test('polilinha com pontos duplicados é limpa', () {
      final mesh = RoadMeshBuilder.build([
        Vector3(0, 0, 0),
        Vector3(0, 0, 0),
        Vector3(50, 0, 0),
      ], 4)!;
      expect(mesh.isValid, isTrue);
      expect(mesh.triangleCount, 2);
    });

    test('entrada inválida retorna null', () {
      expect(RoadMeshBuilder.build([], 4), isNull);
      expect(RoadMeshBuilder.build([Vector3.zero()], 4), isNull);
      expect(
        RoadMeshBuilder.build([Vector3.zero(), Vector3(1, 0, 0)], 0),
        isNull,
      );
    });
  });

  group('PolygonTriangulator', () {
    test('quadrado simples gera 2 triângulos com área correta', () {
      final sq = [
        Vector3(0, 0, 0),
        Vector3(10, 0, 0),
        Vector3(10, 0, 10),
        Vector3(0, 0, 10),
      ];
      final r = PolygonTriangulator.triangulate(sq, const [])!;
      expect(r.triangles.length, 6, reason: '2 triângulos = 6 índices');
      var area = 0.0;
      for (var i = 0; i < r.triangles.length; i += 3) {
        final a = r.vertices[r.triangles[i]];
        final b = r.vertices[r.triangles[i + 1]];
        final c = r.vertices[r.triangles[i + 2]];
        area += (b - a).cross(c - a).length / 2;
      }
      expect(area, closeTo(100, 1e-6));
    });

    test('quadrado com buraco: nenhuma triângulo cobre o centro do buraco', () {
      final outer = [
        Vector3(0, 0, 0),
        Vector3(100, 0, 0),
        Vector3(100, 0, 100),
        Vector3(0, 0, 100),
      ];
      final hole = [
        Vector3(40, 0, 40),
        Vector3(40, 0, 60),
        Vector3(60, 0, 60),
        Vector3(60, 0, 40),
      ];
      final r = PolygonTriangulator.triangulate(outer, [hole])!;
      expect(r.triangles.length, greaterThanOrEqualTo(12));
      var area = 0.0;
      for (var i = 0; i < r.triangles.length; i += 3) {
        final a = r.vertices[r.triangles[i]];
        final b = r.vertices[r.triangles[i + 1]];
        final c = r.vertices[r.triangles[i + 2]];
        final tri = _Tri(a, b, c);
        // Nenhum triângulo pode conter o centro do buraco.
        expect(
          tri.containsPoint(Vector3(50, 0, 50)),
          isFalse,
          reason: 'buraco recortado da superfície',
        );
        area += tri.area;
      }
      expect(
        area,
        closeTo(10000 - 400, 30),
        reason: 'área externa − área do buraco',
      );
    });

    test('polígono inválido retorna null', () {
      expect(PolygonTriangulator.triangulate([Vector3.zero()], []), isNull);
    });
  });

  group('BuildingMeshBuilder', () {
    test('extrusão: paredes + laje, altura e winding externo', () {
      final base = [
        Vector3(0, 0, 0),
        Vector3(10, 0, 0),
        Vector3(10, 0, 10),
        Vector3(0, 0, 10),
      ];
      final mesh = BuildingMeshBuilder.build([base], heightMeters: 15)!;
      expect(mesh.isValid, isTrue);
      // 4 paredes × 2 tri + laje 2 tri = 10 triângulos.
      expect(mesh.triangleCount, 10);
      final b = mesh.computeBounds()!;
      expect(b.max.y, 15);
      // Normal externa: uma parede tem normal +X; garantir que algum
      // triângulo aponta para fora (x>5) com normal +X.
      var found = false;
      for (var i = 0; i < mesh.indices.length && !found; i += 3) {
        final idx = mesh.indices;
        final a = Vector3(
          mesh.positions[idx[i] * 3],
          mesh.positions[idx[i] * 3 + 1],
          mesh.positions[idx[i] * 3 + 2],
        );
        final n = Vector3(
          mesh.normals[idx[i] * 3],
          mesh.normals[idx[i] * 3 + 1],
          mesh.normals[idx[i] * 3 + 2],
        );
        if (a.x > 9 && n.x > 0.9) found = true;
      }
      expect(found, isTrue, reason: 'parede leste com normal +X (externa)');
    });

    test('edifício com buraco (pátio): cobertura recortada', () {
      final outer = [
        Vector3(0, 0, 0),
        Vector3(20, 0, 0),
        Vector3(20, 0, 20),
        Vector3(0, 0, 20),
      ];
      final inner = [
        Vector3(8, 0, 8),
        Vector3(8, 0, 12),
        Vector3(12, 0, 12),
        Vector3(12, 0, 8),
      ];
      final mesh = BuildingMeshBuilder.build([outer, inner], heightMeters: 10)!;
      expect(mesh.isValid, isTrue);
      // Nenhum vértice da cobertura dentro do pátio (exceto paredes do
      // buraco, que ficam no perímetro 8..12 — checar só topo).
      var roofTopCount = 0;
      for (var i = 1; i < mesh.positions.length; i += 3) {
        if (mesh.positions[i] == 10) roofTopCount++;
      }
      expect(roofTopCount, greaterThan(3), reason: 'laje no topo');
    });

    test('altura inválida/contorno curto retorna null', () {
      expect(
        BuildingMeshBuilder.build([
          [Vector3.zero(), Vector3(1, 0, 0)],
        ], heightMeters: 5),
        isNull,
      );
      expect(
        BuildingMeshBuilder.build([
          [Vector3.zero(), Vector3(1, 0, 0), Vector3(1, 0, 1)],
        ], heightMeters: 0),
        isNull,
      );
    });
  });

  group('CrossingMeshBuilder / TrafficSignalMeshBuilder / box', () {
    test('travessia: 4 barras paralelas à via, centradas na posição real', () {
      final mesh = CrossingMeshBuilder.build(
        Vector3(100, 0, 50),
        0, // heading 0 = leste
        roadWidthMeters: 8,
      )!;
      expect(mesh.isValid, isTrue);
      expect(mesh.triangleCount, 8, reason: '4 barras × 2 tri');
      final b = mesh.computeBounds()!;
      // Barras ao longo da via (x): comprimento 2.6; empilhadas na
      // perpendicular (z): total = 4×0.45+3×0.35 = 2.85. Tolerância
      // float32 (posições são Float32List).
      expect(b.max.x - b.min.x, closeTo(2.6, 1e-4));
      expect(b.max.z - b.min.z, closeTo(2.85, 1e-4));
      // Centrada na posição real.
      expect((b.min.x + b.max.x) / 2, closeTo(100, 1e-3));
      expect((b.min.z + b.max.z) / 2, closeTo(50, 1e-3));
    });

    test('semáforo: poste + caixa, malha válida acima do solo', () {
      final mesh = TrafficSignalMeshBuilder.build(Vector3(10, 0, 20), 0)!;
      expect(mesh.isValid, isTrue);
      expect(mesh.computeBounds()!.max.y, closeTo(5.2, 0.01));
    });

    test('caixa rotacionada mantém extensões e normais externas', () {
      final mesh = buildBox(
        Vector3(0, 1, 0),
        Vector3(1, 1, 0.5),
        headingRadians: math.pi / 2,
      );
      expect(mesh.isValid, isTrue);
      for (var i = 0; i < mesh.positions.length; i += 3) {
        expect(
          mesh.positions[i].abs(),
          lessThan(0.6),
          reason: 'rotacionada 90°: extensão vira z',
        );
      }
      var sumX = 0.0;
      for (var i = 0; i < mesh.normals.length; i += 3) {
        sumX += mesh.normals[i];
      }
      expect(sumX, closeTo(0, 1e-6), reason: 'normais equilibram');
    });
  });
}

class _Tri {
  _Tri(this.a, this.b, this.c);

  final Vector3 a, b, c;

  double get area => (b - a).cross(c - a).length / 2;

  bool containsPoint(Vector3 p) {
    final d1 = _sign(p, a, b);
    final d2 = _sign(p, b, c);
    final d3 = _sign(p, c, a);
    final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
    final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(hasNeg && hasPos);
  }

  double _sign(Vector3 p, Vector3 v1, Vector3 v2) =>
      (p.x - v2.x) * (v1.z - v2.z) - (v1.x - v2.x) * (p.z - v2.z);
}

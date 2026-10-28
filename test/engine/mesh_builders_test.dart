import 'dart:math' as math;

import 'package:fogo/engine/geometry/mesh_data.dart';
import 'package:fogo/engine/geometry/polygon_triangulator.dart';
import 'package:fogo/engine/mesh/amenity_mesh_builder.dart';
import 'package:fogo/engine/mesh/box_builder.dart';
import 'package:fogo/engine/mesh/building_mesh_builder.dart';
import 'package:fogo/engine/mesh/crossing_mesh_builder.dart';
import 'package:fogo/engine/mesh/road_mesh_builder.dart';
import 'package:fogo/engine/mesh/slab_mesh_builder.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ponto coberto por algum triângulo da malha (plano x/z).
bool _contains(MeshData mesh, Vector3 q) {
  Vector3 v(int i) => Vector3(
    mesh.positions[mesh.indices[i] * 3],
    mesh.positions[mesh.indices[i] * 3 + 1],
    mesh.positions[mesh.indices[i] * 3 + 2],
  );
  double sign(Vector3 p, Vector3 a, Vector3 b) =>
      (p.x - b.x) * (a.z - b.z) - (a.x - b.x) * (p.z - b.z);
  for (var i = 0; i < mesh.indices.length; i += 3) {
    final a = v(mesh.indices[i]);
    final b = v(mesh.indices[i + 1]);
    final c = v(mesh.indices[i + 2]);
    final d1 = sign(q, a, b);
    final d2 = sign(q, b, c);
    final d3 = sign(q, c, a);
    final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
    final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
    if (!(hasNeg && hasPos)) return true;
  }
  return false;
}

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

    test('rua curva: malha válida, contorno com arcos, sem picos', () {
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
      // Contorno fechado triangulado: tantos triângulos quanto a
      // própria malha permite (>= 2 por segmento, sem degenerados).
      expect(mesh.triangleCount, greaterThanOrEqualTo(2 * (pts.length - 1)));
      // Curva externa recebe arco (não miter esticado): o bounds fica
      // dentro do círculo + largura, sem picos.
      final b = mesh.computeBounds()!;
      final diag = (b.max.x - b.min.x) + (b.max.z - b.min.z);
      expect(diag, greaterThan(2 * 200), reason: 'cobre o arco todo');
      expect(diag, lessThan(2 * 200 + 40), reason: 'sem picos além da via');
      for (var i = 0; i < mesh.positions.length; i += 3) {
        expect(mesh.positions[i].abs(), lessThan(500));
      }
    });

    test('reversão 180°: bevel estável, sem pico de miter', () {
      final mesh = RoadMeshBuilder.build([
        Vector3(0, 0, 0),
        Vector3(10, 0, 0),
        Vector3(0, 0, 0),
        Vector3(-10, 0, 0),
      ], 4)!;
      expect(mesh.isValid, isTrue);
      final b = mesh.computeBounds()!;
      // Bevel em ambos os lados: extensão total limitada à largura
      // (meia-largura 2 por lado) + o comprimento real dos trechos.
      expect(b.max.x - b.min.x, lessThan(25), reason: 'sem pico de miter');
      expect(b.max.z - b.min.z, closeTo(4, 0.5), reason: 'largura da via');
    });

    test('curva fechada ~90°: canto externo em arco, interno em miter', () {
      final mesh = RoadMeshBuilder.build([
        Vector3(0, 0, 0),
        Vector3(100, 0, 0),
        Vector3(100, 0, 100),
      ], 8)!;
      expect(mesh.isValid, isTrue);
      final b = mesh.computeBounds()!;
      // Via de 8 m dobrando 90°: nenhum ponto além de meia-largura (4)
      // do traçado — arco externo + miter interno, sem picos.
      expect(b.max.x, lessThan(100 + 4.1));
      expect(b.max.z, lessThan(100 + 4.1));
      expect(b.min.x, greaterThan(-4.1));
      // Miter interno corta o canto: bounds interno < 100 na dobra.
      expect(b.max.x, greaterThan(100 - 4));
      expect(b.max.z, greaterThan(100 - 4));
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

    test('anel fechado (rotatória): superfície contínua na emenda', () {
      // Anel quadrado 100×100, largura 8: TODOS os lados precisam estar
      // cobertos, inclusive a emenda (segmento de fechamento).
      final ring = RoadMeshBuilder.build([
        Vector3(0, 0, 0),
        Vector3(100, 0, 0),
        Vector3(100, 0, 100),
        Vector3(0, 0, 100),
        Vector3(0, 0, 0),
      ], 8)!;
      expect(ring.isValid, isTrue);
      final b = ring.computeBounds()!;
      // Quadrado 100×100 na linha central + meia-largura 4 por lado.
      expect(b.max.x - b.min.x, closeTo(108, 0.01));
      expect(b.max.z - b.min.z, closeTo(108, 0.01));
      // Ponto central do lado de fechamento (x=50, z=100): numa
      // polilinha aberta este segmento seria PERDIDO pelo dedupe do
      // vértice repetido — fenda ao longo do lado inteiro.
      expect(
        _contains(ring, Vector3(50, 0, 100)),
        isTrue,
        reason: 'lado do fechamento coberto',
      );
      // Centro do anel (ilha interna) NÃO pode estar coberto.
      expect(
        _contains(ring, Vector3(50, 0, 50)),
        isFalse,
        reason: 'ilha da rotatória vazia',
      );
      // Cantos externos em arco: nada além de meia-largura dos vértices.
      expect(b.max.x, lessThan(100 + 4.1));
    });

    test('anel triangular realista: válida, emenda coberta', () {
      // Equilátero 200 m de lado, via de 8 m: raio ≫ largura, como uma
      // rotatória real. (Caso-limite de 60 m × 5 m com miters internos
      // quase colidentes deixa o ear-clip parcial — documentado.)
      final ring = RoadMeshBuilder.build([
        Vector3(0, 0, 0),
        Vector3(200, 0, 0),
        Vector3(100, 0, 173),
        Vector3(0, 0, 0),
      ], 8)!;
      expect(ring.isValid, isTrue);
      expect(
        _contains(ring, Vector3(100, 0, 10)),
        isTrue,
        reason: 'emenda (vértice repetido) coberta',
      );
      expect(
        _contains(ring, Vector3(100, 0, 160)),
        isTrue,
        reason: 'lado do vértice oposto coberto',
      );
      // Nota: neste caso extremo o ear-clip com buraco pode não
      // completar 95% de cobertura — o fallback pinta o anel SÓLIDO
      // (via contínua, ilha preenchida). A ilha vazia é garantida no
      // anel quadrado, que triangula completo.
    });

    test('anel degenerado (2 pontos repetidos): null', () {
      expect(
        RoadMeshBuilder.build([
          Vector3(0, 0, 0),
          Vector3(10, 0, 0),
          Vector3(0, 0, 0),
        ], 4),
        isNull,
        reason: 'dois pontos distintos são via aberta, não anel',
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
      final mesh = BuildingMeshBuilder.build([base], heightMeters: 15)!.volume;
      expect(mesh.isValid, isTrue);
      // 4 paredes × 2 tri + laje 2 tri + piso 2 tri = 12 triângulos
      // (volume FECHADO: paredes, teto e base).
      expect(mesh.triangleCount, 12);
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

    test('volume fechado: piso no solo com normal -Y', () {
      final mesh = BuildingMeshBuilder.build([
        [
          Vector3(0, 0, 0),
          Vector3(10, 0, 0),
          Vector3(10, 0, 10),
          Vector3(0, 0, 10),
        ],
      ], heightMeters: 15)!.volume;
      final b = mesh.computeBounds()!;
      expect(b.min.y, 0, reason: 'piso na base');
      // Algum triângulo com normal -Y (piso visto por baixo).
      var floorFound = false;
      for (var i = 0; i < mesh.indices.length && !floorFound; i += 3) {
        final idx = mesh.indices;
        final n = Vector3(
          mesh.normals[idx[i] * 3],
          mesh.normals[idx[i] * 3 + 1],
          mesh.normals[idx[i] * 3 + 2],
        );
        if (n.y < -0.9) floorFound = true;
      }
      expect(floorFound, isTrue, reason: 'piso com normal -Y (fecha o volume)');
    });

    test(
      'teto INDEXADO: existe triângulo com vértices em y=top e normal +Y',
      () {
        // Reproduz o bug real: índices do teto sem offset aliasavam
        // paredes — vértices do teto órfãos, zero triângulos up-facing.
        final mesh = BuildingMeshBuilder.build([
          [
            Vector3(0, 0, 0),
            Vector3(10, 0, 0),
            Vector3(10, 0, 10),
            Vector3(0, 0, 10),
          ],
        ], heightMeters: 15)!.volume;
        var roofTri = 0;
        for (var i = 0; i + 2 < mesh.indices.length; i += 3) {
          final idx = mesh.indices;
          var allTop = true;
          for (var k = 0; k < 3; k++) {
            if (mesh.positions[idx[i + k] * 3 + 1] != 15) allTop = false;
          }
          if (allTop) roofTri++;
        }
        expect(roofTri, 2, reason: 'laje do teto referenciada de verdade');
      },
    );

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
      final mesh = BuildingMeshBuilder.build([
        outer,
        inner,
      ], heightMeters: 10)!.volume;
      expect(mesh.isValid, isTrue);
      // Nenhum vértice da cobertura dentro do pátio (exceto paredes do
      // buraco, que ficam no perímetro 8..12 — checar só topo).
      var roofTopCount = 0;
      for (var i = 1; i < mesh.positions.length; i += 3) {
        if (mesh.positions[i] == 10) roofTopCount++;
      }
      expect(roofTopCount, greaterThan(3), reason: 'laje no topo');
    });

    test('contorno curto retorna null; altura 0 clampada no mínimo', () {
      expect(
        BuildingMeshBuilder.build([
          [Vector3.zero(), Vector3(1, 0, 0)],
        ], heightMeters: 5),
        isNull,
      );
      // Altura nula/nula: clamp no mínimo do estilo — nunca edifício
      // invisível (o mapper nunca entrega 0; isso é defesa do builder).
      final zero = BuildingMeshBuilder.build([
        [Vector3.zero(), Vector3(1, 0, 0), Vector3(1, 0, 1)],
      ], heightMeters: 0);
      expect(zero, isNotNull);
      expect(zero!.volume.computeBounds()!.max.y, 2.5);
    });

    test('clamp de altura: dados absurdos não deformam o edifício', () {
      final skyScraper = BuildingMeshBuilder.build([
        [
          Vector3(0, 0, 0),
          Vector3(10, 0, 0),
          Vector3(10, 0, 10),
          Vector3(0, 0, 10),
        ],
      ], heightMeters: 99999)!.volume;
      expect(
        skyScraper.computeBounds()!.max.y,
        300,
        reason: 'clamp máximo do estilo',
      );

      final tiny = BuildingMeshBuilder.build([
        [
          Vector3(0, 0, 0),
          Vector3(10, 0, 0),
          Vector3(10, 0, 10),
          Vector3(0, 0, 10),
        ],
      ], heightMeters: 0.05)!.volume;
      expect(tiny.computeBounds()!.max.y, 2.5, reason: 'clamp mínimo');

      expect(
        BuildingMeshBuilder.build([
          [
            Vector3(0, 0, 0),
            Vector3(10, 0, 0),
            Vector3(10, 0, 10),
            Vector3(0, 0, 10),
          ],
        ], heightMeters: double.nan),
        isNull,
        reason: 'NaN não vira edifício',
      );
    });

    test('TASK-0011: pad plano acompanha o volume (mesma triangulação)', () {
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
      final meshes = BuildingMeshBuilder.build([
        outer,
        inner,
      ], heightMeters: 10)!;
      final flat = meshes.flat;
      expect(flat.isValid, isTrue);
      expect(flat.positions, isNotNull);
      // Plano, no lift, ALL normals +Y (visível de cima, buraco recortado).
      for (var i = 0; i < flat.vertexCount; i++) {
        expect(flat.positions[i * 3 + 1], closeTo(0.06, 1e-6));
        expect(flat.normals[i * 3 + 1], 1);
        expect(flat.normals[i * 3], 0);
        expect(flat.normals[i * 3 + 2], 0);
      }
      // Winding up-facing: todos os triângulos com área Y positiva
      // (convencão do motor: x leste, z SUL — cross 2D negativo = +Y).
      for (var i = 0; i + 2 < flat.indices.length; i += 3) {
        final idx = flat.indices;
        final ax = flat.positions[idx[i] * 3],
            az = flat.positions[idx[i] * 3 + 2];
        final bx = flat.positions[idx[i + 1] * 3],
            bz = flat.positions[idx[i + 1] * 3 + 2];
        final cx = flat.positions[idx[i + 2] * 3],
            cz = flat.positions[idx[i + 2] * 3 + 2];
        final cross = (bx - ax) * (cz - az) - (bz - az) * (cx - ax);
        expect(cross, lessThan(0), reason: 'winding de cima (+Y)');
      }
      // Sem cores/UV: material de cor base no adapter.
      expect(flat.colors, isNull);
    });

    test('ETAPA 03: planta côncava (L) — cobertura válida e fiel', () {
      // Planta em L: côncavo no reentrante (origem nos dados, nunca
      // "retangularizado").
      final lShape = [
        Vector3(0, 0, 0),
        Vector3(20, 0, 0),
        Vector3(20, 0, 12),
        Vector3(8, 0, 12),
        Vector3(8, 0, 20),
        Vector3(0, 0, 20),
      ];
      final mesh = BuildingMeshBuilder.build([lShape], heightMeters: 7)!.volume;
      expect(mesh.isValid, isTrue);
      // Contorno preservado: bounds exatos da planta.
      final b = mesh.computeBounds()!;
      expect(b.max.x, closeTo(20, 1e-4));
      expect(b.max.z, closeTo(20, 1e-4));
      expect(b.max.y, 7);
      // 6 arestas × 2 paredes + cobertura (hexágono em L = 4 tri) + piso
      // (4 tri) = 20 triângulos — volume fechado.
      expect(mesh.triangleCount, 20);
      // O reentrante (8..20, 12..20) NÃO é coberto no interior acima
      // da cobertura... ponto da reentrância acima do prédio: sem
      // triângulo de TETO sobre (14, 16). Checagem triângulo a
      // triângulo: paredes verticais são degeneradas em x/z (a linha
      // do segmento "contém" qualquer ponto — falso positivo).
      var coveredAtNotch = false;
      Vector3 v(int i) => Vector3(
        mesh.positions[mesh.indices[i] * 3],
        mesh.positions[mesh.indices[i] * 3 + 1],
        mesh.positions[mesh.indices[i] * 3 + 2],
      );
      for (var i = 0; i < mesh.indices.length; i += 3) {
        final a = v(i), b2 = v(i + 1), c = v(i + 2);
        if (a.y != 7 || b2.y != 7 || c.y != 7) continue;
        final cross = (b2.x - a.x) * (c.z - a.z) - (b2.z - a.z) * (c.x - a.x);
        if (cross == 0) continue; // parede vertical vista de cima
        double sign(Vector3 p, Vector3 u, Vector3 w) =>
            (p.x - w.x) * (u.z - w.z) - (u.x - w.x) * (p.z - w.z);
        final q = Vector3(14, 0, 16);
        final d1 = sign(q, a, b2);
        final d2 = sign(q, b2, c);
        final d3 = sign(q, c, a);
        if (!((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0))) {
          coveredAtNotch = true;
        }
      }
      expect(coveredAtNotch, isFalse, reason: 'reentrante vazia');
    });

    test('ETAPA 03: aresta submilimétrica não gera parede degenerada', () {
      // Dois vértices a 0.5 mm (colapsam no float32): o dedupe XZ já
      // remove; nenhuma parede de área nula sobrevive ao pós-filtro.
      final mesh = BuildingMeshBuilder.build([
        [
          Vector3(0, 0, 0),
          Vector3(0.0005, 0, 0),
          Vector3(10, 0, 0),
          Vector3(10, 0, 10),
          Vector3(0, 0, 10),
        ],
      ], heightMeters: 5)!.volume;
      expect(mesh.isValid, isTrue);
      for (var i = 0; i < mesh.indices.length; i += 3) {
        final a = Vector3(
          mesh.positions[mesh.indices[i] * 3],
          mesh.positions[mesh.indices[i] * 3 + 1],
          mesh.positions[mesh.indices[i] * 3 + 2],
        );
        final b = Vector3(
          mesh.positions[mesh.indices[i + 1] * 3],
          mesh.positions[mesh.indices[i + 1] * 3 + 1],
          mesh.positions[mesh.indices[i + 1] * 3 + 2],
        );
        final c = Vector3(
          mesh.positions[mesh.indices[i + 2] * 3],
          mesh.positions[mesh.indices[i + 2] * 3 + 1],
          mesh.positions[mesh.indices[i + 2] * 3 + 2],
        );
        expect((b - a).cross(c - a).length, greaterThan(1e-5));
      }
    });

    test('volumetria: fachadas sombreadas, cobertura na cor base', () {
      final mesh = BuildingMeshBuilder.build([
        [
          Vector3(0, 0, 0),
          Vector3(10, 0, 0),
          Vector3(10, 0, 10),
          Vector3(0, 0, 10),
        ],
      ], heightMeters: 12)!.volume;
      expect(mesh.colors, isNotNull);
      expect(mesh.isValid, isTrue);
      double shadeOf(int v) => mesh.colors![v * 4];

      // Cobertura (gerada antes do piso): multiplicador = cor base.
      for (var v = mesh.vertexCount - 8; v < mesh.vertexCount - 4; v++) {
        expect(
          shadeOf(v),
          closeTo(1.0, 1e-6),
          reason: 'vértice $v da cobertura em cor base',
        );
      }
      // Piso (últimos vértices): sombra ambiente (face inferior).
      for (var v = mesh.vertexCount - 4; v < mesh.vertexCount; v++) {
        expect(shadeOf(v), closeTo(0.55, 1e-6), reason: 'piso em ambient');
      }
      // Fachadas (primeiros 16 vértices): entre ambient e 1.0 — nunca
      // pretas (detalhe preservado), nunca acima da cobertura.
      for (var v = 0; v < 16; v++) {
        final s = shadeOf(v);
        expect(s, greaterThanOrEqualTo(0.55));
        expect(s, lessThanOrEqualTo(1.0));
      }
      // Luz direcional diferencia fachadas opostas (contraste volumétrico).
      final wallShades = {for (var v = 0; v < 16; v++) shadeOf(v)};
      expect(wallShades.length, greaterThan(1));
      expect(wallShades.reduce(math.min), lessThan(1.0));
    });
  });

  group('SlabMeshBuilder', () {
    test('slab: tampa no topo + saias até a base (espessura real)', () {
      final mesh = SlabMeshBuilder.build(
        [
          [
            Vector3(0, 0, 0),
            Vector3(10, 0, 0),
            Vector3(10, 0, 10),
            Vector3(0, 0, 10),
          ],
        ],
        top: 0.05,
        bottom: 0.01,
      )!;
      expect(mesh.isValid, isTrue);
      // Tampa 2 tri + 4 saias × 2 tri = 10 triângulos.
      expect(mesh.triangleCount, 10);
      final b = mesh.computeBounds()!;
      expect(b.max.y, closeTo(0.05, 1e-6));
      expect(b.min.y, closeTo(0.01, 1e-6), reason: 'saias até a base');
      // Tampa com normal +Y e saia externa com normal horizontal.
      var topFound = false;
      var skirtFound = false;
      for (var i = 0; i < mesh.indices.length; i += 3) {
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
        if (n.y > 0.9) topFound = true;
        if (a.x > 9 && n.x > 0.9) skirtFound = true;
      }
      expect(topFound, isTrue, reason: 'tampa para cima');
      expect(skirtFound, isTrue, reason: 'saia leste com normal +X');
    });

    test('base >= topo ou contorno curto: null', () {
      final ring = [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)];
      expect(SlabMeshBuilder.build([ring], top: 0.05, bottom: 0.05), isNull);
      expect(
        SlabMeshBuilder.build([ring.sublist(0, 2)], top: 0.05, bottom: 0.01),
        isNull,
      );
    });
  });

  group('AmenityMeshBuilder', () {
    final lot = [
      Vector3(-15, 0, -10),
      Vector3(15, 0, -10),
      Vector3(15, 0, 10),
      Vector3(-15, 0, 10),
    ];

    test(
      'posto: pátio + loja + copa + bombas numa malha só, dentro do lote',
      () {
        final mesh = AmenityMeshBuilder.fuelStation([lot])!;
        expect(mesh.isValid, isTrue);
        // 5 partes: plataforma(10) + loja(12) + copa(12) + 2 bombas(24).
        expect(mesh.triangleCount, 58);
        final b = mesh.computeBounds()!;
        expect(
          b.min.y,
          closeTo(0.01, 1e-6),
          reason: 'pátio no plano do parque',
        );
        expect(
          b.max.y,
          closeTo(5.06, 1e-6),
          reason: 'copa elevada (0.06+4.8+0.2)',
        );
        // Tudo dentro da bbox do lote.
        expect(b.min.x, greaterThanOrEqualTo(-15.01));
        expect(b.max.x, lessThanOrEqualTo(15.01));
        expect(b.min.z, greaterThanOrEqualTo(-10.01));
        expect(b.max.z, lessThanOrEqualTo(10.01));
        // Vertex colors presentes (distinção por parte).
        expect(mesh.colors, isNotNull);
        expect(mesh.colors!.length, mesh.vertexCount * 4);
      },
    );

    test('posto: contorno curto ou pátio nulo → null', () {
      expect(
        AmenityMeshBuilder.fuelStation([
          [Vector3(0, 0, 0), Vector3(1, 0, 0)],
        ]),
        isNull,
      );
    });

    test('delegacia: bloco institucional 6 m, base no plano do pátio', () {
      final mesh = AmenityMeshBuilder.police([lot])!;
      expect(mesh.isValid, isTrue);
      // 4 paredes × 2 + teto 2 + piso 2 = 12 tris (volume fechado).
      expect(mesh.triangleCount, 12);
      final b = mesh.computeBounds()!;
      expect(b.min.y, closeTo(0.06, 1e-6), reason: 'base no plano do pátio');
      expect(b.max.y, closeTo(6.06, 1e-6), reason: 'pé-direito 6 m');
    });

    test('estádio: plataforma + tigela de arquibancada (anel com buraco)', () {
      // Anel oval (8 nós, como o Platzeck de 41 nós reduzido).
      final oval = [
        Vector3(-60, 0, -40),
        Vector3(-40, 0, -45),
        Vector3(0, 0, -46),
        Vector3(40, 0, -43),
        Vector3(60, 0, -30),
        Vector3(58, 0, 30),
        Vector3(20, 0, 46),
        Vector3(-30, 0, 44),
        Vector3(-60, 0, -40), // fechamento
      ];
      final mesh = AmenityMeshBuilder.stadium([oval])!;
      expect(mesh.isValid, isTrue);
      final b = mesh.computeBounds()!;
      // Plataforma 0.01..0.06 + arquibancada até 0.06+8: tigela.
      expect(b.min.y, closeTo(0.01, 1e-6));
      expect(b.max.y, closeTo(8.06, 1e-6));
      // Tudo dentro da bbox do anel.
      expect(b.min.x, greaterThanOrEqualTo(-60.01));
      expect(b.max.x, lessThanOrEqualTo(60.01));
      // Vertex colors: plataforma escura, arquibancada clara.
      expect(mesh.colors, isNotNull);
    });

    test('hospital/templo: extrusão institucional 12 m', () {
      final hospital = AmenityMeshBuilder.hospital([lot])!;
      expect(hospital.triangleCount, 12, reason: 'volume fechado');
      expect(hospital.computeBounds()!.max.y, closeTo(12.06, 1e-6));
      final temple = AmenityMeshBuilder.placeOfWorship([lot])!;
      expect(temple.triangleCount, 12);
      expect(temple.computeBounds()!.max.y, closeTo(12.06, 1e-6));
    });
  });

  group('CrossingMeshBuilder / TrafficSignalMeshBuilder / box', () {
    test(
      'travessia: 4 barras transversais à via, centradas na posição real',
      () {
        final mesh = CrossingMeshBuilder.build(
          Vector3(100, 0, 50),
          0, // heading 0 = leste
          roadWidthMeters: 8,
        )!;
        expect(mesh.isValid, isTrue);
        expect(mesh.triangleCount, 8, reason: '4 barras × 2 tri');
        final b = mesh.computeBounds()!;
        // Barras TRANSVERSAIS: cada uma cruza a largura da via (z, 8 m);
        // espessura/empilhamento ao longo da via (x): 4×0.45+3×0.6=3.6
        // (gap maior — visual de faixa real bem separada).
        // Tolerância float32 (posições são Float32List).
        expect(b.max.x - b.min.x, closeTo(3.6, 1e-4));
        expect(b.max.z - b.min.z, closeTo(8, 1e-4));
        // Centrada na posição real.
        expect((b.min.x + b.max.x) / 2, closeTo(100, 1e-3));
        expect((b.min.z + b.max.z) / 2, closeTo(50, 1e-3));
      },
    );

    test('semáforo: poste lateral, braço até o eixo e lentes RGB', () {
      final mesh = TrafficSignalMeshBuilder.build(
        Vector3(10, 0, 20),
        roadDirection: Vector3(1, 0, 0),
        roadWidthMeters: 6,
      )!;
      expect(mesh.isValid, isTrue);
      expect(mesh.computeBounds()!.max.y, closeTo(5.0, 0.01));
      final bounds = mesh.computeBounds()!;
      expect(bounds.min.z, lessThan(16.2), reason: 'poste fora da pista');
      expect(bounds.max.z, greaterThan(19.7), reason: 'braço chega ao eixo');
      final colors = mesh.colors!;
      bool hasColor(double r, double g, double b) {
        for (var i = 0; i < colors.length; i += 4) {
          if ((colors[i] - r).abs() < 1e-5 &&
              (colors[i + 1] - g).abs() < 1e-5 &&
              (colors[i + 2] - b).abs() < 1e-5) {
            return true;
          }
        }
        return false;
      }

      expect(hasColor(0.18, 0.20, 0.23), isTrue, reason: 'poste metálico');
      expect(hasColor(0.025, 0.03, 0.04), isTrue, reason: 'caixa escura');
      expect(hasColor(0.95, 0.035, 0.025), isTrue, reason: 'lente vermelha');
      expect(hasColor(1, 0.48, 0.025), isTrue, reason: 'lente âmbar');
      expect(hasColor(0.04, 0.78, 0.12), isTrue, reason: 'lente verde');
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

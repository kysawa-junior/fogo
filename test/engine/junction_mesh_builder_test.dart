import 'dart:math' as math;

import 'package:fogo/engine/geometry/mesh_data.dart';
import 'package:fogo/engine/mesh/junction_mesh_builder.dart';
import 'package:fogo/engine/scene/visual_style.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final res = Vector3(0.40, 0.42, 0.46); // residencial
  final pri = Vector3(0.86, 0.62, 0.40); // primária

  /// Contém? varre os triângulos do leque (ponto-in-triângulo).
  bool contains(MeshData mesh, Vector3 q) {
    for (var i = 0; i < mesh.indices.length; i += 3) {
      final a = _v(mesh, mesh.indices[i]);
      final b = _v(mesh, mesh.indices[i + 1]);
      final c = _v(mesh, mesh.indices[i + 2]);
      if (_inTri(q, a, b, c)) return true;
    }
    return false;
  }

  MeshData? build(List<JunctionArm> arms, {Vector3? priority}) {
    return JunctionMeshBuilder.build(
      Vector3(0, 0, 0),
      arms,
      priorityColor: priority,
    );
  }

  group('JunctionMeshBuilder — caixas de interseção', () {
    test('cruzamento ortogonal 4 braços: caixa exata, sem entalhe', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(-1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(0, 0, 1),
          halfWidthMeters: 3,
          color: res,
        ),
        JunctionArm(
          direction: Vector3(0, 0, -1),
          halfWidthMeters: 3,
          color: res,
        ),
      ])!;
      expect(pad.isValid, isTrue);
      // Cantos EXATOS em (±3, ±3): as bordas da caixa continuam as
      // bordas das vias — nenhum canto cortado (regressão do leque v1).
      final b = pad.computeBounds()!;
      expect(b.min.x, closeTo(-3, 1e-4));
      expect(b.max.x, closeTo(3, 1e-4));
      expect(b.min.z, closeTo(-3, 1e-4));
      expect(b.max.z, closeTo(3, 1e-4));
      // Os quatro cantos precisam estar cobertos (v1 deixava 4 entalhes).
      for (final corner in [
        Vector3(2.95, 0, 2.95),
        Vector3(-2.95, 0, 2.95),
        Vector3(2.95, 0, -2.95),
        Vector3(-2.95, 0, -2.95),
      ]) {
        expect(contains(pad, corner), isTrue, reason: 'canto $corner coberto');
      }
    });

    test('cruzamento oblíquo (45°): contorno válido e coerente', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(-1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(1, 0, 1)..normalize(),
          halfWidthMeters: 3,
          color: res,
        ),
        JunctionArm(
          direction: Vector3(-1, 0, -1)..normalize(),
          halfWidthMeters: 3,
          color: res,
        ),
      ])!;
      expect(pad.isValid, isTrue);
      expect(pad.computeBounds()!.min.y, closeTo(0.04, 1e-6));
      // O centro pertence à junção em qualquer caso.
      expect(contains(pad, Vector3.zero()), isTrue);
    });

    test('bifurcação em Y: sem pico, braços distintos', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(math.cos(2.4), 0, math.sin(2.4)),
          halfWidthMeters: 3,
          color: res,
        ),
        JunctionArm(
          direction: Vector3(math.cos(-2.4), 0, math.sin(-2.4)),
          halfWidthMeters: 3,
          color: res,
        ),
      ])!;
      expect(pad.isValid, isTrue);
      final b = pad.computeBounds()!;
      // Cunha aguda entre os braços traseiros: limite de miter 2h segura
      // o contorno (nada além de 2×3 m do nó em direção ao canto).
      final span = (b.max.x - b.min.x) + (b.max.z - b.min.z);
      expect(span, lessThan(20), reason: 'sem picos de miter');
    });

    test('T com larguras diferentes: cantos seguem as bordas reais', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 5,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(-1, 0, 0),
          halfWidthMeters: 5,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(0, 0, 1),
          halfWidthMeters: 2,
          color: res,
        ),
      ])!;
      expect(pad.isValid, isTrue);
      // Cantos frontais = interseção das bordas: (±2, ±5).
      final b = pad.computeBounds()!;
      expect(b.max.x, closeTo(2, 1e-4), reason: 'borda da via estreita');
      expect(b.max.z, closeTo(5, 1e-4), reason: 'borda da via larga');
      expect(contains(pad, Vector3(1.9, 0, 4.9)), isTrue);
      expect(
        contains(pad, Vector3(0, 0, -4.9)),
        isTrue,
        reason: 'fundo do T coberto até a borda da via larga',
      );
    });

    test(
      'rotatória (4 braços irregulares + anel): válida e cobre o centro',
      () {
        final pad = build([
          JunctionArm(
            direction: Vector3(1, 0, 0),
            halfWidthMeters: 3.5,
            color: pri,
          ),
          JunctionArm(
            direction: Vector3(math.cos(1.2), 0, math.sin(1.2)),
            halfWidthMeters: 2.5,
            color: res,
          ),
          JunctionArm(
            direction: Vector3(math.cos(2.8), 0, math.sin(2.8)),
            halfWidthMeters: 2.5,
            color: res,
          ),
          JunctionArm(
            direction: Vector3(-1, 0, 0.2)..normalize(),
            halfWidthMeters: 3,
            color: pri,
          ),
          JunctionArm(
            direction: Vector3(0, 0, -1),
            halfWidthMeters: 3,
            color: pri,
          ),
        ])!;
        expect(pad.isValid, isTrue);
        for (var i = 0; i < pad.indices.length; i += 3) {
          final a = _v(pad, pad.indices[i]);
          final b = _v(pad, pad.indices[i + 1]);
          final c = _v(pad, pad.indices[i + 2]);
          final area = (b - a).cross(c - a).length / 2;
          expect(area, greaterThan(1e-4), reason: 'sem triângulos degenerados');
        }
        expect(contains(pad, Vector3.zero()), isTrue);
      },
    );

    test('junção em L com braços de larguras diferentes: caixa coerente', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3.5,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(0, 0, 1),
          halfWidthMeters: 5,
          color: res,
        ),
      ])!;
      expect(pad.isValid, isTrue);
      final b = pad.computeBounds()!;
      expect(b.max.x, closeTo(5, 1e-4), reason: 'canto na borda da via larga');
      expect(b.max.z, closeTo(3.5, 1e-4), reason: 'canto na borda da via fina');
      expect(
        contains(pad, Vector3(4.9, 0, 3.4)),
        isTrue,
        reason: 'canto externo coberto (era entalhe no v1)',
      );
    });

    test('vias colineares de mesma largura: pad degenerada descartada', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(-1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
      ]);
      expect(pad, isNull, reason: 'capas retas já se tocam sem fresta');
    });

    test('menos de 2 braços: sem pad', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
      ]);
      expect(pad, isNull);
    });

    test('winding +Y em todos os triângulos', () {
      final pad = build([
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(0, 0, 1),
          halfWidthMeters: 3,
          color: res,
        ),
        JunctionArm(
          direction: Vector3(-1, 0, 0),
          halfWidthMeters: 3,
          color: res,
        ),
      ])!;
      for (var i = 0; i < pad.indices.length; i += 3) {
        final a = _v(pad, pad.indices[i]);
        final b = _v(pad, pad.indices[i + 1]);
        final c = _v(pad, pad.indices[i + 2]);
        final n = (b - a).cross(c - a);
        expect(n.y, greaterThan(0), reason: 'triângulo $i');
      }
    });

    test(
      'degradê localizado: centro prioritário, cantos mistos, bocas reais',
      () {
        final pad = build([
          JunctionArm(
            direction: Vector3(1, 0, 0),
            halfWidthMeters: 3,
            color: pri,
          ),
          JunctionArm(
            direction: Vector3(0, 0, 1),
            halfWidthMeters: 3,
            color: res,
          ),
        ], priority: pri)!;
        expect(pad.colors![0], closeTo(pri.x, 1e-6));
        // Cantos = média das duas vias (transição estrutural, localizada).
        final found = <double>{};
        for (var i = 4; i < pad.colors!.length; i += 4) {
          found.add(pad.colors![i]);
        }
        expect(
          found.any((c) => (c - (pri.x + res.x) / 2).abs() < 1e-5),
          isTrue,
          reason: 'canto com cor misturada',
        );
        expect(
          found.any((c) => (c - res.x).abs() < 1e-5),
          isTrue,
          reason: 'boca com cor da própria via',
        );
      },
    );

    test('detector de auto-interseção: laço cruza, convexo não', () {
      // Laço (diagonais que se cruzam no miolo): inválido.
      final bow = [
        Vector3(0, 0, 0),
        Vector3(10, 0, 10),
        Vector3(10, 0, 0),
        Vector3(0, 0, 10),
      ];
      expect(JunctionMeshBuilder.hasSelfIntersection(bow), isTrue);
      // Convexo: válido.
      final box = [
        Vector3(-3, 0, -3),
        Vector3(3, 0, -3),
        Vector3(3, 0, 3),
        Vector3(-3, 0, 3),
      ];
      expect(JunctionMeshBuilder.hasSelfIntersection(box), isFalse);
    });

    test('robustez: bateria de junções anômalas nunca gera malha inválida', () {
      // Configurações patológicas (larguras muito distintas, ângulos
      // extremos): o resultado é sempre null ou uma malha VÁLIDA —
      // nunca um polígono furado/auto-intersectado.
      final cases = <List<JunctionArm>>[
        [
          JunctionArm(
            direction: Vector3(1, 0, 0),
            halfWidthMeters: 0.2,
            color: pri,
          ),
          JunctionArm(
            direction: Vector3(-1, 0, 0),
            halfWidthMeters: 10,
            color: res,
          ),
        ],
        [
          JunctionArm(
            direction: Vector3(1, 0, 0),
            halfWidthMeters: 10,
            color: pri,
          ),
          JunctionArm(
            direction: Vector3(math.cos(0.1), 0, math.sin(0.1)),
            halfWidthMeters: 1,
            color: res,
          ),
          JunctionArm(
            direction: Vector3(-1, 0, 0),
            halfWidthMeters: 3,
            color: res,
          ),
        ],
        [
          JunctionArm(
            direction: Vector3(1, 0, 0),
            halfWidthMeters: 2,
            color: pri,
          ),
          JunctionArm(
            direction: Vector3(math.cos(3.0), 0, math.sin(3.0)),
            halfWidthMeters: 2,
            color: res,
          ),
          JunctionArm(
            direction: Vector3(math.cos(3.1), 0, math.sin(3.1)),
            halfWidthMeters: 2,
            color: pri,
          ),
        ],
      ];
      for (final arms in cases) {
        final mesh = JunctionMeshBuilder.build(Vector3(0, 0, 0), arms);
        if (mesh != null) {
          expect(mesh.isValid, isTrue, reason: 'configuração anômala');
          for (var i = 0; i < mesh.indices.length; i += 3) {
            final a = _v(mesh, mesh.indices[i]);
            final b = _v(mesh, mesh.indices[i + 1]);
            final c = _v(mesh, mesh.indices[i + 2]);
            expect(
              (b - a).cross(c - a).length,
              greaterThan(2e-4),
              reason: 'sem triângulos degenerados',
            );
          }
        }
      }
    });

    test('pad respeita elevação do estilo', () {
      const style = Fogo3DStyle(padLiftMeters: 0.25);
      final mesh = JunctionMeshBuilder.build(Vector3(0, 0, 0), [
        JunctionArm(
          direction: Vector3(1, 0, 0),
          halfWidthMeters: 3,
          color: pri,
        ),
        JunctionArm(
          direction: Vector3(0, 0, 1),
          halfWidthMeters: 3,
          color: res,
        ),
      ], style: style)!;
      expect(mesh.computeBounds()!.min.y, closeTo(0.25, 1e-6));
    });
  });
}

bool _inTri(Vector3 p, Vector3 a, Vector3 b, Vector3 c) {
  double sign(Vector3 p1, Vector3 v1, Vector3 v2) =>
      (p1.x - v2.x) * (v1.z - v2.z) - (v1.x - v2.x) * (p1.z - v2.z);
  final d1 = sign(p, a, b);
  final d2 = sign(p, b, c);
  final d3 = sign(p, c, a);
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}

Vector3 _v(MeshData mesh, int i) => Vector3(
  mesh.positions[i * 3],
  mesh.positions[i * 3 + 1],
  mesh.positions[i * 3 + 2],
);

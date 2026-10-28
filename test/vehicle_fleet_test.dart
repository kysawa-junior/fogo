import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/mesh/vehicle_mesh_builder.dart';
import 'package:fogo/engine/scene/vehicle_system.dart';
import 'package:vector_math/vector_math.dart' as vmm;
import 'package:vector_math/vector_math_64.dart' as vm;

/// Frota simulada: movimento contínuo ao longo da geometria, respeito a
/// oneway e alinhamento de yaw — puro, sem cena.
void main() {
  // Malha em T: A(0,0)→B(100,0) horizontal; C(50,-100)→B vertical.
  // B é a junção (nó compartilhado 'B').
  FleetEdge edge({
    required String id,
    required String start,
    required String end,
    required List<vm.Vector3> points,
    bool oneway = false,
  }) => FleetEdge(
    points: points,
    surfaceY: 0,
    oneway: oneway,
    startNodeId: start,
    endNodeId: end,
  );

  final edges = [
    edge(
      id: 'h',
      start: 'A',
      end: 'B',
      points: [
        vm.Vector3(0, 0, 0),
        vm.Vector3(50, 0, 0),
        vm.Vector3(100, 0, 0),
      ],
    ),
    edge(
      id: 'v',
      start: 'C',
      end: 'B',
      points: [
        vm.Vector3(50, 0, -100),
        vm.Vector3(50, 0, -50),
        vm.Vector3(50, 0, 0),
      ],
    ),
  ];

  group('FleetEdge.sample', () {
    test('interpola ao longo da polilinha (com dobra)', () {
      final e = edges[0];
      final (p0, d0) = e.sample(0, true);
      expect(p0.x, 0);
      expect(d0.x, 1);
      final (pMid, _) = e.sample(25, true);
      expect(pMid.x, closeTo(25, 1e-6));
      final (pDobra, _) = e.sample(75, true); // após a dobra? não há — reta
      expect(pDobra.x, closeTo(75, 1e-6));
      // Reverso: s medido da ENTRADA pelo fim.
      final (pRev, dRev) = e.sample(0, false);
      expect(pRev.x, 100);
      expect(dRev.x, -1);
    });

    test('altura = superfície da via (não o y projetado)', () {
      final e = FleetEdge(
        points: [vm.Vector3(0, 0, 0), vm.Vector3(10, 0, 0)],
        surfaceY: 4.5,
        oneway: false,
        startNodeId: 'a',
        endNodeId: 'b',
      );
      final (p, _) = e.sample(5, true);
      expect(p.y, 4.5);
    });
  });

  group('VehicleFleet.tick', () {
    test('movimento contínuo: posição avança, nunca teleporta', () {
      final fleet = VehicleFleet(edges: edges, vehicleCount: 1);
      final v = fleet.vehicles.single;
      final startX = v.x, startZ = v.z;
      fleet.tick(1.0); // 13 m
      // Deslocamento EUCLIDIANO (spawn pode cair na aresta vertical,
      // onde x é fixo e o movimento acontece em z).
      final disp = math.sqrt(
        (v.x - startX) * (v.x - startX) + (v.z - startZ) * (v.z - startZ),
      );
      expect(disp, greaterThan(5)); // avançou de verdade
      expect(disp, lessThan(20)); // ~13 m, sem salto
      // Mil ticks: sem NaN, sempre sobre a malha (x∈[0,100] na reta h,
      // ou z=-100..0 na vertical).
      for (var i = 0; i < 1000; i++) {
        fleet.tick(0.1);
        expect(v.x.isFinite, isTrue);
        expect(v.z.isFinite, isTrue);
        expect(v.x, inInclusiveRange(-1, 101));
        expect(v.z, inInclusiveRange(-101, 1));
      }
    });

    test('oneway respeitado: não entra pela saída', () {
      // v (C→B) oneway: só pode ser percorrida C→B.
      final onewayEdges = [
        edge(
          id: 'h',
          start: 'A',
          end: 'B',
          points: [vm.Vector3(0, 0, 0), vm.Vector3(100, 0, 0)],
        ),
        edge(
          id: 'v',
          start: 'C',
          end: 'B',
          points: [vm.Vector3(50, 0, -100), vm.Vector3(50, 0, 0)],
          oneway: true,
        ),
      ];
      final fleet = VehicleFleet(edges: onewayEdges, vehicleCount: 1);
      final v = fleet.vehicles.single;
      // Força o estado: vindo da horizontal em direção a B (fim em B).
      v.edgeIndex = 0;
      v.forward = true;
      v.s = 100.0;
      v.x = 100;
      fleet.tick(0.001);
      // Só há UMA opção na junção B: a vertical oneway — mas ela só é
      // dirigível ENTRANDO por C (start). A partir de B, entrar por B é
      // proibido → U-turn espelhado na horizontal.
      expect(v.edgeIndex, 0);
      expect(v.forward, isFalse);
      // U-turn espelhado: s = length − (100 + 13·dt) ≈ −0.013 → a
      // posição física continua em x=100 (B). Medimos a posição.
      expect(v.s, closeTo(0, 0.1));
      expect(v.x, closeTo(100, 0.1));
    });

    test('junto na junção: escolhe continuação dirigível (sentido ok)', () {
      // Bidirecionais: de B dá para ir para A (h reverso) ou C (v reverso).
      final fleet = VehicleFleet(edges: edges, vehicleCount: 1);
      final v = fleet.vehicles.single;
      v.edgeIndex = 0;
      v.forward = true;
      v.s = 99.9; // a centímetros de B
      for (var i = 0; i < 50; i++) {
        fleet.tick(0.1);
        // Nunca ultrapassa os limites da malha (virou em B).
        expect(v.x, inInclusiveRange(-1, 101));
        expect(v.z, inInclusiveRange(-101, 1));
        // Direção acompanha o movimento: na reta horizontal o yaw é
        // paralelo ao eixo X (heading ≡ 0 mod π → |sin| pequeno).
        final horizontalAxis = (v.z.abs() < 1);
        if (horizontalAxis) {
          expect(math.sin(v.heading).abs(), lessThan(0.35));
        }
      }
    });
  });

  group('vehicleGroundOffset (alinhamento dos modelos glTF)', () {
    // AABB do modelo (glTF Y-up): x∈[0,4], y∈[0,2], z∈[0,1.9].
    final b = vmm.Aabb3.minMax(vmm.Vector3(0, 0, 0), vmm.Vector3(4, 2, 1.9));

    test('yaw π/2: extents trocam x↔z, chão permanece em y=0', () {
      final o = vehicleGroundOffset(b, math.pi / 2);
      // Centro (2,1,0.95) girado π/2 → (0.95,1,−2); offset = −centro girado
      // com y = hy − cy (= 0: bounds já nascem com chão em y=0). Tolerância
      // 1e-6: a lib principal do vector_math armazena em 32 bits.
      expect(o.x, closeTo(-0.95, 1e-6));
      expect(o.y, closeTo(0, 1e-6));
      expect(o.z, closeTo(2, 1e-6));
    });

    test('yaw 0: offset = −centro', () {
      final o0 = vehicleGroundOffset(b, 0);
      expect(o0.x, closeTo(-2, 1e-6));
      expect(o0.y, closeTo(0, 1e-6));
      expect(o0.z, closeTo(-0.95, 1e-6));
    });
  });

  test('spawn espalhado e determinístico', () {
    final a = VehicleFleet(edges: edges, vehicleCount: 4);
    final b = VehicleFleet(edges: edges, vehicleCount: 4);
    expect(a.vehicles.length, 4);
    for (var i = 0; i < 4; i++) {
      expect(a.vehicles[i].edgeIndex, b.vehicles[i].edgeIndex);
      expect(a.vehicles[i].x, b.vehicles[i].x);
    }
  });
}

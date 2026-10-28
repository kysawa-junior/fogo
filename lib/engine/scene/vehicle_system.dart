import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

/// Tipo de viatura simulada.
enum VehicleKind { police, fire }

/// Aresta dirigível do grafo de viaturas: geometria projetada
/// (start→end = ordem dos pontos da via — MESMO sentido do OSM).
class FleetEdge {
  FleetEdge({
    required this.points,
    required this.surfaceY,
    required this.oneway,
    required this.startNodeId,
    required this.endNodeId,
  });

  final List<vm.Vector3> points;
  final double surfaceY;
  final bool oneway;
  final String startNodeId;
  final String endNodeId;

  late final List<double> cumulative = _cumulative();
  late final double length = cumulative.last;

  List<double> _cumulative() {
    final out = <double>[0];
    for (var i = 1; i < points.length; i++) {
      out.add(out.last + (points[i] - points[i - 1]).length);
    }
    return out;
  }

  /// Posição e direção a `s` metros da ENTRADA (respeita [forward]).
  /// A altura é a SUPERFÍCIE da via ([surfaceY] — pontes elevam) —
  /// pontos projetados vêm com y≈0.
  (vm.Vector3 pos, vm.Vector3 dir) sample(double s, bool forward) {
    final n = points.length;
    if (n < 2) {
      return (
        vm.Vector3(points.first.x, surfaceY, points.first.z),
        vm.Vector3(1, 0, 0),
      );
    }
    final clamped = s.clamp(0.0, length);
    // Índice do ponto inicial do sub-segmento que contém `s`.
    var lo = 0, hi = cumulative.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (cumulative[mid] <= clamped) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = forward ? points[lo] : points[n - 1 - lo];
    final b = forward ? points[lo + 1] : points[n - 1 - lo - 1];
    final segLen = (cumulative[lo + 1] - cumulative[lo]).clamp(1e-6, 1e9);
    final t = ((clamped - cumulative[lo]) / segLen).clamp(0.0, 1.0);
    return (
      vm.Vector3(a.x + (b.x - a.x) * t, surfaceY, a.z + (b.z - a.z) * t),
      (b - a)..normalize(),
    );
  }
}

/// Estado de uma viatura em movimento.
class Vehicle {
  Vehicle({
    required this.id,
    required this.kind,
    required this.edgeIndex,
    required this.forward,
    required this.s,
    required this.speedMps,
  });

  final String id;
  final VehicleKind kind;
  final double speedMps;

  int edgeIndex;
  bool forward; // true = no sentido dos pontos da via
  double s; // metros a partir da entrada na aresta
  double x = 0, y = 0, z = 0;
  double heading = 0; // yaw (rad): mesh +X → direção do movimento
}

/// Lift da viatura sobre a capa da via (m): separação REAL de
/// profundidade. O depthLayer do material só resolve superfícies
/// COPLANARES — e o empurrão dele cresce longe da origem do mundo
/// (cidades a ~km), então a via rasante "avança" sobre o carro cujo
/// chão encosta na capa. Meio metro acima, a via nunca pinta por cima
/// (e 0.5 m é invisível na escala cartográfica).
const double kVehicleSurfaceLift = 0.5;

/// Frota que circula pela malha viária: segue a geometria das vias,
/// respeita oneway (OSM), escolhe continuação nos nós compartilhados
/// (sem U-turn salvo beco) e amortece o yaw para o alinhamento suave.
/// Puro — o tick pertence ao dono único da câmera (Map2DView).
class VehicleFleet {
  VehicleFleet({required this.edges, required this.vehicleCount}) {
    _spawn(vehicleCount);
  }

  /// Grafo dirigível injetado (o engine monta das vias OSM).
  final List<FleetEdge> edges;
  final int vehicleCount;
  final vehicles = <Vehicle>[];
  int revision = 0;

  /// Congela a simulação (diagnóstico visual de sobreposição via×
  /// viatura: cena estática sob a câmera).
  bool frozen = false;

  void _spawn(int count) {
    if (edges.isEmpty) return;
    for (var k = 0; k < count; k++) {
      // Espalhamento determinístico: aresta por stride + offset por hash.
      final idx =
          (k * edges.length ~/ count + _stableHash('spawn$k')) % edges.length;
      final edge = edges[idx];
      final forward = _stableHash('dir$k').isOdd;
      final kind = k % 5 < 3 ? VehicleKind.police : VehicleKind.fire;
      vehicles.add(
        Vehicle(
          id: '$k',
          kind: kind,
          edgeIndex: idx,
          forward: forward,
          s: _stableHash('s$k') % 1000 / 1000 * edge.length,
          speedMps: kind == VehicleKind.police ? 13.0 : 11.0,
        ),
      );
    }
    _applyAll();
  }

  void tick(double dt) {
    if (dt <= 0 || frozen) return;
    for (final v in vehicles) {
      v.s += v.speedMps * dt;
      var guard = 0;
      while (v.s >= edges[v.edgeIndex].length && guard++ < 8) {
        final edge = edges[v.edgeIndex];
        // Nó de SAÍDA no sentido atual da travessia.
        final exit = v.forward ? edge.endNodeId : edge.startNodeId;
        // Continuações dirigíveis: entra pelo start → sempre; pelo end →
        // só se a via não for oneway (respeita o sentido do OSM).
        final options = <int>[];
        for (var i = 0; i < edges.length; i++) {
          if (i == v.edgeIndex) continue; // nunca U-turn pela mesma aresta
          final e = edges[i];
          if (e.startNodeId == exit) options.add(i);
          if (!e.oneway && e.endNodeId == exit) options.add(i);
        }
        if (options.isEmpty) {
          // Beco sem saída: U-turn espelhado (mesma posição física).
          v.forward = !v.forward;
          v.s = edge.length - v.s;
          break;
        }
        final next =
            options[_stableHash('${v.id}:$exit:${v.s.round()}') %
                options.length];
        final nextEdge = edges[next];
        // Entra pelo start → sentido dos pontos; pelo end → contra.
        // (oneway só entra nas opções pelo start — ver filtro acima.)
        v.forward = nextEdge.startNodeId == exit;
        v.s -= edge.length;
        v.edgeIndex = next;
      }
      _apply(v, dt);
    }
    revision++;
  }

  void _applyAll() {
    for (final v in vehicles) {
      _apply(v, 0);
    }
  }

  void _apply(Vehicle v, double dt) {
    final edge = edges[v.edgeIndex];
    final (pos, dir) = edge.sample(v.s, v.forward);
    v.x = pos.x;
    v.y = pos.y + kVehicleSurfaceLift; // em cima da capa, não coplanar
    v.z = pos.z;
    final target = math.atan2(-dir.z, dir.x); // +X local → direção
    var delta = target - v.heading;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    final t = dt <= 0 ? 1.0 : 1 - math.exp(-10 * dt);
    v.heading += delta * t;
  }
}

int _stableHash(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}

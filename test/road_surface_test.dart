import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/vector/road_surface/road_surface.dart';
import 'package:fogo/features/map/vector/vector_data/vector_data.dart';

bool _containsContour(List<double> contour, double xMeters, double yMeters) {
  bool inside = false;
  final int count = contour.length ~/ 2;
  for (int i = 0, j = count - 1; i < count; j = i++) {
    final double yi = contour[i * 2] * 111132.0;
    final double xi = contour[i * 2 + 1] * 111320.0;
    final double yj = contour[j * 2] * 111132.0;
    final double xj = contour[j * 2 + 1] * 111320.0;
    final bool crosses =
        (yi > yMeters) != (yj > yMeters) &&
        xMeters < (xj - xi) * (yMeters - yi) / (yj - yi) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

bool _containsSurface(RoadSurface surface, double xMeters, double yMeters) {
  if (surface.contours.isEmpty ||
      !_containsContour(surface.contours.first, xMeters, yMeters)) {
    return false;
  }
  return surface.contours.length == 1 ||
      !_containsContour(surface.contours[1], xMeters, yMeters);
}

double _contourArea(List<double> contour) {
  final int count = contour.length ~/ 2;
  double area = 0;
  for (int i = 0; i < count; i++) {
    final int next = (i + 1) % count;
    final double x0 = contour[i * 2 + 1] * 111320.0;
    final double y0 = contour[i * 2] * 111132.0;
    final double x1 = contour[next * 2 + 1] * 111320.0;
    final double y1 = contour[next * 2] * 111132.0;
    area += x0 * y1 - x1 * y0;
  }
  return area / 2;
}

ui.Path _toNonZeroPath(RoadSurface surface) {
  final ui.Path path = ui.Path()..fillType = ui.PathFillType.nonZero;
  for (final List<double> contour in surface.contours) {
    path.moveTo(contour[1] * 111320.0, contour[0] * 111132.0);
    for (int i = 1; i < contour.length ~/ 2; i++) {
      path.lineTo(contour[i * 2 + 1] * 111320.0, contour[i * 2] * 111132.0);
    }
    path.close();
  }
  return path;
}

void main() {
  group('RoadSurfaceBuilder — superfícies com bordas laterais', () {
    // segmento reto de ~111 m no equador: 0°,0° → 0°,0.001°
    final straight = <double>[0, 0, 0, 0.001];

    test('linha reta gera anel fechado com bordas a ±h', () {
      const double h = 5; // meia-largura 5 m
      final RoadSurface? surface = RoadSurfaceBuilder.build(straight, h);
      expect(surface, isNotNull);
      final List<double> ring = surface!.contours.single;
      final int n = ring.length ~/ 2;
      expect(n, greaterThanOrEqualTo(16), reason: 'retângulo + 2 caps');
      // existem pontos ~h ao norte (lat +) e ao sul (lat -) do eixo
      final List<double> lats = [for (int i = 0; i < n; i++) ring[i * 2]];
      final double maxLat = lats.reduce(math.max);
      final double minLat = lats.reduce(math.min);
      final double hDeg = h / 111132.0;
      expect(maxLat, closeTo(hDeg, hDeg * 0.05));
      expect(minLat, closeTo(-hDeg, hDeg * 0.05));
    });

    test('caps arredondados extrapolam a via em ~h (beco sem saída)', () {
      const double h = 8;
      final List<double> ring = RoadSurfaceBuilder.build(
        straight,
        h,
      )!.contours.single;
      final List<double> lngs = [
        for (int i = 0; i < ring.length ~/ 2; i++) ring[i * 2 + 1],
      ];
      final double minLng = lngs.reduce(math.min);
      // cap atrás do início: ~ -h metros (não quadrado, não além de h)
      final double hDeg = h / 111320.0;
      expect(minLng, lessThan(-hDeg * 0.8));
      expect(minLng, greaterThan(-hDeg * 1.3));
    });

    test('curva em L cobre o canto interno sem entalhe diagonal', () {
      // L: 100m leste + 100m norte
      final List<double> elbow = <double>[
        0, 0, //
        0, 100 / 111320.0, //
        100 / 111132.0, 100 / 111320.0,
      ];
      final RoadSurface surface = RoadSurfaceBuilder.build(elbow, 5)!;
      expect(surface.contours, hasLength(1));
      expect(
        _containsContour(surface.contours.single, 97, 3),
        isTrue,
        reason: 'ponto a 3m de ambos os trechos não pode cair no entalhe',
      );
    });

    test('limita miter a 2× meia-largura em curva aguda', () {
      const double halfWidth = 5;
      const double leg = 100;
      final double diagonal = leg / math.sqrt2;
      final List<double> sharpTurn = [
        0,
        0,
        0,
        leg / 111320.0,
        diagonal / 111132.0,
        (leg - diagonal) / 111320.0,
      ];

      final RoadSurface surface = RoadSurfaceBuilder.build(
        sharpTurn,
        halfWidth,
      )!;
      final List<double> contour = surface.contours.single;
      final List<double> distancesFromJoin = [
        for (int i = 0; i < contour.length ~/ 2; i++)
          math.sqrt(
            math.pow(contour[i * 2 + 1] * 111320.0 - leg, 2) +
                math.pow(contour[i * 2] * 111132.0, 2),
          ),
      ].where((double distance) => distance < 20).toList();

      expect(distancesFromJoin, isNotEmpty);
      expect(
        distancesFromJoin.reduce(math.max),
        lessThanOrEqualTo(halfWidth * 2 + 0.01),
        reason: 'mitre acima de 2h deve virar bevel sem ponta aguda',
      );
    });

    test('rotatória fecha último→primeiro e mantém centro vazio', () {
      // quadrado fechado de ~50 m
      final double d = 50 / 111320.0;
      final List<double> loop = <double>[
        0, 0, 0, d, d, d, d, 0, 0, 0, // fecha
      ];
      final RoadSurface surface = RoadSurfaceBuilder.build(loop, 4)!;
      expect(
        RoadSurfaceBuilder.build([...loop, 0, 0], 4)?.contours,
        hasLength(2),
        reason: 'fechamento repetido não cria segmento de comprimento zero',
      );
      expect(surface.contours, hasLength(2), reason: 'faixa anular');
      expect(
        _contourArea(surface.contours[0]) * _contourArea(surface.contours[1]),
        lessThan(0),
        reason: 'contornos opostos preservam o furo no fill nonzero',
      );
      expect(
        _containsSurface(surface, 25, 2),
        isTrue,
        reason: 'trecho horizontal do anel',
      );
      expect(
        _containsSurface(surface, 0, 25),
        isTrue,
        reason: 'segmento de fechamento último→primeiro',
      );
      expect(
        _containsSurface(surface, 25, 25),
        isFalse,
        reason: 'centro da rotatória fica vazio',
      );
      final ui.Path path = _toNonZeroPath(surface);
      expect(path.contains(const ui.Offset(0, 25)), isTrue);
      expect(path.contains(const ui.Offset(25, 25)), isFalse);
    });

    test('pontos consecutivos degenerados são removidos antes dos joins', () {
      const List<double> withDuplicate = [0, 0, 0, 0, 0, 0.001];
      final RoadSurface clean = RoadSurfaceBuilder.build(straight, 5)!;
      final RoadSurface deduplicated = RoadSurfaceBuilder.build(
        withDuplicate,
        5,
      )!;
      expect(deduplicated.contours.single, clean.contours.single);
      expect(RoadSurfaceBuilder.build(<double>[0, 0, 0, 0], 5), isNull);
    });

    test('geometria original preservada (dados não mutam)', () {
      final List<double> center = [...straight];
      RoadSurfaceBuilder.build(center, 5);
      expect(center, straight, reason: 'linha central intocada');
    });

    test('larguras insuficientes retornam null (guarda)', () {
      expect(RoadSurfaceBuilder.build(straight, 0), isNull);
      expect(RoadSurfaceBuilder.build(<double>[0, 0], 5), isNull);
    });
  });

  group('RoadSurfaceCache — por faixa de zoom', () {
    test('bucket quantiza e reutiliza dentro da faixa', () {
      expect(RoadSurfaceCache.bucketFor(15.1), 15.0);
      expect(RoadSurfaceCache.bucketFor(15.2), 15.25);
      const road = MapRoad(
        cls: RoadClass.residential,
        name: 'Teste',
        oneway: false,
        bridge: false,
        tunnel: false,
        flatCoords: [0, 0, 0, 0.001],
        bbox: [0, 0, 0, 0.001],
      );
      final cache = RoadSurfaceCache(16.0);
      final RoadSurface a = cache.fillSurface(road, 5);
      final RoadSurface b = cache.fillSurface(road, 5);
      final RoadSurface changedWidth = cache.fillSurface(road, 4);
      expect(identical(a, b), isTrue, reason: 'cache reutiliza a geometria');
      expect(
        identical(a, changedWidth),
        isFalse,
        reason: 'cache recompõe a superfície se a largura em metros muda',
      );
    });
  });
}

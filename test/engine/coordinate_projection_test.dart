import 'dart:math' as math;

import 'package:fogo/engine/fogo_engine.dart'
    show CoordinateProjector, OrbitCamera, Vector3, Aabb3;
import 'package:fogo/engine/geo/geo_bounds.dart';
import 'package:fogo/engine/geo/geo_coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bounds = GeoBounds(
    west: -49.975,
    south: -22.235,
    east: -49.925,
    north: -22.200,
  );
  final projector = CoordinateProjector.forBounds(bounds);

  test('centro da bounds é a origem (0,0,0)', () {
    final center = projector.project(bounds.center);
    expect(center.x, closeTo(0, 1e-6));
    expect(center.y, 0);
    expect(center.z, closeTo(0, 1e-6));
  });

  test('convenção de eixos: +X leste, +Z sul, +Y elevação', () {
    final east = projector.project(GeoCoordinate(-22.2175, -49.94));
    final south = projector.project(GeoCoordinate(-22.2275, -49.95));
    expect(east.x, greaterThan(0), reason: 'lon maior → x maior (leste)');
    expect(east.z, closeTo(0, 1e-9));
    expect(south.z, greaterThan(0), reason: 'lat menor → z maior (sul)');
    expect(south.x, closeTo(0, 1e-6));

    final elevated = projector.project(
      const GeoCoordinate(-22.2175, -49.95, elevation: 12),
    );
    expect(elevated.y, 12);
  });

  test('escala em metros é plausível (~1° lat ≈ 111 km)', () {
    final a = projector.project(GeoCoordinate(-22.0, -49.95));
    final b = projector.project(GeoCoordinate(-23.0, -49.95));
    expect((b.z - a.z).abs(), closeTo(111195, 300));
  });

  test('round-trip project → unproject preserva lat/lon', () {
    const p = GeoCoordinate(-22.2213, -49.9487);
    final round = projector.unproject(projector.project(p));
    expect(round.latitude, closeTo(p.latitude, 1e-9));
    expect(round.longitude, closeTo(p.longitude, 1e-9));
  });

  test('elevação ausente nunca é inventada (y=0, unproject → null)', () {
    final flat = projector.project(GeoCoordinate(-22.0, -49.0));
    expect(flat.y, 0);
    expect(projector.unproject(flat).elevation, isNull);
  });

  test('GeoBounds: contains e union', () {
    expect(bounds.contains(bounds.center), isTrue);
    expect(bounds.contains(const GeoCoordinate(0, 0)), isFalse);
    final other = GeoBounds(
      west: -50.0,
      south: -22.4,
      east: -49.9,
      north: -22.1,
    );
    final union = bounds.union(other);
    expect(union.west, -50.0);
    expect(union.north, -22.1);
  });

  test('OrbitCamera: clamps nas metas e convergência via tick', () {
    final camera = OrbitCamera(minDistance: 80, maxDistance: 25000);
    camera.elevationRadians = 1.4;
    camera.rotate(0, -1000);
    camera.tick(1);
    expect(
      camera.elevationRadians,
      allOf(greaterThan(1.4), lessThan(1.5)),
      reason: 'clamp máximo (~85°)',
    );
    camera.rotate(0, 10000);
    camera.tick(1);
    expect(camera.elevationRadians, greaterThan(0.0), reason: 'clamp mínimo');

    camera.zoom(1e9);
    camera.tick(1);
    expect(camera.distanceMeters, closeTo(camera.minDistance, 0.01));
    camera.zoom(1e-9);
    camera.tick(1);
    expect(camera.distanceMeters, closeTo(camera.maxDistance, 10));

    final wb = Aabb3.minMax(Vector3(-500, 0, -500), Vector3(500, 0, 500));
    camera.fit(wb, instant: true);
    expect(camera.distanceMeters, closeTo(1000 * 1.15 * math.sqrt2, 1));
    expect(camera.target.x, 0);
    expect(camera.target.z, 0);
  });

  test('OrbitCamera: metas convergem suavemente (sem saltos)', () {
    final camera = OrbitCamera();
    camera.goalDistance = 8000;
    camera.tick(1 / 60);
    // Um quadro: aproxima sem alcançar (amortecimento exponencial).
    expect(camera.distanceMeters, lessThan(8000));
    expect(camera.distanceMeters, greaterThan(1500));
    for (var i = 0; i < 120; i++) {
      camera.tick(1 / 60);
    }
    expect(camera.distanceMeters, closeTo(8000, 1.0));
  });

  test(
    'OrbitCamera: zoom direcionado aproxima o alvo do ponto sob o cursor',
    () {
      final camera = OrbitCamera();
      camera.goalTarget = Vector3(0, 0, 0);
      camera.goalDistance = 2000;
      camera.tick(1);
      camera.zoomToward(2.0, Vector3(1000, 0, 0));
      camera.tick(1);
      expect(
        camera.goalTarget.x,
        greaterThan(400),
        reason: 'alvo desloca na direção do ponto (k = 1 − 1/2 = 0.5)',
      );
      expect(camera.goalTarget.x, lessThan(1000), reason: 'não ultrapassa');
      expect(camera.goalDistance, closeTo(1000, 1));
    },
  );

  test('OrbitCamera: frameBounds enquadra a entidade preservando o ângulo', () {
    final camera = OrbitCamera();
    camera.goalAzimuth = 1.2;
    camera.goalElevation = 0.6;
    camera.goalDistance = 5000;
    camera.tick(1);
    final b = Aabb3.minMax(Vector3(100, 0, 100), Vector3(160, 0, 140));
    camera.frameBounds(b);
    camera.tick(1);
    expect(camera.goalTarget.x, closeTo(130, 1e-6));
    expect(camera.goalTarget.z, closeTo(120, 1e-6));
    expect(camera.goalAzimuth, 1.2, reason: 'ângulo preservado');
    // Diagonal ~72 m × margem 2.2 → ~158 m, acima do mínimo.
    expect(camera.goalDistance, closeTo(72.1 * 2.2, 1));
  });

  test('OrbitCamera: pan clamped dentro da bounds do alvo', () {
    final camera = OrbitCamera()
      ..setTargetBounds(
        Aabb3.minMax(Vector3(-100, 0, -100), Vector3(100, 0, 100)),
      );
    camera.pan(-1e6, -1e6);
    camera.tick(1);
    expect(camera.goalTarget.x, lessThanOrEqualTo(100));
    expect(camera.goalTarget.x, greaterThanOrEqualTo(-100));
  });
}

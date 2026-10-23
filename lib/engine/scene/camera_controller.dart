import 'dart:math' as math;

import '../geo/coordinate_projector.dart';

/// Câmera orbital do motor (matemática pura, testável; a conversão para
/// a câmera concreta do backend acontece no adapter).
///
/// Estado: alvo (ponto olhado, no solo), azimute, inclinação e distância.
/// Limites de movimento razoáveis: inclinação 5°..85°, distância
/// 80 m..25 km, alvo dentro de uma bounds opcional.
class OrbitCamera {
  OrbitCamera({
    Vector3? target,
    this.azimuthRadians = 0,
    this.elevationRadians = 0.9,
    this.distanceMeters = 1500,
    this.minDistance = 80,
    this.maxDistance = 25000,
    this.targetBounds,
  }) : target = target ?? Vector3.zero();

  /// Alvo no solo (centro do enquadramento).
  Vector3 target;

  /// 0 = olhando do leste para o alvo; cresce anti-horário (vista de
  /// cima, convenção x/z do motor).
  double azimuthRadians;

  /// 0 = rasante; π/2 = zênite.
  double elevationRadians;
  double distanceMeters;

  final double minDistance;
  final double maxDistance;
  WorldBounds? targetBounds;

  static const double _minElevation = 0.08; // ~4.6°
  static const double _maxElevation = math.pi / 2 * 0.94; // ~85°

  /// Posição da câmera no mundo.
  Vector3 get position => Vector3(
    target.x +
        distanceMeters * math.cos(elevationRadians) * math.cos(azimuthRadians),
    target.y + distanceMeters * math.sin(elevationRadians),
    target.z +
        distanceMeters * math.cos(elevationRadians) * math.sin(azimuthRadians),
  );

  /// Rotação orbital: `dx`, `dy` em pixels-like (qualquer unidade
  /// proporcional ao gesto).
  void rotate(double dx, double dy) {
    azimuthRadians += dx * 0.005;
    final next = elevationRadians - dy * 0.005;
    elevationRadians = next.clamp(_minElevation, _maxElevation);
  }

  /// Zoom: `factor` > 1 aproxima.
  void zoom(double factor) {
    final next = distanceMeters / factor;
    distanceMeters = next.clamp(minDistance, maxDistance);
  }

  /// Deslocamento lateral (pan, "agarra o chão"): move o alvo no plano do
  /// solo ao longo dos eixos da câmera projetados no chão. Conteúdo segue
  /// o dedo: dx>0 → alvo vai para -right; dy>0 → alvo vai para +forward.
  void pan(double dx, double dy, {double speed = 0.0016}) {
    final k = distanceMeters * speed;
    final fwdX = -math.cos(azimuthRadians);
    final fwdZ = -math.sin(azimuthRadians);
    final rightX = -fwdZ;
    final rightZ = fwdX;
    target.x += (-rightX * dx + fwdX * dy) * k;
    target.z += (-rightZ * dx + fwdZ * dy) * k;
    _clampTarget();
  }

  /// Enquadra a bounds: alvo no centro, distância pela diagonal.
  void fit(WorldBounds bounds) {
    target = Vector3(
      (bounds.min.x + bounds.max.x) / 2,
      0,
      (bounds.min.z + bounds.max.z) / 2,
    );
    targetBounds = bounds;
    final dx = bounds.max.x - bounds.min.x;
    final dz = bounds.max.z - bounds.min.z;
    final diag = math.sqrt(dx * dx + dz * dz);
    distanceMeters = (diag * 1.15).clamp(minDistance, maxDistance);
    elevationRadians = 0.9;
  }

  void setTargetBounds(WorldBounds? bounds) {
    targetBounds = bounds;
    _clampTarget();
  }

  void _clampTarget() {
    final b = targetBounds;
    if (b == null) return;
    target.x = target.x.clamp(b.min.x, b.max.x);
    target.z = target.z.clamp(b.min.z, b.max.z);
  }
}

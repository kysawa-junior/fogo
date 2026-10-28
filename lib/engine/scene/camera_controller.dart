import 'dart:math' as math;

import '../geo/coordinate_projector.dart';

/// Câmera orbital do motor (matemática pura, testável; a conversão para
/// a câmera concreta do backend acontece no adapter).
///
/// Estado por METAS + amortecimento exponencial: gestos alteram as
/// metas (goal*) e [tick] aproxima os valores atuais a cada quadro —
/// movimento suave, sem saltos, com sensibilidade consistente.
///
/// Limites de movimento: inclinação ~4,6°..85°, distância 80 m..25 km,
/// alvo dentro de uma bounds opcional (nunca atravessa o terreno).
class OrbitCamera {
  OrbitCamera({
    Vector3? target,
    this.azimuthRadians = 0,
    this.elevationRadians = 0.9,
    this.distanceMeters = 1500,
    this.minDistance = 80,
    this.maxDistance = 25000,
    this.smoothing = 12,
    this.targetBounds,
  }) : target = (target ?? Vector3.zero()).clone() {
    goalTarget = this.target.clone();
    goalAzimuth = azimuthRadians;
    goalElevation = elevationRadians;
    goalDistance = distanceMeters;
  }

  /// Alvo no solo (centro do enquadramento) — valores ATUAIS.
  Vector3 target;

  /// 0 = olhando do leste para o alvo; cresce anti-horário (vista de
  /// cima, convenção x/z do motor).
  double azimuthRadians;

  /// 0 = rasante; π/2 = zênite.
  double elevationRadians;
  double distanceMeters;

  final double minDistance;
  final double maxDistance;

  /// Constante de amortecimento (1/s). 0 = sem suavização.
  final double smoothing;

  WorldBounds? targetBounds;

  // Metas para onde os valores atuais convergem.
  late Vector3 goalTarget;
  late double goalAzimuth;
  late double goalElevation;
  late double goalDistance;

  static const double _minElevation = 0.08; // ~4.6°
  static const double _maxElevation = math.pi / 2 * 0.94; // ~85°

  /// Distância (m) acima da qual a câmera trava no TOPO: a camada 3D
  /// ainda não é opaca sobre a base 2D (banda de opacidade 1400→1000 —
  /// [SceneOverlayOpacity.fullBelowMeters]). MESMO PITCH durante o
  /// surgimento da camada 3D = o mesmo mapa em duas dimensões, sem
  /// sensação de troca; abaixo disso o pitch é livre (visão 3D).
  /// (O LOD de volumes continua em 3500 — LodPolicy.maxDistanceFor(1).)
  static const double mapModeDistanceMeters = 1000;

  /// Posição da câmera no mundo (calculada dos valores atuais).
  Vector3 get position => Vector3(
    target.x +
        distanceMeters * math.cos(elevationRadians) * math.cos(azimuthRadians),
    target.y + distanceMeters * math.sin(elevationRadians),
    target.z +
        distanceMeters * math.cos(elevationRadians) * math.sin(azimuthRadians),
  );

  /// Avança o amortecimento: chamar uma vez por quadro com o delta
  /// desde o quadro anterior (segundos).
  void tick(double deltaSeconds) {
    // Modo mapa: afastado → forçado a olhar de cima (gesto de rotação
    // é ignorado enquanto longe; aproximar devolve o controle).
    if (goalDistance > mapModeDistanceMeters) {
      goalElevation = _maxElevation;
    }
    if (smoothing <= 0 || deltaSeconds <= 0) {
      target.setFrom(goalTarget);
      azimuthRadians = goalAzimuth;
      elevationRadians = goalElevation;
      distanceMeters = goalDistance;
      return;
    }
    final t = 1 - math.exp(-smoothing * deltaSeconds);
    target.setValues(
      target.x + (goalTarget.x - target.x) * t,
      target.y + (goalTarget.y - target.y) * t,
      target.z + (goalTarget.z - target.z) * t,
    );
    azimuthRadians += (goalAzimuth - azimuthRadians) * t;
    elevationRadians += (goalElevation - elevationRadians) * t;
    distanceMeters += (goalDistance - distanceMeters) * t;
  }

  /// Rotação orbital: `dx`, `dy` em pixels do gesto.
  void rotate(double dx, double dy) {
    goalAzimuth += dx * 0.005;
    final next = goalElevation - dy * 0.005;
    goalElevation = next.clamp(_minElevation, _maxElevation);
  }

  /// Zoom: `factor` > 1 aproxima.
  void zoom(double factor) {
    goalDistance = (goalDistance / factor).clamp(minDistance, maxDistance);
  }

  /// Zoom direcionado: aproxima movendo o alvo na direção do ponto
  /// sob o cursor (interseção do raio com o plano do solo).
  void zoomToward(double factor, Vector3 groundPoint) {
    final before = goalDistance;
    zoom(factor);
    final applied = before / goalDistance; // clamp pode reduzir o efeito
    final k = 1 - 1 / applied;
    goalTarget.x += (groundPoint.x - goalTarget.x) * k;
    goalTarget.z += (groundPoint.z - goalTarget.z) * k;
    _clampGoalTarget();
  }

  /// Deslocamento lateral (pan, "agarra o chão"): move o alvo no plano
  /// do solo ao longo dos eixos da câmera. Conteúdo segue o dedo.
  void pan(double dx, double dy, {double speed = 0.0016}) {
    final k = goalDistance * speed;
    final fwdX = -math.cos(goalAzimuth);
    final fwdZ = -math.sin(goalAzimuth);
    final rightX = -fwdZ;
    final rightZ = fwdX;
    goalTarget.x += (-rightX * dx + fwdX * dy) * k;
    goalTarget.z += (-rightZ * dx + fwdZ * dy) * k;
    _clampGoalTarget();
  }

  /// Enquadra a bounds: alvo no centro, distância pela diagonal,
  /// inclinação padrão de cidade (elevação 0.9 rad). O azimute deita o
  /// EIXO LONGO da região na LARGURA da janela (screen-up ⊥ eixo longo):
  /// com o default 0 o eixo X ficava EM PÉ, desperdiçando o viewport
  /// largo. `frameBounds` (entidade) NÃO usa isto — preserva o ângulo.
  void fit(WorldBounds bounds, {bool instant = false}) {
    goalTarget.setValues(
      (bounds.min.x + bounds.max.x) / 2,
      0,
      (bounds.min.z + bounds.max.z) / 2,
    );
    final dx = bounds.max.x - bounds.min.x;
    final dz = bounds.max.z - bounds.min.z;
    final diag = math.sqrt(dx * dx + dz * dz);
    goalDistance = (diag * 1.15).clamp(minDistance, maxDistance);
    goalElevation = 0.9;
    // Eixo longo X → screen-up ao longo de Z (azimute ±π/2); eixo longo
    // Z → azimute 0 (screen-up = -X, Z fica horizontal).
    goalAzimuth = dx >= dz ? math.pi / 2 : 0.0;
    setTargetBounds(bounds);
    if (instant) {
      tick(1e9);
    }
  }

  /// Enquadra uma entidade (rua/edifício selecionado): preserva o
  /// ângulo atual da câmera, move o alvo e ajusta a distância ao
  /// tamanho real — nunca atravessa o terreno nem perde o objeto.
  void frameBounds(WorldBounds bounds, {double margin = 2.2}) {
    goalTarget.setValues(
      (bounds.min.x + bounds.max.x) / 2,
      0,
      (bounds.min.z + bounds.max.z) / 2,
    );
    final dx = bounds.max.x - bounds.min.x;
    final dz = bounds.max.z - bounds.min.z;
    final diag = math.max(math.sqrt(dx * dx + dz * dz), 30);
    goalDistance = (diag * margin).clamp(minDistance, maxDistance);
    _clampGoalTarget();
  }

  void setTargetBounds(WorldBounds? bounds) {
    targetBounds = bounds;
    _clampGoalTarget();
    if (bounds == null) return;
    target.x = target.x.clamp(bounds.min.x, bounds.max.x);
    target.z = target.z.clamp(bounds.min.z, bounds.max.z);
  }

  void _clampGoalTarget() {
    final b = targetBounds;
    if (b == null) return;
    goalTarget.x = goalTarget.x.clamp(b.min.x, b.max.x);
    goalTarget.z = goalTarget.z.clamp(b.min.z, b.max.z);
  }
}

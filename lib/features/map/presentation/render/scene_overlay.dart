/// Opacidade da camada 3D dinâmica sobre a base 2D permanente.
///
/// Nova arquitetura (sem troca de modos): o 2D nunca desliga; o 3D é uma
/// camada por cima que surge progressivamente conforme a câmera se
/// aproxima. A função é pura — avaliada por frame com a distância atual
/// da câmera — e substitui o antigo `MapModeResolver` (que agendava
/// setState pós-frame a partir do paint e produzia o erro "Build
/// scheduled during frame").
abstract final class SceneOverlayOpacity {
  /// Acima disso a camada 3D é invisível (só base 2D). O 3D só entra
  /// quando a câmera está BEM próxima — a banda começa fundo no zoom.
  static const double hiddenAboveMeters = 1400;

  /// Distância em que a camada 3D atinge opacidade total. É também o
  /// limiar da trava top-down da câmera
  /// ([OrbitCamera.mapModeDistanceMeters]): enquanto a camada surge, os
  /// dois mapas têm o MESMO pitch — projeções idênticas, sem "dois
  /// mapas". Abaixo, pitch livre (visão 3D).
  static const double fullBelowMeters = 1000;

  /// 0 = invisível (base 2D nua); 1 = camada 3D opaca. Bandas fora do
  /// intervalo saturem; dentro da banda usa smoothstep (chegada suave,
  /// sem "pop" nas pontas).
  static double compute(double distanceMeters) => smoothstep(
    (hiddenAboveMeters - distanceMeters) /
        (hiddenAboveMeters - fullBelowMeters),
  );

  /// Smoothstep 0..1 (Hermite): t fora do intervalo satura. Reusado pela
  /// extrusão progressiva dos volumes de edifício no adapter (banda do
  /// gate 700→600 m) — a mesma curva que a opacidade do overlay.
  static double smoothstep(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}

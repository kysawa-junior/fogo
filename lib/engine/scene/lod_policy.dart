import 'map_scene.dart';

/// Política de LOD (ETAPA 08): agrupa objetos por importância
/// cartográfica e determina a que distância da câmera ficam visíveis.
///
/// A transição usa thresholds com HISTERESE (±15% do limite) para evitar
/// flicker no zoom na fronteira: um objeto L2 que aparece a 800 m só
/// some novamente abaixo de 680 m (e vice-versa), nunca oscilando.
abstract final class LodPolicy {
  /// TASK-0011: raio (m) ao redor da CÂMERA em que volumes 3D de
  /// edifícios renderizam; fora dele só o pad plano por tile. Ajuste
  /// fino aqui — ~6 quarteirões em Marília.
  static const double buildingVolumeRadiusMeters = 600;

  /// Margem de histerese (m): entra no range em 600 m, só sai em 700 m
  /// — sem flapping de volumes na borda.
  static const double buildingVolumeHysteresisMeters = 100;

  /// Níveis de LOD por tipo de objeto.
  static int levelOf(SceneObjectKind kind) => switch (kind) {
    // Sempre visível: a BASE 2D do mapa — vias, áreas (água/verde
    // urbano), água. Flat e leve: visão geral limpa a quilômetros.
    SceneObjectKind.road ||
    SceneObjectKind.landArea ||
    SceneObjectKind.water => 0,

    // Média distância (< 3500 m): VOLUMES 3D — edifícios com volume,
    // estádio/posto/delegacia/hospital/templo (kind building) e pads
    // de junção (~7 mil malhas pequenas: invisíveis na escala de km,
    // pura tentativa de draw call — fora do modo 2D).
    SceneObjectKind.building ||
    SceneObjectKind.junctionPad ||
    SceneObjectKind.roadMarking => 1,

    // Aproximação: árvores, mobiliário, semáforos — alto custo de
    // draw call e irrelevante à distância.
    SceneObjectKind.crossing ||
    SceneObjectKind.signal ||
    SceneObjectKind.tree ||
    SceneObjectKind.furniture => 2,

    // ENG-0008: discos de POI — só em aproximação (mesma política de
    // mobiliário/semáforos).
    SceneObjectKind.poi => 2,
  };

  /// Distância máxima da câmera (m) para cada nível ficar visível.
  static double maxDistanceFor(int level) => switch (level) {
    0 => double.infinity,
    1 => 3500,
    2 => 1200,
    _ => 800,
  };

  /// Com histerese: para REAPARECER, a distância precisa estar
  /// significativamente ABAIXO do limite (15% de margem).
  static bool isLevelVisible(
    int level,
    double cameraDistance, {
    required double previousDistance,
  }) {
    final max = maxDistanceFor(level);
    if (max == double.infinity) return true;
    final wasVisible = previousDistance <= max;
    // Se estava visível, some só abaixo de max*0.85 (histerese).
    if (wasVisible) return cameraDistance <= max * 0.85;
    // Se estava oculto, aparece só acima de max (voltou a aproximar).
    return cameraDistance <= max;
  }
}

import 'package:vector_math/vector_math_64.dart';

import 'map_scene.dart';

/// Contrato de backend de renderização do F.O.G.O. O motor prepara e
/// gerencia o modelo cartográfico independentemente desta interface;
/// apenas a implementação concreta (ex.: [FlutterSceneAdapter], na camada
/// de aplicação) conhece APIs gráficas.
abstract class RenderBackend {
  /// Sobe a cena inteira (substitui o conteúdo anterior).
  Future<void> uploadScene(MapScene scene);

  /// Descarrega todos os recursos gráficos.
  Future<void> clear();

  /// Destaca (ou restaura, com cor null) a entidade selecionada.
  void setEntityColor(String entityId, Vector3? color);
}

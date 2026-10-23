import 'sourced_value.dart';

/// Propriedades de uma via, compostas (flags) — nunca subclasses por
/// combinação de características. Valores ausentes ≠ conhecidos ≠
/// estimados (ver [SourcedValue]).
class RoadProperties {
  RoadProperties({
    this.widthMeters,
    this.lanes,
    this.oneway = false,
    this.surface,
    this.layer = 0,
    this.bridge = false,
    this.tunnel = false,
  });

  /// Largura: conhecida (tag `width`), estimada (por tipo/`lanes`) ou
  /// padrão — preenchida pelo OsmFeatureMapper, nula antes disso.
  SourcedValue<double>? widthMeters;

  /// Número de faixas (tag `lanes`); nula = ausente.
  final int? lanes;

  /// Sentido de circulação (tag `oneway`). A direção GEOMÉTRICA da
  /// sequência de pontos não é o sentido de tráfego; esta flag vem da tag.
  final bool oneway;

  /// Superfície (tag `surface`); nula = ausente.
  final String? surface;

  /// Camada vertical (tag `layer`, default 0).
  final int layer;

  /// Ponte (tag `bridge`).
  final bool bridge;

  /// Túnel (tag `tunnel`).
  final bool tunnel;
}

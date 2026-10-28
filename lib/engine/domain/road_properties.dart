import 'sourced_value.dart';

/// Propriedades de uma via, compostas (flags) — nunca subclasses por
/// combinação de características. Valores ausentes ≠ conhecidos ≠
/// estimados (ver [SourcedValue]).
class RoadProperties {
  RoadProperties({
    this.widthMeters,
    this.lanes,
    bool oneway = false,
    RoadDirection? direction,
    this.surface,
    this.layer = 0,
    this.bridge = false,
    this.tunnel = false,
  }) : direction =
           direction ?? (oneway ? RoadDirection.forward : RoadDirection.both),
       oneway = direction == null ? oneway : direction != RoadDirection.both;

  /// Largura: conhecida (tag `width`), estimada (por tipo/`lanes`) ou
  /// padrão — preenchida pelo OsmFeatureMapper, nula antes disso.
  SourcedValue<double>? widthMeters;

  /// Número de faixas (tag `lanes`); nula = ausente.
  final int? lanes;

  /// Sentido de circulação. `forward` follows ordered OSM points;
  /// `reverse` permits travel in the opposite direction.
  final RoadDirection direction;

  /// Compatibilidade: true continua significando exatamente um sentido
  /// permitido, seja ele [RoadDirection.forward] ou [RoadDirection.reverse].
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

enum RoadDirection { both, forward, reverse }

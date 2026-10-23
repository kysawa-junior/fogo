/// Valor com origem explícita: conhecido dos dados, estimado por regra
/// configurável, ou padrão de visualização. Nunca confundir os três.
enum SourcedOrigin { known, estimated, defaulted }

class SourcedValue<T> {
  const SourcedValue.known(this.value)
    : origin = SourcedOrigin.known,
      raw = null;

  const SourcedValue.estimated(this.value, {this.raw})
    : origin = SourcedOrigin.estimated;

  const SourcedValue.defaulted(this.value)
    : origin = SourcedOrigin.defaulted,
      raw = null;

  final T value;

  /// Valor bruto da tag OSM que originou a estimativa (ex.: "building
  /// levels:3"), quando aplicável.
  final String? raw;
  final SourcedOrigin origin;

  bool get isKnown => origin == SourcedOrigin.known;
  bool get isEstimated => origin == SourcedOrigin.estimated;
  bool get isDefaulted => origin == SourcedOrigin.defaulted;
}

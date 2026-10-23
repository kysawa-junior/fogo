import 'sourced_value.dart';

import '../geo/geo_coordinate.dart';
import 'map_feature.dart';

/// Edifício com contorno (anéis: externo + buracos) e altura.
/// Altura conhecida (tag `height` numérica, metros) vs estimada
/// (regra configurável; ex.: `building:levels`) vs padrão — sempre explícito.
class Building extends MapFeature {
  const Building({
    required super.id,
    required super.tags,
    required this.footprint,
    this.height = const SourcedValue.estimated(9, raw: 'default'),
    this.minHeightMeters,
  });

  /// Anéis do contorno: [0] = externo, resto = buracos (pátios).
  final List<GeoPolyline> footprint;

  /// Altura em metros, com origem explícita.
  final SourcedValue<double> height;

  /// Altura mínima (tag `min_height`, ex.: passagens elevadas); nula = 0.
  final double? minHeightMeters;

  bool get hasHoles => footprint.length > 1;

  double? get levels {
    final raw = tags['building:levels'];
    return raw == null ? null : double.tryParse(raw);
  }
}

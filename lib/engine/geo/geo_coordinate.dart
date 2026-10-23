/// Coordenada geográfica WGS84: latitude, longitude e elevação opcional
/// (metros acima do nível do mar). Elevação ausente = null — nunca inventada.
class GeoCoordinate {
  const GeoCoordinate(this.latitude, this.longitude, {this.elevation});

  final double latitude;
  final double longitude;
  final double? elevation;

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinate &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.elevation == elevation;

  @override
  int get hashCode => Object.hash(latitude, longitude, elevation);

  @override
  String toString() =>
      'GeoCoordinate($latitude, $longitude'
      '${elevation == null ? '' : ', elev: $elevation'})';
}

/// Polilinha geográfica: sequência ordenada de coordenadas.
typedef GeoPolyline = List<GeoCoordinate>;

/// Polígono geográfico com anéis: o primeiro é o contorno externo, os
/// demais são buracos (inner rings).
class GeoPolygon {
  GeoPolygon(this.rings)
    : assert(rings.isNotEmpty, 'Polígono precisa de ao menos 1 anel.');

  final List<GeoPolyline> rings;

  GeoPolyline get outer => rings.first;
  List<GeoPolyline> get holes => rings.length > 1 ? rings.sublist(1) : const [];
}

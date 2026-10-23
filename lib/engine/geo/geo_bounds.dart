import 'geo_coordinate.dart';

/// Limites geográficos (WGS84) de uma área retangular.
class GeoBounds {
  const GeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  /// Constrói a partir de [west, south, east, north].
  factory GeoBounds.fromList(List<double> b) =>
      GeoBounds(west: b[0], south: b[1], east: b[2], north: b[3]);

  final double west;
  final double south;
  final double east;
  final double north;

  double get widthDegrees => east - west;
  double get heightDegrees => north - south;

  GeoCoordinate get center =>
      GeoCoordinate((south + north) / 2, (west + east) / 2);

  bool contains(GeoCoordinate c) =>
      c.longitude >= west &&
      c.longitude <= east &&
      c.latitude >= south &&
      c.latitude <= north;

  /// União com outro retângulo.
  GeoBounds union(GeoBounds other) => GeoBounds(
    west: west < other.west ? west : other.west,
    south: south < other.south ? south : other.south,
    east: east > other.east ? east : other.east,
    north: north > other.north ? north : other.north,
  );

  @override
  String toString() => 'GeoBounds(w:$west, s:$south, e:$east, n:$north)';
}

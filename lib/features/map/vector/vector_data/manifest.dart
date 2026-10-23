part of 'vector_data.dart';

/// Geographic offline tile coverage from manifest `tileBounds`.
///
/// Named fields preserve the manifest's west/south/east/north order; convert
/// with [toBbox] only where consumers require minLng/minLat/maxLng/maxLat.
class MapTileBounds {
  const MapTileBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  factory MapTileBounds.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('tileBounds must be an object');
    }
    final Map<String, dynamic> valueMap = value;

    double coordinate(String key) {
      final Object? value = valueMap[key];
      if (value is! num || !value.isFinite) {
        throw FormatException('tileBounds.$key must be a finite number');
      }
      return value.toDouble();
    }

    final MapTileBounds bounds = MapTileBounds(
      west: coordinate('west'),
      south: coordinate('south'),
      east: coordinate('east'),
      north: coordinate('north'),
    );
    if (bounds.west > bounds.east || bounds.south > bounds.north) {
      throw const FormatException('tileBounds has inverted coordinates');
    }
    return bounds;
  }

  /// `[west, south, east, north]`, also the vector painter's bbox order.
  List<double> toBbox() => [west, south, east, north];
}

/// Manifesto da base (assets/map/manifest.json).
class MapManifest {
  const MapManifest({
    required this.version,
    required this.bbox,
    required this.tileBounds,
    required this.cellSize,
    required this.cols,
    required this.rows,
    required this.attribution,
    required this.source,
    required this.generatedAt,
  });

  /// minLng, minLat, maxLng, maxLat (convenção do pipeline).
  final List<double> bbox;
  final MapTileBounds tileBounds;
  final int version;
  final double cellSize;
  final int cols;
  final int rows;
  final String attribution;
  final String source;
  final String generatedAt;

  factory MapManifest.fromJson(Map<String, dynamic> json) {
    final Object? rawBbox = json['bbox'];
    if (rawBbox is! List || rawBbox.length != 4) {
      throw const FormatException('bbox must contain four coordinates');
    }
    final List<double> bbox = [
      for (final Object? value in rawBbox)
        if (value is num)
          value.toDouble()
        else
          throw const FormatException('bbox coordinates must be numbers'),
    ];
    final MapTileBounds tileBounds = MapTileBounds.fromJson(json['tileBounds']);
    if (bbox[0] != tileBounds.west ||
        bbox[1] != tileBounds.south ||
        bbox[2] != tileBounds.east ||
        bbox[3] != tileBounds.north) {
      throw const FormatException('bbox and tileBounds must match');
    }
    return MapManifest(
      version: json['version'] as int? ?? 1,
      bbox: bbox,
      tileBounds: tileBounds,
      cellSize: (json['cellSize'] as num).toDouble(),
      cols: json['cols'] as int,
      rows: json['rows'] as int,
      attribution: json['attribution'] as String? ?? '',
      source: json['source'] as String? ?? '',
      generatedAt: json['generatedAt'] as String? ?? '',
    );
  }

  /// Índice de célula (x, y) de uma coordenada; null fora da cobertura.
  (int, int)? cellIndex(double lat, double lng) {
    final int x = ((lng - bbox[0]) / cellSize).floor();
    final int y = ((lat - bbox[1]) / cellSize).floor();
    if (x < 0 || y < 0 || x >= cols || y >= rows) return null;
    return (x, y);
  }

  bool covers(double lat, double lng) =>
      lat >= bbox[1] && lat <= bbox[3] && lng >= bbox[0] && lng <= bbox[2];
}

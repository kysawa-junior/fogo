/// Modelo vetorial puro (sem dependências de UI) da base cartográfica real.
/// Origem: OpenStreetMap (ver tool/map_data/build_map_data.py), formato v2.

library;

/// Classe de via (índice = código no JSON das células).
enum RoadClass {
  motorway,
  trunk,
  primary,
  secondary,
  tertiary,
  unclassified,
  residential,
  service,
  track,
  path,
  other,
}

RoadClass roadClassFromCode(int code) =>
    RoadClass.values[code.clamp(0, RoadClass.values.length - 1)];

enum AreaKind { water, green, farmland, boundary }

AreaKind areaKindFromCode(int code) =>
    AreaKind.values[code.clamp(0, AreaKind.values.length - 1)];

/// Curso d'água linear (rio, canal, córrego, dreno).
enum WaterLineKind { river, canal, stream, drain }

WaterLineKind waterLineKindFromCode(int code) =>
    WaterLineKind.values[code.clamp(0, WaterLineKind.values.length - 1)];

enum PoiKind { amenity, shop, tourism, leisure, healthcare, craftOffice }

enum LabelKind { city, town, village, suburb }

class MapRoad {
  const MapRoad({
    required this.cls,
    required this.name,
    required this.oneway,
    required this.bridge,
    required this.tunnel,
    this.ref,
    required this.flatCoords,
    required this.bbox,
  });

  final RoadClass cls;
  final String name;

  /// Sentido único (setas no zoom de rua).
  final bool oneway;
  final bool bridge;
  final bool tunnel;

  /// Referência (SP-333, BR-…) para shields.
  final String? ref;

  /// Pares lat,lng encadeados: [lat0, lng0, lat1, lng1, ...].
  final List<double> flatCoords;

  /// minLat, minLng, maxLat, maxLng (culling).
  final List<double> bbox;

  int get pointCount => flatCoords.length ~/ 2;
}

class MapArea {
  const MapArea({
    required this.kind,
    required this.flatCoords,
    required this.bbox,
  });

  final AreaKind kind;
  final List<double> flatCoords;
  final List<double> bbox;
}

enum RailKind { rail, tram, disused }

RailKind railKindFromCode(int code) =>
    RailKind.values[code.clamp(0, RailKind.values.length - 1)];

class MapRail {
  const MapRail({
    required this.kind,
    required this.flatCoords,
    required this.bbox,
  });

  final RailKind kind;
  final List<double> flatCoords;
  final List<double> bbox;

  int get pointCount => flatCoords.length ~/ 2;
}

class MapWaterLine {
  const MapWaterLine({
    required this.kind,
    required this.name,
    required this.flatCoords,
    required this.bbox,
  });

  final WaterLineKind kind;
  final String name;
  final List<double> flatCoords;
  final List<double> bbox;

  int get pointCount => flatCoords.length ~/ 2;
}

class MapPoi {
  const MapPoi({
    required this.kind,
    required this.lat,
    required this.lng,
    required this.name,
  });

  final PoiKind kind;
  final double lat;
  final double lng;
  final String name;
}

class MapLabel {
  const MapLabel({
    required this.kind,
    required this.lat,
    required this.lng,
    required this.text,
  });

  final LabelKind kind;
  final double lat;
  final double lng;
  final String text;
}

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

/// Dados de uma célula (l0 = vias/áreas/pois/rótulos/ferrovias/água;
/// l1 = edificações).
class MapCellData {
  const MapCellData({
    this.roads = const [],
    this.areas = const [],
    this.rails = const [],
    this.waterLines = const [],
    this.pois = const [],
    this.labels = const [],
    this.buildings = const [],
  });

  final List<MapRoad> roads;
  final List<MapArea> areas;
  final List<MapRail> rails;
  final List<MapWaterLine> waterLines;
  final List<MapPoi> pois;
  final List<MapLabel> labels;
  final List<MapArea> buildings;

  static MapCellData l0FromJson(Map<String, dynamic> json) => MapCellData(
    roads: [
      for (final r in (json['roads'] as List? ?? const []))
        MapRoad(
          cls: roadClassFromCode(r['c'] as int),
          name: r['n'] as String? ?? '',
          ref: (r['r'] as String?)?.isEmpty ?? true ? null : r['r'] as String,
          oneway: (r['o'] as int? ?? 0) == 1,
          bridge: (r['br'] as int? ?? 0) == 1,
          tunnel: (r['tn'] as int? ?? 0) == 1,
          flatCoords: List<double>.from(r['p'] as List),
          bbox: List<double>.from(r['b'] as List),
        ),
    ],
    areas: [
      for (final a in (json['areas'] as List? ?? const []))
        MapArea(
          kind: areaKindFromCode(a['k'] as int),
          flatCoords: List<double>.from(a['p'] as List),
          bbox: List<double>.from(a['b'] as List),
        ),
    ],
    rails: [
      for (final r in (json['rail'] as List? ?? const []))
        MapRail(
          kind: railKindFromCode(r['k'] as int? ?? 0),
          flatCoords: List<double>.from(r['p'] as List),
          bbox: List<double>.from(r['b'] as List),
        ),
    ],
    waterLines: [
      for (final w in (json['wl'] as List? ?? const []))
        MapWaterLine(
          kind: waterLineKindFromCode(w['k'] as int),
          name: w['n'] as String? ?? '',
          flatCoords: List<double>.from(w['p'] as List),
          bbox: List<double>.from(w['b'] as List),
        ),
    ],
    pois: [
      for (final p in (json['pois'] as List? ?? const []))
        MapPoi(
          kind: PoiKind.values[(p['k'] as int).clamp(0, 5)],
          lat: p['x'] as double,
          lng: p['y'] as double,
          name: p['n'] as String? ?? '',
        ),
    ],
    labels: [
      for (final l in (json['labels'] as List? ?? const []))
        MapLabel(
          kind: LabelKind.values[(l['k'] as int).clamp(0, 3)],
          lat: l['x'] as double,
          lng: l['y'] as double,
          text: l['n'] as String? ?? '',
        ),
    ],
  );

  static MapCellData l1FromJson(Map<String, dynamic> json) => MapCellData(
    buildings: [
      for (final b in (json['bld'] as List? ?? const []))
        MapArea(
          kind: AreaKind.green, // não usado; edifícios pintados à parte
          flatCoords: List<double>.from(b['p'] as List),
          bbox: List<double>.from(b['b'] as List),
        ),
    ],
  );
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

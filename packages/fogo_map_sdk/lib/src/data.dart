import 'package:flutter/foundation.dart';

import 'coordinates.dart';

enum FogoRoadClass {
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

enum FogoAreaKind { water, green, farmland, boundary }

enum FogoRailKind { rail, tram, disused }

enum FogoWaterLineKind { river, canal, stream, drain }

enum FogoPoiKind { amenity, shop, tourism, leisure, healthcare, craftOffice }

enum FogoLabelKind { city, town, village, suburb }

enum FogoCellTier { l0, l1 }

@immutable
class FogoMapRoad {
  FogoMapRoad({
    required this.roadClass,
    required this.name,
    required this.oneway,
    required this.bridge,
    required this.tunnel,
    required List<double> coordinates,
    required List<double> bbox,
    this.ref,
  }) : coordinates = List.unmodifiable(coordinates),
       bbox = List.unmodifiable(bbox);

  final FogoRoadClass roadClass;
  final String name;
  final String? ref;
  final bool oneway;
  final bool bridge;
  final bool tunnel;

  /// Flat sequence of latitude, longitude pairs.
  final List<double> coordinates;

  /// `[minLat, minLng, maxLat, maxLng]`.
  final List<double> bbox;

  int get pointCount => coordinates.length ~/ 2;
}

@immutable
class FogoMapArea {
  FogoMapArea({
    required this.kind,
    required List<double> coordinates,
    required List<double> bbox,
    this.heightMeters,
  }) : coordinates = List.unmodifiable(coordinates),
       bbox = List.unmodifiable(bbox);

  final FogoAreaKind kind;
  final List<double> coordinates;
  final List<double> bbox;

  /// Positive numeric OSM `height`, in metres. Null means render flat.
  final double? heightMeters;
}

@immutable
class FogoMapRail {
  FogoMapRail({
    required this.kind,
    required List<double> coordinates,
    required List<double> bbox,
  }) : coordinates = List.unmodifiable(coordinates),
       bbox = List.unmodifiable(bbox);

  final FogoRailKind kind;
  final List<double> coordinates;
  final List<double> bbox;
}

@immutable
class FogoMapWaterLine {
  FogoMapWaterLine({
    required this.kind,
    required this.name,
    required List<double> coordinates,
    required List<double> bbox,
  }) : coordinates = List.unmodifiable(coordinates),
       bbox = List.unmodifiable(bbox);

  final FogoWaterLineKind kind;
  final String name;
  final List<double> coordinates;
  final List<double> bbox;
}

@immutable
class FogoMapPoi {
  const FogoMapPoi({
    required this.kind,
    required this.coordinate,
    required this.name,
  });

  final FogoPoiKind kind;
  final FogoCoordinate coordinate;
  final String name;
}

@immutable
class FogoMapLabel {
  const FogoMapLabel({
    required this.kind,
    required this.coordinate,
    required this.text,
  });

  final FogoLabelKind kind;
  final FogoCoordinate coordinate;
  final String text;
}

/// Immutable metadata for the regional `manifest.json` asset.
@immutable
class FogoMapManifest {
  const FogoMapManifest({
    required this.bounds,
    required this.cellSize,
    required this.columns,
    required this.rows,
    required this.attribution,
    required this.generatedAt,
    required this.source,
  });

  final FogoGeoBounds bounds;
  final double cellSize;
  final int columns;
  final int rows;
  final String attribution;
  final String generatedAt;
  final String source;

  factory FogoMapManifest.fromJson(Object? value) {
    final Map<String, Object?> json = _map(value, 'manifest');
    final List<Object?> bbox = _list(json['bbox'], 'bbox');
    if (bbox.length != 4) {
      throw const FormatException('manifest.bbox must contain four values');
    }
    final FogoGeoBounds bounds = FogoGeoBounds(
      west: _number(bbox[0], 'bbox[0]'),
      south: _number(bbox[1], 'bbox[1]'),
      east: _number(bbox[2], 'bbox[2]'),
      north: _number(bbox[3], 'bbox[3]'),
    );
    if (!bounds.isValid) {
      throw const FormatException('manifest.bbox has invalid bounds');
    }
    final Map<String, Object?> tileBounds = _map(
      json['tileBounds'],
      'tileBounds',
    );
    final FogoGeoBounds declaredBounds = FogoGeoBounds(
      west: _number(tileBounds['west'], 'tileBounds.west'),
      south: _number(tileBounds['south'], 'tileBounds.south'),
      east: _number(tileBounds['east'], 'tileBounds.east'),
      north: _number(tileBounds['north'], 'tileBounds.north'),
    );
    if (bounds != declaredBounds) {
      throw const FormatException('bbox and tileBounds must match');
    }
    final double cellSize = _number(json['cellSize'], 'cellSize');
    final int columns = _integer(json['cols'], 'cols');
    final int rows = _integer(json['rows'], 'rows');
    if (cellSize <= 0 || columns <= 0 || rows <= 0) {
      throw const FormatException('cell grid dimensions must be positive');
    }
    if (bounds.east > bounds.west + columns * cellSize + 1e-9 ||
        bounds.north > bounds.south + rows * cellSize + 1e-9) {
      throw const FormatException('cell grid does not cover manifest bounds');
    }
    return FogoMapManifest(
      bounds: bounds,
      cellSize: cellSize,
      columns: columns,
      rows: rows,
      attribution: json['attribution'] is String
          ? json['attribution']! as String
          : '',
      generatedAt: json['generatedAt'] is String
          ? json['generatedAt']! as String
          : '',
      source: json['source'] is String ? json['source']! as String : '',
    );
  }

  (int, int)? cellIndex(FogoCoordinate coordinate) {
    if (!bounds.contains(coordinate)) return null;
    final int x = ((coordinate.longitude - bounds.west) / cellSize).floor();
    final int y = ((coordinate.latitude - bounds.south) / cellSize).floor();
    return (x.clamp(0, columns - 1), y.clamp(0, rows - 1));
  }
}

/// One decoded cell. Empty arrays are normal and render no feature.
@immutable
class FogoMapCellData {
  FogoMapCellData({
    List<FogoMapRoad> roads = const [],
    List<FogoMapArea> areas = const [],
    List<FogoMapRail> rails = const [],
    List<FogoMapWaterLine> waterLines = const [],
    List<FogoMapPoi> pois = const [],
    List<FogoMapLabel> labels = const [],
    List<FogoMapArea> buildings = const [],
  }) : roads = List.unmodifiable(roads),
       areas = List.unmodifiable(areas),
       rails = List.unmodifiable(rails),
       waterLines = List.unmodifiable(waterLines),
       pois = List.unmodifiable(pois),
       labels = List.unmodifiable(labels),
       buildings = List.unmodifiable(buildings);

  final List<FogoMapRoad> roads;
  final List<FogoMapArea> areas;
  final List<FogoMapRail> rails;
  final List<FogoMapWaterLine> waterLines;
  final List<FogoMapPoi> pois;
  final List<FogoMapLabel> labels;
  final List<FogoMapArea> buildings;

  bool get isEmpty =>
      roads.isEmpty &&
      areas.isEmpty &&
      rails.isEmpty &&
      waterLines.isEmpty &&
      pois.isEmpty &&
      labels.isEmpty &&
      buildings.isEmpty;

  factory FogoMapCellData.l0FromJson(Object? value) {
    final Map<String, Object?> json = _map(value, 'L0 cell');
    return FogoMapCellData(
      roads: [for (final Object? item in _array(json, 'roads')) _road(item)],
      areas: [
        for (final Object? item in _array(json, 'areas')) _area(item, 'area'),
      ],
      rails: [for (final Object? item in _array(json, 'rail')) _rail(item)],
      waterLines: [
        for (final Object? item in _array(json, 'wl')) _waterLine(item),
      ],
      pois: [for (final Object? item in _array(json, 'pois')) _poi(item)],
      labels: [for (final Object? item in _array(json, 'labels')) _label(item)],
    );
  }

  factory FogoMapCellData.l1FromJson(Object? value) {
    final Map<String, Object?> json = _map(value, 'L1 cell');
    return FogoMapCellData(
      buildings: [
        for (final Object? item in _array(json, 'bld')) _area(item, 'building'),
      ],
    );
  }
}

FogoMapRoad _road(Object? value) {
  final Map<String, Object?> record = _map(value, 'road');
  return FogoMapRoad(
    roadClass: _enumValue(FogoRoadClass.values, record['c'], 'road.c'),
    name: _stringOrEmpty(record['n']),
    ref: record['r'] is String && (record['r']! as String).isNotEmpty
        ? record['r']! as String
        : null,
    oneway: _flag(record['o']),
    bridge: _flag(record['br']),
    tunnel: _flag(record['tn']),
    coordinates: _coordinates(record['p'], 'road.p', minimumPoints: 2),
    bbox: _bbox(record['b'], 'road.b'),
  );
}

FogoMapArea _area(Object? value, String label) {
  final Map<String, Object?> record = _map(value, label);
  final Object? rawHeight = record['height'];
  final double? height = rawHeight is num && rawHeight.isFinite && rawHeight > 0
      ? rawHeight.toDouble()
      : null;
  return FogoMapArea(
    kind: _enumValue(FogoAreaKind.values, record['k'] ?? 0, '$label.k'),
    coordinates: _coordinates(record['p'], '$label.p', minimumPoints: 3),
    bbox: _bbox(record['b'], '$label.b'),
    heightMeters: height,
  );
}

FogoMapRail _rail(Object? value) {
  final Map<String, Object?> record = _map(value, 'rail');
  return FogoMapRail(
    kind: _enumValue(FogoRailKind.values, record['k'] ?? 0, 'rail.k'),
    coordinates: _coordinates(record['p'], 'rail.p', minimumPoints: 2),
    bbox: _bbox(record['b'], 'rail.b'),
  );
}

FogoMapWaterLine _waterLine(Object? value) {
  final Map<String, Object?> record = _map(value, 'waterline');
  return FogoMapWaterLine(
    kind: _enumValue(FogoWaterLineKind.values, record['k'], 'waterline.k'),
    name: _stringOrEmpty(record['n']),
    coordinates: _coordinates(record['p'], 'waterline.p', minimumPoints: 2),
    bbox: _bbox(record['b'], 'waterline.b'),
  );
}

FogoMapPoi _poi(Object? value) {
  final Map<String, Object?> record = _map(value, 'POI');
  final FogoCoordinate coordinate = FogoCoordinate(
    _number(record['x'], 'POI.x'),
    _number(record['y'], 'POI.y'),
  );
  if (!coordinate.isValid) {
    throw const FormatException('POI coordinate invalid');
  }
  return FogoMapPoi(
    kind: _enumValue(FogoPoiKind.values, record['k'], 'POI.k'),
    coordinate: coordinate,
    name: _stringOrEmpty(record['n']),
  );
}

FogoMapLabel _label(Object? value) {
  final Map<String, Object?> record = _map(value, 'label');
  final FogoCoordinate coordinate = FogoCoordinate(
    _number(record['x'], 'label.x'),
    _number(record['y'], 'label.y'),
  );
  if (!coordinate.isValid) {
    throw const FormatException('label coordinate invalid');
  }
  return FogoMapLabel(
    kind: _enumValue(FogoLabelKind.values, record['k'], 'label.k'),
    coordinate: coordinate,
    text: _stringOrEmpty(record['n']),
  );
}

List<double> _coordinates(
  Object? value,
  String name, {
  required int minimumPoints,
}) {
  final List<Object?> raw = _list(value, name);
  if (raw.length < minimumPoints * 2 || raw.length.isOdd) {
    throw FormatException('$name must contain $minimumPoints coordinate pairs');
  }
  final List<double> coordinates = [
    for (int i = 0; i < raw.length; i++) _number(raw[i], '$name[$i]'),
  ];
  for (int i = 0; i < coordinates.length; i += 2) {
    final FogoCoordinate point = FogoCoordinate(
      coordinates[i],
      coordinates[i + 1],
    );
    if (!point.isValid) throw FormatException('$name has invalid WGS84 point');
  }
  return coordinates;
}

List<double> _bbox(Object? value, String name) {
  final List<Object?> raw = _list(value, name);
  if (raw.length != 4) throw FormatException('$name must contain four values');
  final List<double> bbox = [
    for (int i = 0; i < raw.length; i++) _number(raw[i], '$name[$i]'),
  ];
  if (bbox[0] > bbox[2] || bbox[1] > bbox[3]) {
    throw FormatException('$name has inverted bounds');
  }
  return bbox;
}

List<Object?> _array(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return const [];
  return _list(value, key);
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('$name must be an object');
  return value.map((Object? key, Object? item) {
    if (key is! String) throw FormatException('$name keys must be strings');
    return MapEntry(key, item);
  });
}

List<Object?> _list(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array');
  return value.cast<Object?>();
}

double _number(Object? value, String name) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$name must be a finite number');
  }
  return value.toDouble();
}

int _integer(Object? value, String name) {
  if (value is! int) throw FormatException('$name must be an integer');
  return value;
}

T _enumValue<T>(List<T> values, Object? value, String name) {
  if (value is! int || value < 0 || value >= values.length) {
    throw FormatException('$name has unsupported code');
  }
  return values[value];
}

bool _flag(Object? value) => value == 1 || value == true;
String _stringOrEmpty(Object? value) => value is String ? value : '';
